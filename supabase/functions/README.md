# Supabase Edge Functions

Sprint 0 only reserves this directory. Future privileged workflows live here:

- Webpay transaction creation, callback validation, and idempotent commits.
- Administrative actions such as changing roles, approving businesses, suspending users, and activating memberships.
- Email and notification fan-out.

Do not put service role keys in Flutter. Edge Functions must read secrets from Supabase environment variables.
