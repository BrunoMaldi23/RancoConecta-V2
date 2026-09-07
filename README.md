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

## Setup

```powershell
flutter pub get
```

Optional Supabase values are passed as Dart defines:

```powershell
flutter run --dart-define=APP_ENVIRONMENT=development --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

Without Supabase config, the app starts in safe development mode.

## Checks

```powershell
dart format .
flutter analyze
flutter test
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

## Supabase

Schema changes live in `supabase/migrations`. Catalog seed data lives in `supabase/seed.sql`. Service role keys and privileged workflows must stay server-side.
