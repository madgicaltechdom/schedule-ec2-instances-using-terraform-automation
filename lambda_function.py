import boto3
import os
import time
import datetime

ec2 = boto3.client("ec2")

MAX_RETRIES = 3
BASE_DELAY = 10
FLEET_STATES_TO_MODIFY = ["active", "partially_fulfilled", "unfulfilled"]
SKIP_RETRY_ERRORS = {"FleetNotInModifiableState"}


def lambda_handler(event, context):
    print("======================================")
    IST = datetime.timezone(datetime.timedelta(hours=5, minutes=30))
    print("Execution time (IST):", datetime.datetime.now(IST))
    print("Request ID:", context.aws_request_id)
    print("Event received:", event)
    print("======================================")

    action = event.get("action")
    env_tag = os.environ.get("ENV_TAG", "qa")

    if action not in ("stop", "start"):
        print(f"ERROR: Unknown action '{action}', expected 'start' or 'stop'")
        return {"error": f"Unknown action '{action}'", "status": "failed"}

    target_capacity = 1 if action == "start" else 0

    fleet_results = []
    instance_results = []

    # --- EC2 Fleet scheduling ---
    try:
        fleet_results = handle_fleet(action, target_capacity, context)
    except Exception as e:
        print(f"ERROR: Fleet scheduling failed unexpectedly: {e}")
        fleet_results = [{"status": "error", "error": str(e)}]

    # --- EC2 Instance scheduling (independent of fleet) ---
    try:
        instance_results = handle_ec2_instances(action, env_tag)
    except Exception as e:
        print(f"ERROR: EC2 instance scheduling failed unexpectedly: {e}")
        instance_results = [{"status": "error", "error": str(e)}]

    # --- Combined summary ---
    all_results = {"fleet": fleet_results, "instances": instance_results}
    print(f"Final Results: {all_results}")
    return all_results


def handle_fleet(action, target_capacity, context):
    try:
        fleet_ids = get_active_fleet_ids()
    except Exception as e:
        print(f"ERROR: Failed to discover fleets: {e}")
        return [{"status": "error", "error": str(e)}]

    if not fleet_ids:
        print("No active fleets found")
        return []

    print(f"Found {len(fleet_ids)} fleet(s): {fleet_ids}")

    results = []
    for fleet_id in fleet_ids:
        try:
            current_capacity = get_fleet_capacity(fleet_id)
        except Exception as e:
            print(f"ERROR: Failed to get capacity for fleet {fleet_id}: {e}")
            results.append({"fleet_id": fleet_id, "status": "error", "error": str(e)})
            continue

        print(f"Fleet {fleet_id} current capacity: {current_capacity}")

        if current_capacity == target_capacity:
            status = "already_stopped" if target_capacity == 0 else "already_running"
            print(f"Fleet {fleet_id} is {status}, skipping")
            results.append({"fleet_id": fleet_id, "status": status, "current_capacity": current_capacity})
            continue

        print(f"Modifying fleet {fleet_id} from {current_capacity} to {target_capacity}")
        result = modify_fleet_with_retry(fleet_id, target_capacity, context)
        results.append(result)

    succeeded = sum(1 for r in results if r["status"] == "success")
    skipped = sum(1 for r in results if r["status"] in ("skipped", "already_stopped", "already_running"))
    failed = sum(1 for r in results if r["status"] in ("error", "timeout"))
    print(f"Fleet Summary: {succeeded} succeeded, {skipped} skipped, {failed} failed")
    return results


def handle_ec2_instances(action, env_tag):
    if action == "stop":
        state_filter = ["running"]
    else:
        state_filter = ["stopped"]

    response = ec2.describe_instances(
        Filters=[
            {"Name": "tag:environment", "Values": [env_tag]},
            {"Name": "instance-state-name", "Values": state_filter}
        ]
    )

    all_instance_ids = []
    fleet_instance_ids = []
    for r in response["Reservations"]:
        for i in r["Instances"]:
            all_instance_ids.append(i["InstanceId"])
            tags = {t["Key"]: t["Value"] for t in i.get("Tags", [])}
            if "aws:ec2:fleet-id" in tags:
                fleet_instance_ids.append(i["InstanceId"])

    if fleet_instance_ids:
        print(f"Skipping {len(fleet_instance_ids)} fleet-managed instance(s) (handled by fleet): {fleet_instance_ids}")

    instance_ids = [iid for iid in all_instance_ids if iid not in fleet_instance_ids]

    if not instance_ids:
        print(f"No EC2 instances found for action '{action}' in environment '{env_tag}' (all are fleet-managed or none matched)")
        return []

    print(f"Found {len(instance_ids)} EC2 instance(s) to {action}: {instance_ids}")

    succeeded = []
    failed = []
    for instance_id in instance_ids:
        try:
            if action == "stop":
                ec2.stop_instances(InstanceIds=[instance_id])
                print(f"Stopping EC2 instance: {instance_id}")
            else:
                ec2.start_instances(InstanceIds=[instance_id])
                print(f"Starting EC2 instance: {instance_id}")
            succeeded.append(instance_id)
        except Exception as e:
            print(f"ERROR: Failed to {action} EC2 instance {instance_id}: {e}")
            failed.append({"instance_id": instance_id, "error": str(e)})

    results = []
    if succeeded:
        results.append({"instance_ids": succeeded, "status": "success", "action": action})
    if failed:
        results.append({"status": "error", "failed": failed})

    return results


def get_active_fleet_ids():
    fleet_ids = []
    paginator = ec2.get_paginator("describe_fleets")
    for page in paginator.paginate(
        Filters=[{"Name": "fleet-state", "Values": FLEET_STATES_TO_MODIFY}]
    ):
        for fleet in page.get("Fleets", []):
            fleet_ids.append(fleet["FleetId"])
    return fleet_ids


def get_fleet_capacity(fleet_id):
    response = ec2.describe_fleets(FleetIds=[fleet_id])
    fleets = response.get("Fleets", [])
    if not fleets:
        raise ValueError(f"Fleet {fleet_id} not found")
    return fleets[0]["TargetCapacitySpecification"]["TotalTargetCapacity"]


def modify_fleet_with_retry(fleet_id, target_capacity, context):
    for attempt in range(1, MAX_RETRIES + 1):
        remaining_ms = context.get_remaining_time_in_millis()
        if remaining_ms < (BASE_DELAY + 10) * 1000:
            print(f"Lambda timeout approaching ({remaining_ms}ms left), stopping retries")
            return {"fleet_id": fleet_id, "status": "timeout", "attempt": attempt}

        try:
            ec2.modify_fleet(
                FleetId=fleet_id,
                TargetCapacitySpecification={
                    "TotalTargetCapacity": target_capacity
                }
            )
            print(f"Set fleet {fleet_id} target capacity to {target_capacity}")
            return {"fleet_id": fleet_id, "status": "success", "attempt": attempt}
        except Exception as e:
            error_code = getattr(e, "response", {}).get("Error", {}).get("Code", "")
            print(f"Error (attempt {attempt}/{MAX_RETRIES}): {error_code} - {str(e)}")

            if error_code in SKIP_RETRY_ERRORS:
                print(f"Skipping retries for {error_code}")
                return {"fleet_id": fleet_id, "status": "skipped", "error": str(e), "attempt": attempt}

            if attempt == MAX_RETRIES:
                return {"fleet_id": fleet_id, "status": "error", "error": str(e), "attempt": attempt}

            delay = BASE_DELAY * (2 ** (attempt - 1))
            print(f"Retrying in {delay}s...")
            time.sleep(delay)

    return {"fleet_id": fleet_id, "status": "error", "error": "Exhausted all retries"}
