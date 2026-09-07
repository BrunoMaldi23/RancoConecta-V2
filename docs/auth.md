# Auth

Supabase Auth is the identity provider. Flutter receives only public configuration through `--dart-define`:

- `APP_ENVIRONMENT`
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

If Supabase values are missing, the app starts in a safe development state and shows that the backend is not configured.

The initial auth layer includes:

- `AuthRepository`
- `SupabaseAuthRepository`
- `authStateProvider`
- `/sign-in` route placeholder

No demo users are seeded in SQL because Supabase Auth users should be created through Auth APIs, the dashboard, or a secure local script in a later sprint. Administrative role assignment must not be possible from the client.
