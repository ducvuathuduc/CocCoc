# ADR-0001: Flutter feature architecture

## Status

Accepted V1; decision2026-10-04.

## Context

Flutter must remain the Android/iOS application and support a full fake-data UX before backend integration.

## Decision

Feature-first MVVM with optional domain logic for complex state machines.

## Alternatives

Horizontal layer folders; mandatory four-layer Clean Architecture; platform-native app.

## Rationale

Feature ownership keeps screen work local; repositories permit deterministic tests and fake Phase2 demos.

## Consequences

Complex lesson/sync/speech reducers need explicit domain files; simple reads do not need use-case classes.

## Revisit triggers

Revisit when feature boundaries cause repeated import cycles or duplicated domain rules.

Canonical specification: [owner](../../architecture/ARCHITECTURE.md).

