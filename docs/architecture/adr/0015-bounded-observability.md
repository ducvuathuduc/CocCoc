# ADR-0015: Bounded observability

## Status

Accepted V1; decision2026-10-04.

## Context

Student resources need operational evidence without raw audio/transcript leakage or cost escalation.

## Decision

Structured redacted logs, request IDs, metrics/traces sampling; bounded Grafana Free and optional Sentry; local fallback.

## Alternatives

Full session replay; unbounded analytics pipeline; separate observability service.

## Rationale

Tracks completion/event lag/quota failures with a small operational footprint.

## Consequences

No secrets/audio by default; numeric Sentry free quota remains account gate; export failures cannot block learning.

## Revisit triggers

Revisit after measured incidents that current evidence cannot diagnose within allocation.

Canonical specification: [owner](../../devops/OPERATIONS.md).

