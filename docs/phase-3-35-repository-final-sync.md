# Fase 3.35 — cierre definitivo del repositorio

Fecha: 2026-10-07

## Estado productivo

La producción ya estaba actualizada antes de esta sincronización: 64/64 migraciones aplicadas, cero pendientes, cuatro Edge Functions activas y frontend con build automático GitHub → Vercel. Los dominios `rancoconecta.cl` y `www.rancoconecta.cl` estaban operativos.

Esta fase solo verificó y sincronizó el repositorio. No se ejecutaron `supabase db push`, `supabase functions deploy`, `supabase secrets set`, cambios de datos ni deploy manual de Vercel.

## Repositorio

- Branch: `main`.
- El commit `27dc8d9c01e30cf156b7e4259708370a281f59ab` ya contenía el backend pendiente: 64 migraciones, las cuatro funciones activas (`admin-user`, `notify-provider-review`, `submit-contact`, `submit-request`), tests y documentación de las fases anteriores.
- Las migraciones y funciones están físicamente presentes y versionadas. El commit existente no se modificó ni se reescribió.
- Modelo de producto comprobado en contratos: `admin`, `provider` y visitante anónimo; `legacy_customer` queda como valor histórico. Los roles de producto antiguos `super_admin` y `customer` no forman parte del modelo activo.
- El flujo anónimo incluye solicitud, idempotencia, límites de frecuencia, RLS y contrato SQL en `supabase/tests/phase_3_32_anonymous_flows.sql`.
- Las migraciones versionadas incluyen revocación de RPC administrativa a `anon`, endurecimiento de helpers SECURITY DEFINER y los controles de TRUNCATE.
- `.vercel/.env.production.vars` está excluido por `.vercel/` en `.gitignore`; también se excluyen `.env` privados, build local, `.dart_tool`, `vercel_output`, dumps, backups y `.playwright-cli`. No se inspeccionó ni se incluyó ningún valor local.

## Validación local

- `flutter analyze`: PASS, sin problemas.
- `flutter test`: PASS, 634/634.
- `flutter build web --release`: PASS, generado `build/web`.
- `scripts/check_text_encoding.ps1`: PASS.
- `git diff --check`: PASS.
- Deno: 11/11 tests PASS.
- Edge type-check: 4/4 PASS.
- Contratos SQL relevantes: 10/10 PASS, según la corrida aislada registrada en `docs/phase-3-33-production-apply-report.md`; no se ejecutaron contra producción en esta fase.

## Push y Vercel

Al iniciar la fase, `HEAD` y `origin/main` ya coincidían en `27dc8d9c01e30cf156b7e4259708370a281f59ab` y el árbol de trabajo estaba limpio. Ese commit ya estaba sincronizado en GitHub; no se creó un commit backend duplicado ni se hizo un push redundante.

La última producción de Vercel observada para ese estado terminó `Ready` (`dpl_4zUcS9x5aJQwMXhLfr4kPX2E9mQC`) y conservó los aliases de ambos dominios. Las rutas `/`, `/explore`, `/business/demo` y `/login` respondieron HTTP 200; el dominio raíz redirigió al dominio `www`. La validación interactiva del navegador no pudo ejecutarse porque el entorno Playwright no tiene Chrome instalado; por eso no se registran resultados de consola o llamadas API de navegador.

## Cierre

El backend que ya estaba aplicado en producción quedó representado en Git y local/remote estaban sincronizados. No hubo segundo apply de Supabase. El commit backend sincronizador es `27dc8d9c01e30cf156b7e4259708370a281f59ab`.
