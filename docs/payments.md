# Payments

Webpay is not implemented in Sprint 0.

Future flow:

1. Flutter asks a Supabase Edge Function to create a payment intent.
2. The Edge Function calls Transbank Webpay Plus using backend-only secrets.
3. Transbank redirects or calls back to the backend.
4. The backend validates the transaction.
5. A single idempotent commit updates `payments`.
6. Membership state is activated or extended in PostgreSQL.
7. Flutter receives the result through navigation, polling, or realtime updates.

Requirements for Sprint 1+:

- separate sandbox and production configuration;
- idempotency keys for create and commit operations;
- no Transbank secrets in Flutter;
- no direct client mutation of `payments` or `memberships`.
