# ADR-0009: Realtime as a refetch hint

## Status

Accepted V1; decision2026-10-04.

## Context

Reward convergence needs fresh UI without exposing command authority over push.

## Decision

Optional Appwrite owner-readable notification subscription; visible-screen polling fallback.

## Alternatives

Realtime as command bus; permanent polling every screen; separate WebSocket server.

## Rationale

Keeps truth in owner HTTP API and reduces client trust surface.

## Consequences

Polling/realtime quotas and disposal required; native speech uses its own provider transport.

## Revisit triggers

Revisit for measured high-volume collaboration or provider capacity with authorized cost.

Canonical specification: [owner](../ARCHITECTURE.md).

