# Fase 3.26.2A — hotfix grants-only

Fecha: 2026-10-07. Proyecto: **RancoConecta** (`exdaagbftotnnoyetcpg`). No se expusieron secretos ni datos personales.

## Resultado

**PRODUCTION SECURITY HOTFIX: APPLIED.** Se ejecutó únicamente `20261007160000_emergency_grants_only.sql` mediante `supabase db query --linked --file`; no se usó `db push` ni se aplicaron migraciones funcionales. Después se registró solo esa versión en el historial con `supabase migration repair --linked --status applied 20261007160000`.

| Control | Antes | Después |
|---|---:|---:|
| TRUNCATE efectivo para `anon` en tablas `public` | 42 | 0 |
| TRUNCATE efectivo para `authenticated` en tablas `public` | 42 | 0 |
| RPC admin SECURITY DEFINER ejecutables por `anon` | 12 | 0 |
| RPC admin objetivo con EXECUTE efectivo para `authenticated` | 12 | 12 |
| RPC admin objetivo con EXECUTE directo para `PUBLIC` | 9 | 0 |

El postflight consultó `has_table_privilege`, `has_function_privilege` y los ACL efectivos. Cada una de las doce firmas fue comprobada individualmente. Las doce siguen ejecutables por `authenticated`, de acuerdo con el alcance de esta fase; esa autorización continúa siendo peligrosa mientras el helper global remoto acepte tenant admin.

## Objetos auditados y migración

Las doce firmas fueron `admin_analytics_summary()`, `admin_business_review_detail(uuid)`, `admin_business_review_queue(text,text,text,integer,integer)`, `admin_business_review_stats()`, `admin_get_business_review(uuid)`, `admin_list_users(integer,integer)`, `admin_publish_business(uuid)`, `admin_reject_business(uuid,text,boolean)`, `admin_request_business_changes(uuid,text)`, `admin_restore_business(uuid)`, `admin_suspend_business(uuid,text)` y `admin_update_whatsapp_settings(text,boolean,boolean,boolean,boolean)`.

La migración revoca TRUNCATE de `anon` y `authenticated` sobre las tablas de `public`; retira EXECUTE de `anon` de las doce funciones y de `PUBLIC` allí donde ACL daba EXECUTE efectivo. No toca `service_role`, grants DML ordinarios, funciones, políticas, datos ni privilegios por defecto. Tiene assertions que fallan si quedan grants efectivos peligrosos.

El borrador más amplio `20261007150000_emergency_production_privilege_hardening.sql` fue revisado y retirado antes de aplicar; contenía cambios de privilegios por defecto y un barrido más amplio de funciones que excedían esta fase. No fue aplicado ni quedó en el historial.

## Rollback exacto preparado

[`scripts/rollback-phase-3-26-2a-grants-only.sql`](../scripts/rollback-phase-3-26-2a-grants-only.sql) restaura únicamente los 42 grants TRUNCATE previos, EXECUTE de `anon` en las doce firmas y EXECUTE de `PUBLIC` en las nueve firmas donde existía. Los grants de `authenticated`/`service_role` que se conservaron no requieren rollback. El archivo **no se ejecutó**.

## Pruebas del SQL

`supabase/migrations/20261007160000_emergency_grants_only.sql` pasó en PostgreSQL 16 aislado con los grants de producción modelados, incluso al repetirse. `supabase/tests/phase_3_26_2_security_hotfix.sql` pasó: cero TRUNCATE, cero ejecución anónima en las RPC objetivo y SELECT público/autenticado a `businesses` conservado. EXECUTE de `authenticated` y `service_role` se conservó en el modelo. La prueba no sustituye reset Supabase completo: Docker no estaba disponible (`dockerDesktopLinuxEngine` ausente).

## Smoke de lecturas públicas posterior al cambio

Playwright contra `https://www.rancoconecta.cl` confirmó Home, Explore, categorías, detalle, fotos, Términos, Privacidad y la UI de Contacto. Lectura de negocio, reseñas, alojamiento e imágenes Storage respondieron HTTP 200; la vista del detalle generó la métrica no crítica `record_business_analytics_event` con HTTP 204. No hubo errores de consola ni 401/403/404/5xx observados. Contacto muestra “Canal de contacto pendiente de habilitación”; no se envió ningún mensaje.

## Riesgos pendientes fuera del hotfix

- **TENANT ADMIN GLOBAL AUTHORIZATION: STILL PRESENT.** El `current_user_is_admin()` remoto acepta perfiles activos con rol `admin` o `super_admin` y no exige sesión SuperAdmin explícita. `super_admin_sessions` no existe en remoto; perfiles observados: 1 admin, 0 super_admin. Es un **BLOQUEO DE SEGURIDAD PENDIENTE** para la secuencia completa de separación de roles. No fue modificado.
- En el remoto se encontraron tres helpers SECURITY DEFINER internos aún ejecutables por anon/PUBLIC: `record_business_review_event`, `notify_business_managers` y `sync_context_conversation_members`. Su hardening local está preparado en `20261007170000_revoke_internal_definer_helpers.sql`; no se aplicó a producción.
- `contact_messages` tampoco existe remotamente; Contacto y `submit-contact` están implementados localmente y pendientes de migración/deploy.
- Se mantienen las 24 migraciones funcionales anteriores pendientes. No fueron marcadas como aplicadas.

## Historial remoto después del hotfix

El remoto contiene 32 versiones aplicadas: las 31 anteriores hasta `20261003181310` más `20261007160000`. Las 24 migraciones funcionales siguen pendientes; la migración local adicional `20261007170000` también está pendiente. No hubo `db push`.

El hotfix reduce el riesgo inmediato de TRUNCATE anónimo/autenticado y ejecución anónima de las doce RPC admin. La producción queda **PARTIALLY HARDENED — ROLE SEPARATION PENDING**; no se declara totalmente endurecida.
