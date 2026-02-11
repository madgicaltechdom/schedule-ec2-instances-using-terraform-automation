# Automated EC2 Start/Stop Scheduler using Terraform (Tag-Based)
Many businesses struggle with unnecessary AWS costs due to idle EC2 instances running outside business hours.

This solution uses Terraform + EventBridge + Lambda + AWS Systems Manager (SSM) to automatically start and stop EC2 instances based on schedule — completely tag-driven and fully automated.

Non-production machines can be turned off after hours and on weekends, and automatically started when working hours begin. This can reduce EC2 costs by more than 50% in most non-prod environments.

## Architecture

The automation works as follows:

1. EventBridge (CloudWatch Scheduler) triggers on a cron schedule.
2. EventBridge invokes a Lambda function.
3. Lambda:
    - Finds EC2 instances using the environment tag (e.g., qa)
    - Directly calls:
        - ec2:StartInstances
        - ec2:StopInstances

4. SSM executes the start/stop operation.

Automatically works for newly created tagged instances.

## Requirements

 - Install terraform [video](https://www.youtube.com/watch?v=Cn6xYf0QJME&t=8s).
 - Setup your AWS account [video](https://www.youtube.com/watch?v=XhW17g73fvY&t=357s).
 - Create a programmatic user with the permissions specified in the [permission.json](https://github.com/kaumudi766/Multi_Machine_Schedule/blob/main/permission.json) file.
 - EC2 instances must be tagged with:
    ```
    Key   = environment
    Value = qa (or prd)
    ```
 - Configure AWS credentials using:
    ```
    aws configure
    ```
## Tag-Based Scheduling (Important)

This solution dynamically fetches instances using:

```
Filters=[
    {"Name": "tag:environment", "Values": [env_tag]},
    {"Name": "instance-state-name", "Values": ["running", "stopped"]}
]
```

So any new instance created with environment = qa tag will automatically be scheduled — no Terraform changes required.
 
## Cron Expression Fundamentals

 This cron job is made up of several fields, each separated by a space:
 ``` 
 [Minute] [Hour] [Day_of_Month] [Month] [Day_of_Week] [Year] 
 ```

 - The first field is for minutes (0-59).
 - The second field is for hours (0-23).
 - The third field is for days of the month (1-31).
 - The fourth field is for months (1-12).
 - The fifth field is for days of the week (0-7, where both 0 and 7 represent Sunday).
 - The sixth field represents the year. Use * to run every year.
 
## Usage

1. Clone this repository to your local machine by running the below command:
   ```
   git clone -b feature/ec2-scheduler-automation https://github.com/madgicaltechdom/schedule-ec2-instances-using-terraform-automation.git
   ```
    
2. Navigate to the repository directory by running the below command:
   ```
   cd schedule-ec2-instances-using-terraform-automation
   ```
    
3. Log in to your AWS account and navigate to EC2. Select the instance(s) you want to schedule, go to the Tags tab, and click Manage tags. Add a new tag with Key = environment and Value = qa or prd as per your requirement, then click Save.

4. Optional: If you want to add another environment, update the workspace_to_environment_map variable in variables.tf.

   ```
    variable "workspace_to_environment_map" {
      type = map(string)
      default = {
        qa  = "qa"
        prd = "prd"
      }
    }
   ```

5. To match your requirements, modify the stopping time value in the file variable.tf. In this case, "30 14" is UTC time, which corresponds to 8 p.m. IST. For timing reference, please see the time conversion chart at the end of this document. Additionally, the machine is shut off at 8 p.m every Monday to Saturday. You can customize the days as per your business requirements.
   ```
    variable "cron_stop" {
        description = "Cron expression to define when to trigger a stop of the DB"
        default     = "30 14 ? * MON-SAT *"
    }
   ```
   
6. Change the starting time value in the file variable.tf to suit your needs. For timing reference, please see the time conversion chart at the end of this document. In this case, "30 03" denotes UTC time, which corresponds to 9 a.m. IST. Additionally, the machine is turned on at 9 a.m every Monday to Saturday. You can customize the days as per your business requirements.
   ```
    variable "cron_start" {
        description = "Cron expression to define when to trigger a start of the DB"
        default     = "30 03 ? * MON-SAT *"
    }
   ```
   
7. Create a new workspace for each environment you want to deploy, for example for qa(testing): 
    ```
    terraform workspace new qa 
    ```
 
8. Initialize Terraform by running below command: 
    ```
    terraform init
    ```
   
9. Run below command to preview the changes:
    ```
    terraform plan
    ```
   
10. Run below command to apply the changes:
    ```
    terraform apply
    ```

## Lambda Implementation (Dynamic Tag-Based)

The Lambda:

- Reads action from EventBridge
- Detects environment via ENV_TAG
- Fetches matching EC2 instances
- Executes SSM automation document

Environment variables:
```
AUTOSTART_DOC = AWS-StartEC2Instance
AUTOSTOP_DOC  = AWS-StopEC2Instance
ENV_TAG       = qa
```

## IAM Permissions Used
Lambda Role Permissions:

- ssm:StartAutomationExecution
- ec2:DescribeInstances
- ec2:StartInstances
- ec2:StopInstances
- ec2:DescribeInstanceStatus
- CloudWatch Logs permissions

# Verification


## Check EventBridge Rule

Go to: 

EventBridge → Scheduled rules

https://us-west-1.console.aws.amazon.com/events/home?region=us-west-1#/scheduled-rules

Confirm:

- Rule is Enabled
- Next trigger time is correct (UTC)

## Check Lambda Logs

Go to: 

CloudWatch → Log groups → /aws/lambda/EC2-Scheduler-qa

You should see: 

SSM Automation started: "ExecutionId"

## Check Automation Execution

Go to:

Systems Manager → Automation → Executions

## References:

We took information from this [article](https://dnx.solutions/reducing-aws-costs-by-turning-off-development-environments-at-night-the-easy-way-without-lambda/) and this is the step by step User Guide [video](https://drive.google.com/file/d/1d-oyPzC7z2A5ihaIFQuT2oi0DzHJUs6L/view?usp=sharing).

- Here is [time Zone converter](https://www.worldtimebuddy.com/ist-to-utc-converter) for IST to UTC:

![web-screenshot-25-01-2023 (4)](https://user-images.githubusercontent.com/109335469/214537941-37ab6022-d49a-4e50-8d27-623c77007e05.jpg)

# Contributing

We are very grateful for any contributions you are willing to make. Please have a look here to get started. If you aim to make a large change, it is helpful to discuss the change first in a new GitHub issue. Feel free to open one!

# LICENCE:

This project is licensed under the MIT License.
