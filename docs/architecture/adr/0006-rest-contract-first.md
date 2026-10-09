# ADR-0006: REST contract first

## Status

Accepted V1; decision2026-10-04.

## Context

Dart and TypeScript need one testable wire source and deterministic commands.

## Decision

OpenAPI3.1 REST per service domain, JWT/HMAC security, typed bodies, receipts, explicit errors.

## Alternatives

GraphQL; gRPC; handwritten duplicate DTO contracts.

## Rationale

REST works with Functions/local HTTP and Flutter; generated types stay separate from domain models.

## Consequences

Schema compatibility and fixtures are mandatory; provider protocol is behind AI adapters.

## Revisit triggers

Revisit if a demonstrated bandwidth/streaming use case cannot be served by current HTTP plus bounded provider WebSocket.

Canonical specification: [owner](../../api/openapi.yaml).

