# Supabase

Project URL:

```text
https://exdaagbftotnnoyetcpg.supabase.co
```

Flutter must receive public configuration at runtime:

```powershell
flutter run -d edge `
  --dart-define=APP_ENVIRONMENT=development `
  --dart-define=SUPABASE_URL="https://exdaagbftotnnoyetcpg.supabase.co" `
  --dart-define=SUPABASE_PUBLISHABLE_KEY="your-publishable-key"
```

Do not commit publishable keys to source files, and never put `service_role`, database passwords, Transbank secrets, or Resend keys in Flutter.

Local CLI:

```powershell
npm install supabase --save-dev
npx supabase --version
npx supabase link --project-ref exdaagbftotnnoyetcpg
```

The remote project was linked from this repo during Sprint 1. The audited foundation migration was applied to the remote project on 2026-09-07:

```powershell
npx supabase db push
```

Seed data for local development is loaded during local resets because `supabase/config.toml` points to `./seed.sql`:

```powershell
npx supabase db reset
```

For the linked remote project, `supabase/seed.sql` was applied on 2026-09-07 with:

```powershell
npx supabase db query --linked --file supabase\seed.sql
```

Verified remote seed counts:

- `regions`: 1
- `communes`: 2
- `locations`: 11
- `categories`: 6
- `subcategories`: 19
- `membership_plans`: 4

Storage buckets prepared by migration:

- `business-media`, public read for published business assets after audited object policies are added.
- `avatars`, public read for profile avatars after audited object policies are added.
- `request-attachments`, private.

Object-level Storage policies are intentionally deferred to avoid insecure broad writes.
