# Fase 3.30 — cierre técnico final

Fecha: 2026-10-07. Proyecto revisado: RancoConecta (`exdaagbftotnnoyetcpg`). Producción se usó solo en consultas de lectura. No se aplicaron migraciones, no se escribieron datos ni se desplegó nada.

## Resultado

**TECHNICAL BLOCKERS: 0 / 2**  
**READY FOR PRODUCTION APPLY: CONDITIONAL**

Los dos bloqueos técnicos quedan cerrados en una restauración aislada del snapshot real y en una revisión semántica de las funciones SECURITY DEFINER. La aplicación a producción sigue pendiente de autorización humana y de las decisiones enumeradas al final.

## 1. Snapshot y fidelidad

- Se usó el snapshot cifrado de producción capturado el `2026-10-06 23:05:04 UTC`, proyecto `exdaagbftotnnoyetcpg`. El manifiesto, los seis exports y sus hashes pasaron la verificación DPAPI del script de restore. No se creó otro backup.
- Restauración en PostgreSQL 16 aislado, fuera del repositorio, con ACL privada para el usuario local. Se restauraron los esquemas y datos `public`, `auth` y `storage`; los tres triggers diferidos de `auth.users` se instalaron después de restaurar las funciones públicas.
- El snapshot se contrastó con catálogos actuales de producción en modo read-only. Coincidieron objetos, 739 definiciones de columnas, constraints, indexes, policies, triggers, tipos, ACL de tablas, ACL de funciones de aplicación, sequences y views. Las definiciones de columnas coincidieron por nombre, tipo, nullability, default, generated e identity.
- Excepciones del entorno, no del esquema de aplicación: producción usa PostgreSQL 17 y la réplica aislada PostgreSQL 16; se omitió el grant de propietario `MAINTAIN` que PG16 no reconoce. Cuatro funciones de la extensión `unaccent` tienen metadatos/cuerpo/propietario dependientes de la versión de extensión. La extensión runtime `supabase_vault` y sus dos funciones no se recrearon en PG16. El orden físico `attnum` difiere en dos tablas internas de Auth, pero todas las columnas por nombre y definición coinciden. La publicación de aplicación `supabase_realtime` se recreó con sus cuatro tablas; la publicación runtime de particiones de Realtime no es parte de las migraciones de aplicación.
- La lectura actual de conteos remotos coincidió con el snapshot para las 67 tablas salvo `analytics_events` (73 en snapshot, 75 ahora). Las tablas críticas tuvieron conteos iguales. `notifications` conserva tres filas, pero su fingerprint difiere entre snapshot y lectura remota actual; esa diferencia ya existía antes de migrar y no fue introducida por la secuencia. El replay no alteró su contenido.

## 2. Replay exacto y datos

La lista original de 28 migraciones pendientes se aplicó en timestamp ascendente, cada archivo en su propia transacción. El ensayo se repitió desde una segunda restauración limpia. Las 28 pasaron en ambos replays. Luego pasó `20261007210000_revoke_api_internal_scope_helpers.sql`, nueva corrección encontrada durante la auditoría semántica. No se usó `db push`.

Orden original replayado:

`20261004120000`–`20261004141000` (15 archivos), `20261005000000`–`20261005008000` (9 archivos), `20261007170000`, `20261007180000`, `20261007190000`, `20261007200000`. La secuencia nueva termina con `20261007210000`.

| Métrica | Antes | Después | Resultado |
|---|---:|---:|---|
| profiles | 15 | 15 | sin pérdida |
| roles | admin 1, provider 1, customer 13 | igual | sin reclasificación automática adicional |
| negocios | 12 | 12 | preservados |
| reservas de alojamiento | 7 | 7 | preservadas |
| solicitudes | 0 | 0 | sin cambios |
| notificaciones | 3 | 3 | sin cambios en replay |
| settings | 5 | 10 | cinco defaults/configuraciones de migración |
| audit_logs | 11 | 14 | tres eventos de migración esperados |
| categorías | 27 | 27 | sin cambios |
| owners huérfanos | 0 | 0 | íntegros |

De las 68 tablas del baseline, todos los conteos se conservaron salvo los cinco settings y tres registros de auditoría esperados. Los tres perfiles candidatos ambiguos permanecen `customer`. La FK `businesses.owner_id → profiles(id)` tiene `ON DELETE RESTRICT`. La proyección Home consulta `is_featured`, `accepts_requests`, `rating_avg`, `review_count`, categoría e imágenes sin error de columna.

El ensayo aislado de backfill identificó seis negocios publicados sin categoría: tres con una única categoría activa derivable desde `business_services → subcategories → categories`, tres ambiguos. Actualizó solo las tres filas deducibles y verificó source/resultado; el test terminó con `ROLLBACK`. Las tres ambiguas no cambiaron.

## 3. Schema final y Contacto

El estado final del replay contiene `super_admin_sessions`, `contact_messages`, `contact_submission_rate_limits` y `contact_submission_dedup`; políticas y grants directos impiden abusar las tablas de control/contacto desde la API. El RPC de envío queda solo para `service_role`; el Edge Function valida los campos antes de invocarlo. Las identidades se guardan como hashes, con límite por IP hash (10/h), usuario autenticado (3/h) y email normalizado (3/h), deduplicación de contenido de 10 minutos, llave idempotente durable y resultado `rate_limited` para que Edge responda 429. El contrato SQL de contacto y los tests Deno existentes pasaron. No se hizo un HTTP real de Edge Runtime porque no está levantado el runtime local; esto no impidió el replay PostgreSQL.

## 4. Auditoría semántica SECURITY DEFINER

Se leyeron los cuerpos finales, ACL efectivos, callers y cadenas de autorización de las funciones locales. La matriz completa de las 103 funciones públicas SECURITY DEFINER del estado final está en [phase-3-30-security-definer-audit.csv](phase-3-30-security-definer-audit.csv), con firma, uso, caller, grants efectivos (`PUBLIC`, `anon`, `authenticated`, `service_role`), `search_path`, marcadores de auth/rol/ámbito, SQL dinámico, riesgo y estado.

| Alcance | SAFE | HARDENED | NEEDS_FIX | OBSOLETE |
|---|---:|---:|---:|---:|
| Repo local final, 103 funciones públicas | 52 | 50 | 0 | 1 |

El conteo incluye 103 entradas; la fila `OBSOLETE` es el reconciliador de roles, invocable solo por owner y usado durante la migración. Las 103 fijan el `search_path` exacto `pg_catalog, public, auth, storage, pg_temp`. Ninguna conserva `EXECUTE` directo para `PUBLIC`. Las seis funciones con ejecución efectiva por `anon` son endpoints/helpers intencionales y revisados: gate `is_admin` que falla cerrado, canales públicos, analytics con eventos whitelisted sobre negocio publicado, pre-request de sesión y dos predicados de gestión que dependen de identidad/ámbito.

Hallazgo corregido: `context_chat_participants(text, uuid)` podía devolver IDs de participantes para un contexto arbitrario; `request_is_visible_to_business(uuid, uuid)` era un oráculo directo de visibilidad. Ambas se usan desde funciones SECURITY DEFINER de nivel superior, así que `20261007210000` revoca `PUBLIC`, `anon` y `authenticated` sin cambiar los cuerpos ni quitar `service_role`. La migración comprueba la postcondición efectiva y la conservación del permiso backend. Las tres helpers internas previas (`notify_business_managers`, `record_business_review_event`, `sync_context_conversation_members`) también quedan inaccesibles a roles API.

Las 24 funciones `admin_*` del estado final comprueban el gate global. `current_user_is_admin()` exige `is_super_admin()` y una sesión vigente explícita en `super_admin_sessions`; el tenant admin no cruza el gate. `admin_change_user_role` no admite `super_admin`, protege los objetivos SuperAdmin y serializa la protección del último admin. El único SQL dinámico con acceso a datos está en `admin_mark_user_deleted`: identificadores provienen del catálogo y se interpolan con `%I`; el ID se pasa enlazado (`$1`). No se detectó dynamic SQL basado en input sin parametrizar.

Se siguieron las cadenas UI/Edge/RPC/helper/tablas de roles, settings globales, revisión de provider, Contacto y notificaciones. Las RPC administrativas mantienen `EXECUTE` de `authenticated` para el JWT de consola, pero exigen gate SuperAdmin+sesión; anon y PUBLIC quedan fuera. El test de integración ejecutado con el rol real `authenticated` y el tenant admin del snapshot rechazó `current_user_is_admin()` y `admin_analytics_summary()`. El test de matriz con customer, provider y owner confirmó gate global cerrado y ownership limitado al negocio correspondiente. Bootstrap y acceso con sesión explícita pasaron contratos aislados con rollback.

Inventario remoto read-only: la auditoría anterior contiene 82 funciones SECURITY DEFINER en los esquemas remotos examinados, 79 públicas; los cuerpos de funciones de aplicación coinciden con el snapshot salvo las cuatro funciones de extensión ya descritas. El remoto todavía no tiene aplicado el bloque de migraciones funcionales: mantiene el gate histórico tenant-admin, los grants `authenticated` de las RPC globales y los grants de los helpers que cierran las migraciones pendientes. Es drift de apply, no una regresión del estado local final.

## 5. Métricas de seguridad

En la réplica final:

- TRUNCATE efectivo en tablas públicas: `anon=0`, `authenticated=0`.
- RPC administrativas ejecutables por `anon`: `0`.
- Helpers internos ejecutables por `PUBLIC`, `anon` o `authenticated`: `0`.
- `current_user_is_admin()` para tenant admin: `false`; sin sesión global: `false`.
- Negocios con owner huérfano: `0`.
- Las RPC globales conservan `EXECUTE` authenticated, pero todas pasan por el gate endurecido.

Recheck read-only de producción al cierre: hotfix existente sigue en `TRUNCATE anon=0`, `TRUNCATE authenticated=0`, `admin RPC anon=0`. No se aplicó otra escritura remota.

## 6. Validaciones y límites

- Replay aislado: las 28 migraciones exactas pasaron en dos restauraciones limpias; corrección `072100` y re-run idempotente pasaron.
- SQL: **10/10** contratos pasaron: bootstrap, hotfix, helpers, gate, contacto, search_path, matriz de roles, Home, backfill reversible y contrato semántico final.
- `dart format .`: PASS, 203 archivos examinados, 0 cambios de formato.
- `flutter analyze`: PASS.
- `flutter test --reporter compact`: **630/630 PASS**.
- `scripts/check_text_encoding.ps1`: PASS.
- `git diff --check`: PASS; Git solo emitió avisos existentes de normalización LF/CRLF.
- `flutter build web --release`: PASS.
- Deno: **7/7 PASS**. `deno check`: PASS en `submit-contact`, `admin-user` y `notify-provider-review`.
- Docker no estuvo disponible. No se considera bloqueo: el snapshot real se restauró en PostgreSQL 16 aislado. Las diferencias de versión/extension runtime quedan explícitas arriba.
- No hubo browser/HTTP Edge local durante este replay. El objetivo de esta fase —fidelidad de snapshot y semántica SECURITY DEFINER— sí quedó cubierto con catálogos PostgreSQL, tests por rol real y contratos Deno/SQL.
- Las bases locales `ranco330_snapshot_replay` y `ranco330_replay_clean` se eliminaron después de las pruebas. La política rechazó la eliminación recursiva de los exports descifrados antes de ejecutarla. Las carpetas que aún requieren limpieza manual son `%TEMP%\ranco-330-production-snapshot`, `%TEMP%\ranco-330-pg16-restore`, `%TEMP%\ranco-330-schema-load` y `%TEMP%\ranco-330-snapshot`; están fuera del repo con ACL privada. El backup cifrado original en `%LOCALAPPDATA%\RancoConecta\production-backups` debe conservarse.

## 7. Migraciones y estado de producción

El repo queda con **61 migraciones**. Producción tenía **32 registradas** al inicio de esta fase; el hotfix `071600` ya estaba registrado/aplicado. Quedan **29 archivos pendientes**: las 28 enumeradas arriba más `20261007210000_revoke_api_internal_scope_helpers.sql`. El runbook actualizado describe el orden completo. No se marcó ninguna versión como aplicada en producción.

## 8. Decisiones humanas y pasos de producción

No son defectos técnicos:

1. Elegir `INITIAL_SUPER_ADMIN_USER_ID`.
2. Elegir categoría para cada uno de los tres negocios `MANUAL_REVIEW_REQUIRED`.
3. Configurar `ADMIN_NOTIFICATION_WEBHOOK_SECRET` (requerido por `notify-provider-review`).
4. Aprobar expresamente el apply y tomar/verificar backup operacional inmediatamente antes.

El orden y los asserts por bloque están en [phase-3-28-production-apply-runbook.md](phase-3-28-production-apply-runbook.md). No ejecutar `db push` general.
