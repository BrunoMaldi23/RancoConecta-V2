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
flutter run --dart-define=APP_ENVIRONMENT=development --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

Supabase CLI can be installed later and used to apply migrations locally or remotely. Do not link or push to a production Supabase project without explicit credentials and approval.
