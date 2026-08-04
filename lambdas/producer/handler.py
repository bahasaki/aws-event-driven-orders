import json
import os
import boto3
import uuid
from datetime import datetime, timezone

sns = boto3.client("sns")
SNS_TOPIC_ARN = os.environ["SNS_TOPIC_ARN"]

def lambda_handler(event, context):
    body = json.loads(event.get("body", "{}"))

    order = {
        "order_id": str(uuid.uuid4()),
        "customer_id": body.get("customer_id", "unknown"),
        "amount": body.get("amount", 0),
        "currency": body.get("currency", "USD"),
        "status": "CREATED",
        "created_at": datetime.now(timezone.utc).isoformat(),
    }

    sns.publish(
        TopicArn=SNS_TOPIC_ARN,
        Message=json.dumps(order),
        Subject="order.created",
        MessageAttributes={
            "event_type": {
                "DataType": "String",
                "StringValue": "order.created",
            }
        },
    )

    print(f"Published order {order['order_id']} to SNS")

    return {
        "statusCode": 201,
        "body": json.dumps({"order_id": order["order_id"], "status": "CREATED"}),
    }