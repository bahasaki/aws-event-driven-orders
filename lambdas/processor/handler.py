import json

def lambda_handler(event, context):
    for record in event["Records"]:
        # SQS wraps SNS message in an extra layer
        sns_payload = json.loads(record["body"])
        order = json.loads(sns_payload["Message"])

        print(f"Processing order {order['order_id']} amount={order['amount']} {order['currency']}")

        # Simulate processing failure for DLQ testing
        if order.get("amount") == 0:
            raise ValueError(f"Invalid amount for order {order['order_id']}")

        print(f"Order {order['order_id']} processed successfully")