# Incident 001 — DLQ Routing on Invalid Order Amount

**Date:** 2026-08-04  
**Severity:** Low (controlled test)  
**Status:** Resolved  

## Symptoms

Order with `amount=0` was published successfully by producer Lambda (HTTP 201),
but processor Lambda silently failed to process it. No error visible to the caller.
Message disappeared from processing queue without confirmation of successful processing.

## Investigation

1. Checked producer logs — Lambda returned 201, SNS publish succeeded
2. Checked processor logs via `aws logs tail` — no output found initially
3. Checked DLQ depth via `aws sqs get-queue-attributes` — found 1 message
4. Retrieved message from DLQ via `aws sqs receive-message` — confirmed it was
   the original order with `amount=0`

## Root Cause

Processor Lambda raises `ValueError` when `amount=0`. With SQS event source mapping
and `maxReceiveCount=3` in the redrive policy, SQS retried delivery 3 times.
After 3 failures, SQS automatically moved the message to the dead letter queue.

CloudWatch logs were absent because Lambda failed during event processing before
producing any log output — a known behaviour with SQS triggers on cold start failures.

## Fix

No fix applied — this is intentional validation logic. In production, the fix would be:
- Return a structured error response instead of raising an exception (to avoid unnecessary retries for business logic errors)
- Distinguish between transient failures (network, downstream timeout) that should retry, and permanent failures (invalid data) that should go directly to DLQ

## Verification

```bash
aws sqs get-queue-attributes \
  --queue-url https://sqs.us-east-1.amazonaws.com/774493573578/event-driven-orders-processing-dlq-dev \
  --attribute-names ApproximateNumberOfMessages
# Result: {"ApproximateNumberOfMessages": "1"}
```

## Prevention

- CloudWatch Alarm `event-driven-orders-processing-dlq-depth-dev` fires when DLQ depth > 0
- In production: add input validation in producer before publishing to SNS

## Lessons Learned

1. SQS + Lambda retry behaviour is invisible to the caller — producer returns 201 while processor is silently failing
2. CloudWatch logs may be absent for Lambda failures triggered via SQS event source mapping on cold start
3. DLQ is the only reliable signal that messages are failing — monitoring DLQ depth is mandatory, not optional