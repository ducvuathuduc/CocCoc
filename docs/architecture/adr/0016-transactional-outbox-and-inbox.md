# ADR-0016: Transactional outbox and inbox

## Status

Accepted V1; decision2026-10-04.

## Context

Learning completion must not fail when Progress is down and cannot double-award after retry.

## Decision

Commit session/frontier/receipt/outbox in Learning transaction; signed bounded redelivery; unique Progress inbox/ledger; durable deletion acknowledgements.

## Alternatives

Synchronous cross-service reward transaction; direct fire-and-forget; managed Kafka/Redis broker.

## Rationale

Keeps critical learning atomic and preserves recoverable delivery without another hosted product.

## Consequences

Eventual reward UI, bounded workers, lease/conflict/dead-letter/watermark logic required; verify Free transaction operation limit.

## Revisit triggers

Revisit when measured backlog/reliability warrants funded broker, retaining dedupe and owner boundaries.

Canonical specification: [owner](../../api/EVENTS_ERRORS.md).

