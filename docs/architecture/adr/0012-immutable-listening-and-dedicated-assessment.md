# ADR-0012: Immutable listening and dedicated assessment

## Status

Accepted V1; scored capability gated; decision2026-10-04.

## Context

Ordinary lesson listening must survive offline; speech recognition is not pronunciation measurement.

## Decision

Pregenerate versioned listening assets; Azure assessment only after entitlement/eval; otherwise honest STT/record-replay null score.

## Alternatives

Live TTS on every playback; transcript similarity as numeric accent score; bundled on-device Whisper scorer.

## Rationale

Static assets reduce recurring cost/latency; dedicated assessment supplies supported metrics.

## Consequences

Prosody/stress may be unavailable; silence/noise fails safely; every media prompt has equivalent written action.

## Revisit triggers

Revisit with actual dedicated scoring evidence; no quality claim from model capability alone.

Canonical specification: [owner](../../ai/AI_EVALS.md).

