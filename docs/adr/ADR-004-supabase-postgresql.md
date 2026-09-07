# ADR-004 Supabase PostgreSQL

## Context

The product needs auth, relational data, RLS, storage, realtime, and serverless functions.

## Decision

Use Supabase with PostgreSQL as the primary backend.

## Consequences

Relational rules and RLS can live close to the data. Privileged logic must be carefully kept server-side.
