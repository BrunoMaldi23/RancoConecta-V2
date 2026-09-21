# Ranco Conecta 2.0

Ranco Conecta 2.0 is the production foundation for a local platform connecting people in Lago Ranco, Futrono, and nearby Chilean localities with services, commerce, gastronomy, and lodging providers.

## Stack

- Flutter and Dart
- Material 3
- Riverpod
- go_router
- Supabase Auth, PostgreSQL, Storage, Realtime, Edge Functions
- PostgreSQL Row Level Security

## Current Status

Sprint 0 establishes the executable Flutter shell, typed environment configuration, initial auth architecture, responsive navigation, design system, PostgreSQL schema, RLS policies, seed data, tests, and documentation.

The current codebase also includes Supabase-backed discovery, favorites, direct service requests, reviews, provider-facing lodging management, lodging calendar, lodging photos, lodging rates, and lodging booking workflows. Phase 0.2 adds the first non-destructive foundation for multi-business ownership and future transactional operations through `business_members`, `operations`, and `operation_events`.

Phase 1 adds the multivertical foundation: `business_type` is separate from public categories, capabilities are resolved centrally, publication is free by default, and memberships, commissions, and promoted listings are separate commercial concepts. See `docs/business-model.md`.

Phase 1 closure adds a functional provider onboarding flow backed by Supabase RPCs. Authenticated users can create a business draft, save progress, resume onboarding, complete service basics, and submit the business to `pending_review` without being able to self-publish or self-verify.

Phase 2 adds the minimum admin review workflow. Admin/super admin users can review pending businesses, request changes, reject, publish, suspend, and restore through backend RPCs. The public app continues to show only `published` businesses. See `docs/admin-review-workflow.md` and `docs/pre-deploy-checklist.md`.

## Setup

```powershell
flutter pub get
```

Optional Supabase values are passed as Dart defines:

```powershell
flutter run -d edge `
  --dart-define=APP_ENVIRONMENT=development `
  --dart-define=SUPABASE_URL="https://exdaagbftotnnoyetcpg.supabase.co" `
  --dart-define=SUPABASE_PUBLISHABLE_KEY="your-publishable-key"
```

Without Supabase config, the app starts in safe development mode.

## Feature Flags

Incomplete modules stay disabled by default and must still be protected by RLS/backend authorization:

```powershell
--dart-define=CHAT_ENABLED=false
--dart-define=PAYMENTS_ENABLED=false
--dart-define=QUOTES_ENABLED=false
--dart-define=LODGING_ENABLED=true
```

## Checks

```powershell
dart format .
flutter analyze
flutter test
```

## Production Deploy

Production uses the committed Flutter web bundle in `vercel_output`.

Create `.env.production.local` locally with only public Flutter values required by the app:

```powershell
APP_ENVIRONMENT=production
SUPABASE_URL=https://exdaagbftotnnoyetcpg.supabase.co
SUPABASE_PUBLISHABLE_KEY=your-publishable-key
```

Build, verify, commit, push, and deploy to Vercel production:

```powershell
npm run deploy:production
```

For a local production build without Git/Vercel deploy:

```powershell
npm run build:production
```

## Structure

- `lib/app`: root app widget
- `lib/bootstrap`: startup and dependency initialization
- `lib/config`: typed environment config
- `lib/router`: go_router and responsive shell
- `lib/theme`: design system and Material themes
- `lib/core`: shared errors, result, logging, base widgets
- `lib/features`: feature-first modules
- `lib/shared`: shared domain-style models
- `supabase`: migrations, seed, Edge Function workspace
- `docs`: architecture, security, business, and operational notes

## Sprint 1 Slice

The app now includes real Supabase-backed foundations for sign up, sign in, password recovery, profile read/update, categories, locations, published businesses, business detail, favorites, direct service requests, and request history/detail.

## Phase 0.2 Foundation

- `operations`: shared future transaction header for service and booking flows, not yet connected to existing requests/bookings.
- `operation_events`: immutable event history for future state transitions.
- `business_members`: membership model for one user with many businesses and one business with many users.
- Provider management routes require an authenticated user; Supabase RLS remains the final authorization layer.
- `ProviderBusinessRepository.getMyBusiness()` remains for compatibility, while `getMyBusinesses()` and membership-oriented APIs prepare the multi-business model.

## Supabase

Schema changes live in `supabase/migrations`. Catalog seed data lives in `supabase/seed.sql`. Service role keys and privileged workflows must stay server-side.
