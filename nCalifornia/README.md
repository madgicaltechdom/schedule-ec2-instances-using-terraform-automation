# Automated EC2 Fleet Scheduler using Terraform

Many businesses struggle with unnecessary AWS costs due to idle EC2 instances running outside business hours.

This solution uses Terraform + EventBridge + Lambda to automatically start and stop **EC2 Fleet instances** based on schedule — fully automated.

Non-production machines can be turned off after hours and on weekends, and automatically started when working hours begin. This can significantly reduce EC2 costs in non-production environments by stopping idle resources outside business hours.

## Architecture

The automation works as follows:

1. EventBridge (CloudWatch Scheduler) triggers on a cron schedule.
2. EventBridge invokes a Lambda function.
3. Lambda:
    - Reads fleet IDs from environment variable `FLEET_IDS`
    - Calls `ec2:ModifyFleet` to set target capacity:
        - `target_capacity = 0` → terminates fleet instances (8 PM IST)
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

## Requirements

- Install Terraform
- Setup your AWS account
- Create a programmatic user with permissions to manage EC2 Fleets
- Configure AWS credentials using:
  ```
  aws configure
  ```

## Find Your Fleet IDs

Run this command to list all EC2 Fleets in your region:

```bash
aws ec2 describe-fleets --region us-west-1 --query "Fleets[*].{FleetId:FleetId,Name:Tags[?Key=='Name']|[0].Value}" --output table
```

Fleet IDs look like: `fleet-0123456789abcdef0`

## Usage

1. Clone this repository:
   ```
   git clone -b feature/ec2-scheduler-automation https://github.com/madgicaltechdom/schedule-ec2-instances-using-terraform-automation.git
   ```

2. Navigate to the nCalifornia directory:
   ```
   cd schedule-ec2-instances-using-terraform-automation/nCalifornia
   ```

3. Create `terraform.tfvars` and add your fleet IDs:
   ```
   fleet_ids = [
     "fleet-xxxxxxxxxxxxx",
     "fleet-yyyyyyyyyyyyy"
   ]
   ```

4. (Optional) Customize cron schedules in `variable.tf`:
   ```
   variable "cron_stop" {
     default = "30 14 ? * MON-SAT *"  # 8 PM IST, Mon-SAT
   }

   variable "cron_start" {
     default = "30 03 ? * MON-SAT *"  # 9 AM IST, Mon-SAT
   }
   ```

5. Create a new workspace (optional):
   ```
   terraform workspace new qa
   ```

6. Initialize Terraform:
   ```
   terraform init
   ```

7. Preview changes:
   ```
   terraform plan
   ```

8. Apply changes:
   ```
   terraform apply
   ```

## Lambda Implementation

The Lambda:

- Reads fleet IDs from `FLEET_IDS` environment variable (comma-separated)
- Receives action (`start` or `stop`) from EventBridge
- Calls `ec2:ModifyFleet` to set target capacity to 0 or 1

Environment variables:
```
FLEET_IDS = fleet-xxxxxxxxxxxxx,fleet-yyyyyyyyyyyyy
```

## IAM Permissions

Lambda Role Permissions:

- `ec2:ModifyFleet`
- `ec2:DescribeFleets`
- `ec2:DescribeFleetsInstances`
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
Processing fleet: fleet-xxxxxxxxxxxxx
Set fleet fleet-xxxxxxxxxxxxx target capacity to 0
Execution completed. Results: [{'fleet_id': 'fleet-xxxxxxxxxxxxx', 'status': 'success'}]
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
