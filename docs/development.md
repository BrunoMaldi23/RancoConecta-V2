# Development

Requirements:

- Flutter SDK
- Dart SDK
- Git
- Supabase CLI, optional for Sprint 0

Install dependencies:

```powershell
flutter pub get
```

Run checks:

```powershell
dart format .
flutter analyze
flutter test
```

Run locally without Supabase:

```powershell
flutter run
```

Run with Supabase public config:

```powershell
flutter run -d edge `
  --dart-define=APP_ENVIRONMENT=development `
  --dart-define=SUPABASE_URL="https://exdaagbftotnnoyetcpg.supabase.co" `
  --dart-define=SUPABASE_PUBLISHABLE_KEY="your-publishable-key"
```

Supabase CLI is installed as a local dev dependency:

```powershell
npx supabase --version
npx supabase link --project-ref exdaagbftotnnoyetcpg
```

Remote `db push` mutates the linked database and should only run with explicit approval after reviewing the migration. The Sprint 1 foundation migration and seed were applied to `exdaagbftotnnoyetcpg` on 2026-09-07.
