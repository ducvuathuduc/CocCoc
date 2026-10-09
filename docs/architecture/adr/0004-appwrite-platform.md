# ADR-0004: Appwrite platform

## Status

Accepted V1; account allocation gated; decision2026-10-04.

## Context

User requires Appwrite and zero new demo spend; current Education offer is temporary.

## Decision

Use Auth, one TablesDB database, one Storage bucket, Functions and optional Realtime hints.

## Alternatives

Firebase/Supabase replacement; self-hosting every component; custom auth.

## Rationale

Keeps identity/data operational work managed; one database/bucket survives Free resource counts.

## Consequences

Education expiry and Free function limit require the documented local service demo fallback; no perpetual Pro claim.

## Revisit triggers

Revisit on incompatible transaction/runtime behavior or verified quota exhaustion with authorized budget.

Canonical specification: [owner](../../devops/COST_MODEL.md).

