# Pre-deploy checklist

Destino previsto: `https://ranco-conecta-v2.vercel.app/`

## Migraciones

- Proyecto Supabase enlazado confirmado: `exdaagbftotnnoyetcpg`.
- Migraciones aplicadas en orden hasta `20260921150000_admin_review_workflow.sql`.
- RLS revisado en tablas nuevas y politicas de storage/admin/onboarding.
- RPCs admin y onboarding incluidos en migraciones aplicadas.
- Confirmado que el frontend usa `SUPABASE_PUBLISHABLE_KEY`, no `service_role`.
- Nota de deriva resuelta: en remoto `membership_plans.id` es `uuid`; `plan_features.plan_id` queda como `text` sin FK rigido y compara con `mp.id::text` para compatibilidad.

## Variables de entorno

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`
- `APP_ENVIRONMENT`
- `CHAT_ENABLED=false`
- `PAYMENTS_ENABLED=false`
- `QUOTES_ENABLED=false`
- `LODGING_ENABLED=true`

## Validacion automatica

- `dart format .`: OK, 98 archivos, 0 cambios.
- `flutter analyze`: OK, sin issues.
- `flutter test`: OK, 25 tests.
- `flutter build web --release --dart-define-from-file=.dart_tool/production_public_defines.env`: OK.
- `vercel_output`: sincronizado desde `build/web`.

## Smoke tests manuales

1. Crear cuenta.
2. Crear negocio.
3. Guardar draft.
4. Retomar onboarding.
5. Enviar a revision.
6. Login admin.
7. Ver pendiente.
8. Solicitar cambios.
9. Proveedor corrige.
10. Reenvia.
11. Admin publica.
12. Negocio aparece en Explorar.
13. Usuario externo abre ficha.
14. Proveedor entra dashboard.
15. Suspender negocio.
16. Confirmar desaparicion publica.
17. Restaurar.

## Compatibilidad

- Auth.
- Home.
- Explore.
- Favorites.
- Requests.
- Reviews.
- Lodging.
- Lodging bookings.
- Provider dashboard.

## Deploy

- Configuracion Vercel local confirmada para proyecto `ranco-conecta-v2`.
- Deploy automatico no ejecutado: requiere aprobacion humana explicita para publicar a produccion con token externo.
- Comando previsto desde este workspace:

```powershell
$tokenLine = Get-Content -LiteralPath .env.local | Where-Object { $_ -match '^VERCEL_OIDC_TOKEN=' } | Select-Object -First 1
$env:VERCEL_TOKEN = ($tokenLine -replace '^VERCEL_OIDC_TOKEN=', '').Trim('"')
npm.cmd exec --yes --package vercel -- vercel deploy --prod --yes --token $env:VERCEL_TOKEN
```

## Smoke local

- `http://127.0.0.1:8787/`: 200.
- `http://127.0.0.1:8787/index.html`: 200.
- `http://127.0.0.1:8787/flutter_bootstrap.js`: 200.
- `http://127.0.0.1:8787/main.dart.js`: 200.
