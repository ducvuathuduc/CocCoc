# ADR-0003: TypeScript backend runtime

## Status

Accepted V1; runtime availability gated P1; decision2026-10-04.

## Context

Appwrite is primary; Windows/local execution and three small cloud routers must share logic.

## Decision

TypeScript on Node22 with thin local HTTP and Appwrite Function context adapters.

## Alternatives

Dart server; Go; Python; NestJS/full framework.

## Rationale

Current Appwrite SDK and JS platform fit small functions; no demonstrated ML dependency requires Python.

## Consequences

Runtime list/SDK compatibility and generated artifact tests must pass before cloud deploy.

## Revisit triggers

If Node22 is unavailable use local adapter pending supported-runtime ADR; Python requires proven unmet ML need.

Canonical specification: [owner](../STACK.md).

