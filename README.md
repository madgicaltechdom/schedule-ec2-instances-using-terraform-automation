# Automated EC2 Fleet Scheduler using Terraform

Many businesses struggle with unnecessary AWS costs due to idle EC2 instances running outside business hours.

This solution uses Terraform + EventBridge + Lambda to automatically start and stop **EC2 Fleet instances** based on schedule — fully automated.

Non-production machines can be turned off after hours and on weekends, and automatically started when working hours begin. This can significantly reduce EC2 costs in non-production environments by stopping idle resources outside business hours.

## Architecture

The automation works as follows:

1. EventBridge (CloudWatch Scheduler) triggers on a cron schedule.
2. EventBridge invokes a Lambda function.
3. Lambda:
    - Auto-discovers all active EC2 Fleets via `DescribeFleets` API (no hardcoded IDs)
    - Checks current capacity of each fleet before modifying
    - Calls `ec2:ModifyFleet` to set target capacity:
        - `target_capacity = 0` → terminates fleet instances (10 PM IST)
        - `target_capacity = 1` → creates new fleet instances (9 AM IST)

## How It Works

| Time (IST) | Time (UTC) | Action | What Happens |
|------------|------------|--------|--------------|
| 9 AM | 03:30 | Start | Fleet creates new Spot instances |
| 8 PM | 14:30 | Stop | Fleet terminates Spot instances |
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
| Fleet discovery fails | Returns error, continues with remaining fleets |

## Requirements

- Install Terraform
- Setup your AWS account
- Create a programmatic user with permissions to manage EC2 Fleets
- Configure AWS credentials using:
  ```
  aws configure
  ```

## Usage

1. Clone this repository:
   ```
   git clone -b feature/ec2-scheduler-automation https://github.com/madgicaltechdom/schedule-ec2-instances-using-terraform-automation.git
   ```

2. Navigate to the nCalifornia directory:
   ```
   cd schedule-ec2-instances-using-terraform-automation/nCalifornia
   ```

3. (Optional) Customize cron schedules in `variable.tf`:
   ```
   variable "cron_stop" {
     default = "30 16 ? * MON-SAT *"  # 10 PM IST, Mon-SAT
   }

   variable "cron_start" {
     default = "30 03 ? * MON-SAT *"  # 9 AM IST, Mon-SAT
   }
   ```

4. Create a new workspace (optional):
   ```
   terraform workspace new qa
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

## Lambda Implementation

The Lambda:

- **Auto-discovers fleets** via `DescribeFleets` API — no hardcoded fleet IDs
- **Checks current capacity** before modifying (idempotent)
- Receives action (`start` or `stop`) from EventBridge
- Calls `ec2:ModifyFleet` to set target capacity to 0 or 1
- Retries up to 3 times with exponential backoff (10s, 20s, 40s)
- Skips retries for `FleetNotInModifiableState` errors

### Error Handling

| Error | Handling |
|-------|----------|
| Unknown action | Returns error, Lambda succeeds |
| `DescribeFleets` fails (IAM/network) | Returns error, Lambda succeeds |
| Fleet deleted during execution | Logs error, continues with next fleet |
| `FleetNotInModifiableState` | Skips immediately, no retries |
| Lambda timeout approaching | Stops retries, returns timeout status |
| All retries exhausted | Returns error status |

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
Summary: 1 succeeded, 1 skipped, 0 failed
```

## IAM Permissions

Lambda Role Permissions:

- `ec2:ModifyFleet`
- `ec2:DescribeFleets`
- `ec2:DescribeFleetInstances`
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
Summary: 1 succeeded, 0 skipped, 0 failed
```

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
