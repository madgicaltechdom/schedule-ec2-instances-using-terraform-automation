**Hook:** EC2 start/stop is manual — unnecessary costs at night.

**Body:** Terraform automation for EC2 scheduling.

**Closer:** Automated EC2 scheduling — 70% cost reduction.

---

# Stop Wasting Money on Idle EC2 Instances with Terraform Automation
Many businesses are focused about lowering the costs of running AWS EC2 instances. Terraform can help you save money by automating EC2 instance management.This solution enables you to automate the start and stop off your instances based on your business requirements. 

Non-production machines can be turned off after hours and on weekends. The machines can be started whenever working hours begin. This might result in more than 50% of your ec2 instances being stopped, saving you a lot.

## Requirements

 - Install terraform [video](https://www.youtube.com/watch?v=Cn6xYf0QJME&t=8s).
 - Setup your AWS account [video](https://www.youtube.com/watch?v=XhW17g73fvY&t=357s).
 - Create a programmatic user with the permissions specified in the [permission.json](https://github.com/kaumudi766/Multi_Machine_Schedule/blob/main/permission.json) file.
 - To schedule ec2 instances, we must have tagged them with the 'environment' tag.
 
## Cronjob Fundamentals:

 This cron job is made up of several fields, each separated by a space:
 ``` 
 [Minute] [Hour] [Day_of_Month] [Month_of_Year] [Day_of_Week] 
 ```

 - The first field is for minutes (0-59).
 - The second field is for hours (0-23).
 - The third field is for days of the month (1-31).
 - The fourth field is for months (1-12).
 - The fifth field is for days of the week (0-7, where both 0 and 7 represent Sunday).
 - The sixth field is for year by default it take current year.
 
## Usage

1. Clone this repository to your local machine by running the below command:
   ```
   git clone https://github.com/madgicaltechdom/Schedule-Idle-EC2-Instances-with-Terraform-Automation.git
   ```
    
2. Navigate to the repository directory by running the below command:
   ```
   cd Schedule-Idle-EC2-Instances-with-Terraform-Automation
   ```
    
3. Login to your AWS Account, search for the EC2, click on the "Tags", then the "Manage tags" button. Here you need to select the instances in which you need to make scheduling and add a tag, in the Key field select "environment", and in Value select "qa" or "prd" according to your need then click on the "Add Tag" button.

![image](https://user-images.githubusercontent.com/101810595/218736709-b072c59d-a8dd-4410-aed5-8ed546067720.png)

4. Optional, if you want to add another tag then first you need to add that tag in the workspace_to_environment_map variable in the varible.tf file and use that tag for scheduling.

   ```
    variable "workspace_to_environment_map" {
      type = map(string)
      default = {
        qa  = "qa"
        prd = "prd"
      }
    }
   ```

5. To match your requirements, modify the stopping time value in the file variable.tf. In this case, "30 14" is UTC time, which corresponds to 8 p.m. IST. For timing, please refer to the chart we printed on the last of this file. Additionally, the machine is shut off at 8 p.m every Monday to Saturday. You can customise your days according to your need.
   ```
    variable "cron_stop" {
        description = "Cron expression to define when to trigger a stop of the DB"
        default     = "30 14 ? * MON-SAT *"
    }
   ```
   
6. Change the starting time value in the file variable.tf to suit your needs. For timing, please refer to the chart in the last of this file. In this case, "30 03" denotes UTC time, which corresponds to 9 a.m. IST. Additionally, the machine is turned on at 9 a.m every Monday to Saturday. You can customise your days according to your need.
   ```
    variable "cron_start" {
        description = "Cron expression to define when to trigger a start of the DB"
        default     = "30 03 ? * MON-SAT *"
    }
   ```
    
7. Change the AWS access key value in the file variable.tf to meet your requirements.
   ```
    variable "access_key" {
        description = "value of access key"
        default     = ""
    }
   ```

8. Change the AWS secret key value in the file variable.tf to meet your requirements.
   ``` 
    variable "secret_key" {
        description = "value of secret key"
        default     = ""
    }
   ```
   
9. Create a new workspace for each environment you want to deploy, for example for qa(testing): 
    ```
    terraform workspace new qa 
    ```
 
10. Initialize Terraform by running below command: 
    ```
    terraform init
    ```
   
11. Run below command to preview the changes:
    ```
    terraform plan
    ```
   
12. Run below command to apply the changes:
    ```
    terraform apply
    ```

# Verify Machines Status

1. Click on the link below to see status, also you can see the time slot by implementing 5 minute later and run the code to see it's running or stopped status as shown below: 

    https://us-east-2.console.aws.amazon.com/cloudwatch/home?region=us-east-2#rules:

![Screenshot (164) (1)](https://user-images.githubusercontent.com/109335469/213730422-0e4803f2-4fc8-45ba-bfe0-0cad41313a79.png) 


  

<img width="812" alt="Screenshot (1631)" src="https://user-images.githubusercontent.com/109335469/214514799-3f224341-661c-4227-9c5b-0fe2887584c6.png">

![Screenshot (165) (1)](https://user-images.githubusercontent.com/109335469/214514514-c45e39d1-ade5-4adf-929a-e001af5a88da.jpg)





2. Check The Execution Point Using System Manager by clicking on the link below: 

https://us-east-2.console.aws.amazon.com/systems-manager/automation/executions?region=us-east-2

<img width="906" alt="Screenshot (166)" src="https://user-images.githubusercontent.com/109335469/213734723-5a2d5503-472f-48d2-b827-c9225e2ba14f.png">


## References:

We took information from this [article](https://dnx.solutions/reducing-aws-costs-by-turning-off-development-environments-at-night-the-easy-way-without-lambda/) and this is the step by step User Guide [video](https://drive.google.com/file/d/1d-oyPzC7z2A5ihaIFQuT2oi0DzHJUs6L/view?usp=sharing).

- Here is [time Zone converter](https://www.worldtimebuddy.com/ist-to-utc-converter) for IST to UTC:

![web-screenshot-25-01-2023 (4)](https://user-images.githubusercontent.com/109335469/214537941-37ab6022-d49a-4e50-8d27-623c77007e05.jpg)

# Contributing

We are very grateful for any contributions you are willing to make. Please have a look here to get started. If you aim to make a large change, it is helpful to discuss the change first in a new GitHub issue. Feel free to open one!

# LICENCE:

This project is licensed under the MIT License.
