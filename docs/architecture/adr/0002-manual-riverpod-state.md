# ADR-0002: Manual Riverpod state

## Status

Accepted V1; decision2026-10-04.

## Context

Async auth, cache, lessons and speech need controlled lifetimes and test overrides.

## Decision

Use manual Riverpod Notifier/AsyncNotifier; immutable sealed domain states; no provider code generation.

## Alternatives

BLoC/Cubit; Provider/ChangeNotifier; generated Riverpod.

## Rationale

Weighted comparison favors Riverpod for async lifecycle and agent reliability with modest boilerplate.

## Consequences

Cancellation/disposal and race tests remain mandatory; codegen remains limited to DTOs/Drift.

## Revisit triggers

Revisit only after repeated measured lifecycle defects; package familiarity alone does not justify replacement.

Canonical specification: [owner](../STACK.md).

