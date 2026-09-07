# ADR-007 Row Level Security

## Context

The client talks directly to Supabase APIs, so database access must not rely on UI checks.

## Decision

Enable RLS on all app tables from Sprint 0.

## Consequences

Every new table and workflow must include explicit policies or secure server-side access.
