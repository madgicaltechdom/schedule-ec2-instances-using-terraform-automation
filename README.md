# Automated EC2 Fleet & Instance Scheduler using Terraform

Many businesses struggle with unnecessary AWS costs due to idle EC2 instances running outside business hours.

This solution uses Terraform + EventBridge + Lambda to automatically start and stop **EC2 Fleet instances** and **individual EC2 instances** based on schedule — fully automated.

Non-production machines can be turned off after hours and on weekends, and automatically started when working hours begin. This can significantly reduce EC2 costs in non-production environments by stopping idle resources outside business hours.

## Ventech Deployment

This branch (`ec2-fleet-and-instance-scheduler-ventech`) is deployed to the **Ventech AWS account** and schedules the **SonarQube** server.

| Item | Value |
|------|-------|
| AWS profile | `ventech` |
| Region | `us-west-1` (N. California) |
| Terraform state | `s3://madgical-terraform-state-bucket-ventech/ncalifornia-scheduler/terraform.tfstate` (`ap-south-1`) |
| Environment | `qa` (default workspace) |
| Lambda | `EC2-Scheduler-qa` |
| EventBridge rules | `EC2-Scheduler-Start-qa`, `EC2-Scheduler-Stop-qa` |
| Dead-letter queue | `EC2-Scheduler-DLQ-qa` |

SonarQube runs as a single Spot instance in an EC2 Fleet (capacity 1), launched from a launch template. Every night the fleet is scaled to 0 and the instance is terminated; every morning it is scaled back to 1 and a new instance is launched. SonarQube data survives because it lives on a separate persistent EBS volume that the launch template's user data reattaches and mounts at `/var/lib/docker` on boot. Expect SonarQube to be reachable a few minutes after 9 AM IST.

SonarQube runs Mon–Sat, 9 AM–8 PM IST (66 of 168 hours a week).

## Architecture

The automation works as follows:

1. EventBridge (CloudWatch Scheduler) triggers on a cron schedule.
2. EventBridge invokes a Lambda function.
3. Lambda handles two independent sections (failure in one does not affect the other):
    - **EC2 Fleets**: Auto-discovers all active fleets via `DescribeFleets` API, checks capacity, calls `ec2:ModifyFleet` to set target capacity to 0 or 1
    - **EC2 Instances**: Discovers instances by `environment` tag, **excludes fleet-managed instances** (tagged with `aws:ec2:fleet-id`), then stops/starts remaining instances individually
4. If an invocation fails, EventBridge retries it up to 2 times (for events up to 1 hour old), then sends it to an SQS dead-letter queue (14-day retention).

## How It Works

| Time (IST) | Time (UTC) | Action | What Happens |
|------------|------------|--------|--------------|
| 9 AM | 03:30 | Start | Fleet creates new Spot instances + EC2 instances start |
| 8 PM | 14:30 | Stop | Fleet terminates Spot instances + EC2 instances stop |
| Sunday | - | - | Stays stopped (no start) |

**Note:** Fleet instances are terminated and recreated each day. This means:
- New public/private IPs each morning
- Data on instance store volumes is lost
- EBS volumes (if attached) persist
- For persistent data, use EBS or EFS

### Idempotent Behavior

The Lambda checks current capacity before modifying:

| Scenario | Behavior |
|----------|----------|
| Fleet already at target capacity | Skips with log `already_running` or `already_stopped` |
| Fleet not at target capacity | Modifies fleet to desired capacity |
| Fleet in non-modifiable state | Skips immediately (e.g., `FleetNotInModifiableState`) |
| Fleet capacity lookup fails | Logs error, continues with remaining fleets |

## Requirements

- Terraform >= 1.10 (the S3 backend uses native state locking via `use_lockfile`)
- An AWS user with permissions to manage EC2 Fleets, EC2 Instances, Lambda, EventBridge, SQS and IAM
- An AWS CLI profile named `ventech` (used by both the provider and the S3 backend):
  ```
  aws configure --profile ventech
  ```

## Usage

1. Clone this repository:
   ```
   git clone -b ec2-fleet-and-instance-scheduler-ventech https://github.com/madgicaltechdom/schedule-ec2-instances-using-terraform-automation.git
   ```

2. Navigate to the repository root (all Terraform files are at the root):
   ```
   cd schedule-ec2-instances-using-terraform-automation
   ```

3. (Optional) Customize cron schedules in `variable.tf` (cron times are in UTC):
   ```
   variable "cron_stop" {
     default = "30 14 ? * MON-SAT *"  # 8 PM IST, Mon-SAT
   }

   variable "cron_start" {
     default = "30 03 ? * MON-SAT *"  # 9 AM IST, Mon-SAT
   }
   ```

4. (Optional) Select a workspace. The workspace decides the `environment` tag value the Lambda targets and the resource name suffix:

   | Workspace | Environment tag |
   |-----------|-----------------|
   | `default` | `qa` |
   | `qa` | `qa` |
   | `prd` | `prd` |
   | any other | `qa` |

   ```
   terraform workspace new prd
   ```

5. Initialize Terraform:
   ```
   terraform init
   ```

6. Preview changes:
   ```
   terraform plan
   ```

7. Apply changes:
   ```
   terraform apply
   ```

### Updating the Lambda Code

Terraform deploys `lambda.zip`, not `lambda_function.py`. After editing the Python file, rebuild the zip before applying:

```
zip lambda.zip lambda_function.py
terraform apply
```

## Lambda Implementation

The Lambda:

- **Auto-discovers fleets** via `DescribeFleets` API — no hardcoded fleet IDs
- **Auto-discovers EC2 instances** by `environment` tag — no hardcoded instance IDs
- **Filters out fleet-managed instances** (`aws:ec2:fleet-id` tag) — these are handled by the fleet capacity logic, not individually
- **Stops/starts instances individually** — one failure does not block other instances
- **Checks current capacity** before modifying (idempotent)
- Receives action (`start` or `stop`) from EventBridge
- Calls `ec2:ModifyFleet` to set target capacity to 0 or 1
- Calls `ec2:StartInstances` / `ec2:StopInstances` for individual instances
- **Error isolation**: Fleet and instance operations are independent — if one fails, the other still runs
- Makes up to 3 attempts per fleet with exponential backoff (waits 10s, then 20s)
- Skips retries for `FleetNotInModifiableState` errors

### Error Handling

| Error | Handling |
|-------|----------|
| Unknown action | Returns error, Lambda succeeds |
| `DescribeFleets` fails (IAM/network) | Returns error for fleet section, instances still run |
| Fleet deleted during execution | Logs error, continues with next fleet |
| `FleetNotInModifiableState` | Skips immediately, no retries |
| Lambda timeout approaching | Stops retries, returns timeout status |
| All retries exhausted | Returns error status |
| EC2 instance start/stop fails | Logs error for that instance, continues with remaining instances |
| Fleet-managed instance found | Skipped automatically (handled by fleet capacity logic) |

### Log Output Example

```
Execution time (IST): 2026-07-21 22:13:28+05:30
Event received: {'action': 'stop'}
Found 2 fleet(s): [fleet-aaa, fleet-bbb]
Fleet fleet-aaa current capacity: 1
Modifying fleet fleet-aaa from 1 to 0
Set fleet fleet-aaa target capacity to 0
Fleet fleet-bbb current capacity: 1
Fleet fleet-bbb is already_stopped, skipping
Fleet Summary: 1 succeeded, 1 skipped, 0 failed
Skipping 2 fleet-managed instance(s) (handled by fleet): [i-aaa, i-bbb]
Found 1 EC2 instance(s) to stop: [i-ccc]
Stopping EC2 instance: i-ccc
Final Results: {'fleet': [...], 'instances': [...]}
```

## IAM Permissions

Lambda Role Permissions:

- `ec2:ModifyFleet`
- `ec2:DescribeFleets`
- `ec2:DescribeFleetInstances`
- `ec2:StartInstances`
- `ec2:StopInstances`
- `ec2:DescribeInstances`
- `sqs:SendMessage` (dead-letter queue only)
- CloudWatch Logs permissions

## Verification

### Check EventBridge Rule

Go to: EventBridge → Scheduled rules

https://us-west-1.console.aws.amazon.com/events/home?region=us-west-1#/scheduled-rules

Confirm:
- Rule is Enabled
- Next trigger time is correct (UTC)

### Check Lambda Logs

Go to: CloudWatch → Log groups → /aws/lambda/EC2-Scheduler-qa

You should see logs similar to:
```
Found 1 fleet(s): [fleet-xxxxxxxxxxxxx]
Fleet fleet-xxxxxxxxxxxxx current capacity: 1
Modifying fleet fleet-xxxxxxxxxxxxx from 1 to 0
Set fleet fleet-xxxxxxxxxxxxx target capacity to 0
Fleet Summary: 1 succeeded, 0 skipped, 0 failed
Skipping 1 fleet-managed instance(s) (handled by fleet): [i-yyyyyyyyyyyyy]
Found 1 EC2 instance(s) to stop: [i-xxxxxxxxxxxxx]
Stopping EC2 instance: i-xxxxxxxxxxxxx
```

### Check the Dead-Letter Queue

Events that failed after all EventBridge retries land in the DLQ. It should normally be empty:

```
aws sqs get-queue-attributes --profile ventech --region us-west-1 \
  --queue-url $(terraform output -raw dlq_url) \
  --attribute-names ApproximateNumberOfMessages
```

## Known Limitations

- **Fleets are not filtered by tag**: every active EC2 Fleet in the region is scaled to 0/1, not only fleets tagged with the environment.
- **Start always sets capacity to 1**: a fleet's original capacity is not remembered. Fleets that need more than 1 instance will come back with 1.
- **Public IP changes daily**: fleet instances are new each morning and there is no Elastic IP or DNS update, so anything that points at the SonarQube IP must be updated (or an Elastic IP added to the launch template user data).
- **Only `/var/lib/docker` persists**: the root volume is deleted on termination, so anything stored outside the persistent EBS volume is lost each night.
- **Spot capacity**: if no Spot capacity is available at 9 AM for the fleet's instance types, startup is delayed until capacity frees up.

## Time Zone Reference

| IST | UTC |
|-----|-----|
| 9 AM | 03:30 |
| 8 PM | 14:30 |

[Time Zone Converter (IST to UTC)](https://www.worldtimebuddy.com/ist-to-utc-converter)

## Contributing

We are very grateful for any contributions you are willing to make. Please have a look here to get started. If you aim to make a large change, it is helpful to discuss the change first in a new GitHub issue. Feel free to open one!

## License

This project is licensed under the MIT License.
