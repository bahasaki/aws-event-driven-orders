# ADR 001 — SNS + SQS Fan-out Pattern for Order Events

**Date:** 2026-08-04  
**Status:** Accepted  

## Context

The order processing pipeline requires that a single order creation event triggers
two independent downstream workflows: order processing (inventory, payment validation)
and customer notification (email/SMS). These workflows must be decoupled — a failure
in notification must not affect processing, and vice versa.

## Decision

Use SNS topic as the entry point for order events, with two SQS queues as subscribers
(fan-out pattern). Producer Lambda publishes once to SNS; SNS delivers to both queues
simultaneously. Each queue has an independent Lambda consumer and a dedicated DLQ.

## Alternatives Considered

**1. Direct SQS publish from producer (no SNS)**  
Producer would need to send messages to two queues explicitly. This creates tight
coupling — producer must know about all consumers, and adding a third consumer
requires modifying producer code. Rejected.

**2. Single SQS queue, single Lambda, internal routing**  
One consumer handles both processing and notification logic. Simpler, but violates
single responsibility principle. A bug in notification logic can block order processing.
Failure isolation is lost. Rejected.

**3. EventBridge instead of SNS**  
EventBridge supports content-based filtering and has better observability tooling.
However, it adds cost and complexity not justified for this use case. SNS fan-out
is sufficient when all consumers receive all events. EventBridge is the right choice
when consumers need to filter by event attributes. Noted for future consideration.

## Consequences

**Positive:**
- Producer is decoupled from consumers — adding a new consumer requires no producer changes
- Processing and notification failures are fully isolated
- Each queue has independent scaling, visibility timeout, and retry configuration
- DLQ per queue enables targeted dead letter analysis

**Negative:**
- SNS wraps the message in an envelope — consumers must unwrap `sns_payload["Message"]`
  before accessing order data (extra parsing step, source of bugs if forgotten)
- Two queues means two Lambda functions to monitor and maintain
- No built-in message ordering (standard SQS, not FIFO)