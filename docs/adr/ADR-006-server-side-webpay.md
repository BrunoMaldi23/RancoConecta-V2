# ADR-006 Server-Side Webpay

## Context

Transbank credentials and payment commits are sensitive.

## Decision

Webpay integration will run through Supabase Edge Functions and backend-only secrets.

## Consequences

Flutter never handles private payment secrets, and payment state can be committed idempotently.
