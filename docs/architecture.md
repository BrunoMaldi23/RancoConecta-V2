# Architecture

Ranco Conecta 2.0 starts with a feature-first Flutter architecture backed by Supabase.

The intended flow is:

`UI -> Riverpod controller/provider -> repository -> datasource -> Supabase`

Sprint 0 implements the outer shell, typed configuration, auth foundation, theme, demo home state, and database source of truth. Widgets do not access `Supabase.instance.client` directly; the client is exposed through a controlled provider and repositories.

Feature folders can contain `presentation`, `application`, `domain`, and `data` only when those layers are needed. Empty placeholder files are intentionally avoided.

Future work should keep privileged operations outside Flutter. Administrative actions, payments, and membership activation belong in Edge Functions or secure PostgreSQL functions.

## Multivertical business core

Ranco Conecta treats a provider business as a base business plus explicit `BusinessType`, resolved capabilities, and monetization policy. Flutter should avoid scattered checks like `businessType == lodging`; screens should ask `BusinessCapabilityResolver` or provider context which capabilities are available.

The provider area has an active business context through `activeProviderBusinessProvider`. This supports multiple businesses per user and lets dashboard/navigation adapt to the selected business.

Local domain rules live in:

- `lib/shared/models/business.dart`
- `lib/shared/models/business_capability.dart`
- `lib/shared/models/monetization.dart`
- `lib/features/provider_registration/application/business_onboarding.dart`

Backend commercial source of truth lives in `membership_plans`, `plan_features`, and `commission_rules`. Flutter may resolve policies from fetched data, but must not define definitive prices or commission percentages.

## Business onboarding

Provider onboarding persists to Supabase. Flutter calls RPCs instead of composing privileged writes:

- `create_business_draft` for atomic business + owner membership creation.
- `update_business_draft` for progress saves.
- `submit_business_for_review` for backend validation and status transition.

The lifecycle for Phase 1 is `draft -> pending_review -> published/rejected/changes_requested` once admin review exists. `submitted` is not a separate state because it would duplicate `pending_review`.

The onboarding UI supports common business data for every vertical and complete service basics through `business_services` and `business_coverage`. Lodging remains compatible with the existing `lodging_details`, calendar, rates, photos, and bookings modules.

## Admin review

Admin UI lives under `/admin` and is intentionally separate from provider active business context. Authorization is checked in UI through `currentAdminRoleProvider`, but backend RPCs remain authoritative.

The minimum review surface includes:

- `/admin`: status counters.
- `/admin/businesses` and `/admin/businesses/pending`: paginated review list.
- `/admin/businesses/:id`: read-only detail and administrative actions.

Administrative actions are not optimistic. UI waits for RPC confirmation before refreshing.
