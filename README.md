# AWS Event-Driven Order Processing Pipeline

Event-driven order processing pipeline built on AWS serverless messaging services.
Demonstrates SNS fan-out, SQS dead letter queues, Lambda event source mapping,
and CloudWatch observability — patterns common in fintech payment processing systems.

## Architecture

## Stack

- **Messaging:** AWS SNS, AWS SQS (standard queues + DLQ)
- **Compute:** AWS Lambda (Python 3.12)
- **Storage:** S3 (Lambda artifact storage)
- **Observability:** CloudWatch Metric Alarms
- **IaC:** Terraform (AWS provider ~5.0)

## Key Design Decisions

**SNS fan-out over direct SQS publish** — producer publishes once to SNS;
SNS delivers to both queues simultaneously. Adding a new consumer requires
zero producer changes. See [ADR 001](docs/adrs/adr-001-sns-sqs-fanout-pattern.md).

**DLQ per queue** — processing and notification failures are fully isolated.
`maxReceiveCount=3` means SQS retries 3 times before routing to DLQ.
DLQ retention is 14 days; main queue retention is 1 day.

**Least-privilege IAM** — each Lambda has a dedicated role with minimal permissions:
producer can only `sns:Publish`, processor and notifier can only
`sqs:ReceiveMessage`, `sqs:DeleteMessage`, `sqs:GetQueueAttributes`
on their respective queues.

## Project Structure

## Deployment

```bash
cd terraform
terraform init
terraform apply -auto-approve
```

## Testing

**Happy path — valid order:**
```bash
aws lambda invoke \
  --function-name event-driven-orders-producer-dev \
  --payload '{"body": "{\"customer_id\": \"cust-123\", \"amount\": 99.99, \"currency\": \"USD\"}"}' \
  --cli-binary-format raw-in-base64-out \
  response.json && cat response.json
```

**DLQ trigger — invalid order (amount=0):**
```bash
aws lambda invoke \
  --function-name event-driven-orders-producer-dev \
  --payload '{"body": "{\"customer_id\": \"cust-bad\", \"amount\": 0, \"currency\": \"USD\"}"}' \
  --cli-binary-format raw-in-base64-out \
  response.json
```

After ~2 minutes check DLQ:
```bash
aws sqs get-queue-attributes \
  --queue-url https://sqs.us-east-1.amazonaws.com/774493573578/event-driven-orders-processing-dlq-dev \
  --attribute-names ApproximateNumberOfMessages
```

## Incidents

- [INC-001 — DLQ routing on invalid order amount](docs/incidents/incident-001-dlq-invalid-amount.md)

## Teardown

```bash
cd terraform
terraform destroy -auto-approve
```

> **Note:** S3 bucket must be emptied before destroy.
> Run `aws s3 rm s3://event-driven-orders-lambda-artifacts-dev --recursive` first.