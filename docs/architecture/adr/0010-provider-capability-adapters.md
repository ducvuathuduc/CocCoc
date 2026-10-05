# ADR-0010: Provider capability adapters

## Status

Accepted V1; decision2026-10-04.

## Context

Free allocations, previews and scorer availability vary by account/time.

## Decision

Server-selected allowlisted adapters with explicit capability flags, nullable scores and authored fallback.

## Alternatives

Provider logic in widgets; automatic paid fallback; LLM-generated pronunciation scores.

## Rationale

Provider replacement stays behind stable DTOs and cannot alter grading/reward ownership.

## Consequences

Optional capabilities need account/device evidence; stable tutoring still cannot replace curated answer acceptance.

## Revisit triggers

Revisit provider identity through capability probe, cost review and evals; breaking interface needs ADR.

Canonical specification: [owner](../../ai/AI_ARCHITECTURE.md).

