# ADR-0014: Windows development with cloud macOS

## Status

Accepted V1; signing conditional; decision2026-10-04.

## Context

Developer is on Windows; local Xcode/iOS simulator cannot be assumed.

## Decision

Local Android Flutter workflow; GitHub standard macOS unsigned simulator build; Codemagic personal M2 fallback; signed IPA optional existing eligible team.

## Alternatives

Windows Xcode emulation; Apple membership assumed free; Bitrise paid baseline.

## Rationale

Provides a reproducible iOS build path without new signing purchase.

## Consequences

Simulator cannot certify real microphone/Bluetooth; physical iOS remains pending if signing unavailable.

## Revisit triggers

Revisit upon real Mac/iPhone/team access or runner quota change.

Canonical specification: [owner](../../devops/CI_CD.md).

