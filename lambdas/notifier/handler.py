import json

def lambda_handler(event, context):
    for record in event["Records"]:
        sns_payload = json.loads(record["body"])
        order = json.loads(sns_payload["Message"])

        print(f"Sending notification for order {order['order_id']} to customer {order['customer_id']}")
        print(f"Notification: Your order {order['order_id']} for {order['amount']} {order['currency']} has been received.")

        print(f"Notification sent for order {order['order_id']}")