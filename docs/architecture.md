# Architecture

Ranco Conecta 2.0 starts with a feature-first Flutter architecture backed by Supabase.

The intended flow is:

`UI -> Riverpod controller/provider -> repository -> datasource -> Supabase`

Sprint 0 implements the outer shell, typed configuration, auth foundation, theme, demo home state, and database source of truth. Widgets do not access `Supabase.instance.client` directly; the client is exposed through a controlled provider and repositories.

Feature folders can contain `presentation`, `application`, `domain`, and `data` only when those layers are needed. Empty placeholder files are intentionally avoided.

Future work should keep privileged operations outside Flutter. Administrative actions, payments, and membership activation belong in Edge Functions or secure PostgreSQL functions.
