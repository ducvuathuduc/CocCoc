# ADR-0013: Deterministic CI and gated integration

## Status

Accepted V1; decision2026-10-04.

## Context

Routine checks must not spend live AI quota or expose deployment credentials to forks.

## Decision

Linux deterministic PR gates; selected macOS simulator gate; explicit authorized Appwrite integration/staging execution.

## Alternatives

Every PR full cloud/device matrix; untrusted privileged PR workflow; deploy at agent completion.

## Rationale

Meaningful layers run at matching scope with bounded minutes/storage and immutable artifacts.

## Consequences

P1 creates actual workflow/script implementations; document checks alone do not certify application build.

## Revisit triggers

Revisit for measured build time/cost or native compatibility requirements, retaining secret boundaries.

Canonical specification: [owner](../../devops/CI_CD.md).

