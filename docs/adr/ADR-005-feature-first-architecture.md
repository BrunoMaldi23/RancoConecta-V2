# ADR-005 Feature-First Architecture

## Context

Ranco Conecta will grow across discovery, requests, quotes, chat, provider tools, payments, and admin.

## Decision

Organize Flutter code by feature with `presentation`, `application`, `domain`, and `data` layers only where useful.

## Consequences

Features can evolve independently while shared primitives stay in `core` and `shared`.
