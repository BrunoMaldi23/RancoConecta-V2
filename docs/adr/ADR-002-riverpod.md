# ADR-002 Riverpod

## Context

The app needs testable state management without global mutable service access.

## Decision

Use Riverpod providers for configuration, repositories, auth state, and feature state.

## Consequences

Dependencies can be overridden in tests and widgets avoid direct backend coupling.
