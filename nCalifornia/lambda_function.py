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
    fleet_ids = os.environ.get("FLEET_IDS", "").split(",")

    if not fleet_ids or fleet_ids == [""]:
        print("No fleet IDs configured in FLEET_IDS environment variable")
        return

    if action == "stop":
        target_capacity = 0
    elif action == "start":
        target_capacity = 1
    else:
        raise ValueError("Unknown action: " + str(action))

    results = []
    for fleet_id in fleet_ids:
        fleet_id = fleet_id.strip()
        if not fleet_id:
            continue

        print(f"Processing fleet: {fleet_id}")
        try:
            ec2.modify_fleet(
                FleetId=fleet_id,
                TargetCapacitySpecification={
                    "TotalTargetCapacity": target_capacity,
                    "DefaultTargetCapacityType": "spot"
                }
            )
            print(f"Set fleet {fleet_id} target capacity to {target_capacity}")
            results.append({"fleet_id": fleet_id, "status": "success"})
        except Exception as e:
            print(f"Error modifying fleet {fleet_id}: {str(e)}")
            results.append({"fleet_id": fleet_id, "status": "error", "error": str(e)})

    print(f"Execution completed. Results: {results}")
    return results
