# ADR-0011: Bounded direct native voice

## Status

Accepted V1; native enablement gated P8; decision2026-10-04.

## Context

Appwrite synchronous Functions cannot carry a long duplex audio relay; native speech is requested.

## Decision

Candidate Gemini direct WebSocket with constrained single-use short credential; server quota/slot reservation; TURN fallback.

## Alternatives

Always-on hosted relay; paid OpenAI baseline; timer-only mobile budget enforcement.

## Rationale

Avoids extra hosting and raw-audio Function limits while retaining conditional live capability.

## Consequences

Provider expiry/config enforcement must pass; ambiguous mint consumes budget and never remints; Appwrite cannot terminate the direct socket.

## Revisit triggers

If provider bounds fail disable native; server relay needs justified hosting/security/cost ADR.

Canonical specification: [owner](../../ai/AI_ARCHITECTURE.md).

