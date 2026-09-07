# RLS Test Plan

These checks should run against a disposable Supabase project or local Supabase database after migrations and seed are applied.

Required cases:

- User A cannot update User B's `profiles` row.
- User A cannot set `role = 'admin'` or `role = 'super_admin'`.
- Guest can read only `businesses` with `publication_status = 'published'`.
- Owner can read their own unpublished business.
- Customer can create a request only with `customer_id = auth.uid()`.
- Customer cannot create a request for another customer.
- Customer cannot update `payments`.
- Customer cannot activate or update `memberships`.
- User A cannot read User B's `notifications`.
- User A cannot insert, delete, or read User B's `favorites`.

Recommended method:

1. Create two Supabase Auth users through Auth APIs or dashboard.
2. Confirm profiles were created by the `handle_new_auth_user()` trigger.
3. Use each user's JWT with the REST API or Supabase client to execute the cases above.
4. Keep SQL service-role setup separate from client-role assertions.

Do not run these tests against production data.
