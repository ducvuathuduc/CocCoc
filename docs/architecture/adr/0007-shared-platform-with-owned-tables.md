# ADR-0007: Shared platform with owned tables

## Status

Accepted V1; decision2026-10-04.

## Context

Free resource counts favor one database; each service must remain authoritative for its writes.

## Decision

Service-prefixed TablesDB tables, explicit allowlist adapters, no cross-service writes or native relationship joins.

## Alternatives

Database per service; unrestricted shared repository; assumed table-scoped API keys.

## Rationale

Preserves ownership within resource budget; managed API scope is explicitly not hard table isolation.

## Consequences

Compromised admin key has project-wide blast radius; negative ownership/permission tests mandatory.

## Revisit triggers

Hard isolation/security requirements require verified credential constraints and funded/project allocation ADR.

Canonical specification: [owner](../../data/DATA_MODEL.md).

