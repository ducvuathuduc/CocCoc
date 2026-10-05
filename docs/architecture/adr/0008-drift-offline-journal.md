# ADR-0008: Drift offline journal

## Status

Accepted V1; decision2026-10-04.

## Context

Poor network and process death must preserve progress without trusting client rewards/time.

## Decision

Transactional per-user SQLite journal and immutable content/audio cache; server regrades offline completion.

## Alternatives

SharedPreferences queue; Hive-only journal; remote-only application.

## Rationale

SQLite transaction/restart tests express replay invariants and scoped cleanup clearly.

## Consequences

Offline practice cannot unlock later nodes until sync; public grading rules offer no strong anti-cheat guarantee.

## Revisit triggers

Revisit when measured cache/journal requirements exceed SQLite approach, not speculative scale.

Canonical specification: [owner](../OFFLINE.md).

