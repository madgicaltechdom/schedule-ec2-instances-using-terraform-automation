import boto3
import os

ssm = boto3.client("ssm")
ec2 = boto3.client("ec2")

def lambda_handler(event, context):
    action = event.get("action")
    env_tag = os.environ.get("ENV_TAG", "qa")

    # Get all instances with tag environment=qa that are running or stopped
    response = ec2.describe_instances(
        Filters=[
            {"Name": "tag:environment", "Values": [env_tag]},
            {"Name": "instance-state-name", "Values": ["running", "stopped"]}
        ]
    )

    instance_ids = [
        i["InstanceId"]
        for r in response["Reservations"]
        for i in r["Instances"]
    ]

    if not instance_ids:
        print("No instances found for environment:", env_tag)
        return

    if action == "stop":
        doc_name = os.environ.get("AUTOSTOP_DOC", "AWS-StopEC2Instance")
    elif action == "start":
        doc_name = os.environ.get("AUTOSTART_DOC", "AWS-StartEC2Instance")
    else:
        raise ValueError("Unknown action: " + str(action))

    # Execute SSM automation
    response = ssm.start_automation_execution(
        DocumentName=doc_name,
        Parameters={"InstanceId": instance_ids}
    )
    print("SSM Automation started:", response["AutomationExecutionId"])
