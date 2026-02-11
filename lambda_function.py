import boto3
import os
import datetime

ec2 = boto3.client("ec2")

def lambda_handler(event, context):
    print("======================================")
    IST = datetime.timezone(datetime.timedelta(hours=5, minutes=30))
    print("Execution time (IST):", datetime.datetime.now(IST))
    print("Request ID:", context.aws_request_id)
    print("Event received:", event)
    print("======================================")

    action = event.get("action")
    env_tag = os.environ.get("ENV_TAG", "qa")

    if action == "stop":
        state_filter = ["running"]
    elif action == "start":
        state_filter = ["stopped"]
    else:
        raise ValueError("Unknown action: " + str(action))

    # 🔍 Get instances based on tag + state
    response = ec2.describe_instances(
        Filters=[
            {"Name": "tag:environment", "Values": [env_tag]},
            {"Name": "instance-state-name", "Values": state_filter}
        ]
    )

    instance_ids = [
        i["InstanceId"]
        for r in response["Reservations"]
        for i in r["Instances"]
    ]

    if not instance_ids:
        print(f"No instances found for action: {action} in environment: {env_tag}")
        return

    try:
        if action == "stop":
            ec2.stop_instances(InstanceIds=instance_ids)
            print("Stopping instances:", instance_ids)

        elif action == "start":
            ec2.start_instances(InstanceIds=instance_ids)
            print("Starting instances:", instance_ids)

    except Exception as e:
        print("Error occurred:", str(e))
        raise

    print("Execution completed successfully.")
