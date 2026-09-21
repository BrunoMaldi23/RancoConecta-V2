# Database Schema

The source of truth is the ordered migration set in `supabase/migrations`.

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
- `lodging_details`, `lodging_calendar`, `lodging_bookings`
- `operations`, `operation_events`
- `business_members`

Phase 0.2 adds `operations` and `operation_events` as a non-destructive transactional foundation. Existing specialized tables such as `service_requests`, `quotes`, and `lodging_bookings` are intentionally not migrated yet. The expected future relationship is:

- `operations.status`: shared high-level lifecycle for cross-feature activity.
- `service_requests.status`: service-request-specific lifecycle already represented by `ServiceRequestStatus`.
- `lodging_bookings.status`: lodging booking lifecycle, currently `pending`, `accepted`, `rejected`, `cancelled`.

Until a controlled RPC/Edge Function migration connects these models, specialized tables remain the source of truth for their current screens.

`business_members` is backfilled from `businesses.owner_id`. The existing `owner_id` remains compatible while the app moves away from assuming one user owns only one business.

`updated_at` is maintained through the reusable `set_updated_at()` trigger. Service request public codes use `RC-YYYY-000001` format through a PostgreSQL sequence. The sequence is safe for uniqueness, though future distributed or imported historical data may require year-scoped sequence strategy.

PostGIS is intentionally not enabled in Sprint 0. Latitude and longitude are stored with constraints, and `business_coverage.radius_km` prepares for later geospatial queries.

## Phase 1 multivertical additions

Phase 1 keeps the existing `business_type` enum for compatibility and extends it with `tourism` and `emergency`. Categories/subcategories remain marketplace taxonomy; `business_type` is the behavior driver.

New tables:

- `plan_features`: per-plan feature switches and limits.
- `commission_rules`: transaction fee rules by `business_type` and `operation_type`, separate from subscriptions.
- `business_sensitive_change_requests`: future review queue for ownership, identity, business type, legal, publication, and verification-sensitive changes.
- `business_offers`: promotions published by the business.
- `featured_placements`: future advertising/featured placement products managed by Ranco.

Business onboarding adds nullable profile fields to `businesses`: `primary_category_id`, `address_text`, `onboarding_metadata`, `submitted_at`, and `changes_requested_note`.

Business creation and review submission are handled through PostgreSQL RPCs:

- `create_business_draft`: creates `businesses` plus owner `business_members` atomically.
- `update_business_draft`: persists common onboarding data, service selections, coverage, and lodging details when applicable.
- `business_review_requirements`: returns backend-authoritative minimum requirements.
- `submit_business_for_review`: validates ownership and requirements, then moves the business to `pending_review`.

## Phase 2 admin review additions

New table:

- `business_review_events`: workflow history for submitted, resubmitted, changes requested, rejected, published, suspended, and restored events.

Admin RPCs:

- `current_user_is_admin`
- `admin_business_review_stats`
- `admin_list_business_reviews`
- `admin_get_business_review`
- `admin_request_business_changes`
- `admin_reject_business`
- `admin_publish_business`
- `admin_suspend_business`
- `admin_restore_business`

Admin publication does not change `verification_status`; a business may be `published + unverified`.
