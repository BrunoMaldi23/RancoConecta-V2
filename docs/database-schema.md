# Database Schema

The source of truth is `supabase/migrations/20260907000000_sprint_0_foundation.sql`.

Sprint 0 creates catalog, marketplace, request, quote, membership, payment, notification, audit, and chat-preparation tables. UUIDs are used for user-owned and transactional records. Stable PostgreSQL enums store internal states in English.

Sprint 1 audited the same migration before remote application and added automatic profile creation from `auth.users`, function `search_path` hardening, explicit role/status protection, and prepared Storage buckets.

Key tables:

- `profiles`
- `regions`, `communes`, `locations`
- `categories`, `subcategories`
- `businesses`, `business_services`, `business_coverage`, `business_hours`, `business_media`
- `service_requests`, `quotes`
- `favorites`, `reviews`
- `membership_plans`, `memberships`, `payments`
- `notifications`, `audit_logs`
- `conversations`, `messages`

`updated_at` is maintained through the reusable `set_updated_at()` trigger. Service request public codes use `RC-YYYY-000001` format through a PostgreSQL sequence. The sequence is safe for uniqueness, though future distributed or imported historical data may require year-scoped sequence strategy.

PostGIS is intentionally not enabled in Sprint 0. Latitude and longitude are stored with constraints, and `business_coverage.radius_km` prepares for later geospatial queries.
