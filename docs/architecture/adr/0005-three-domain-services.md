# ADR-0005: Three domain services

## Status

Accepted V1; decision2026-10-04.

## Context

Microservices are required without fragmented critical learning transactions.

## Decision

Learning owns content/course/session/review; Progress owns rewards/profile/social; AI owns provider/quota/jobs.

## Alternatives

One backend monolith; separate auth/catalog/notification/speech/analytics services.

## Rationale

Three independently deployable units satisfy isolation of failure/release work while retaining useful domain cohesion.

## Consequences

Eventual rewards; logical table isolation in one database; no extra gateway/broker.

## Revisit triggers

Split further only for proven independent scale/security/team ownership requiring separate deployment.

Canonical specification: [owner](../SERVICE_CATALOG.md).

