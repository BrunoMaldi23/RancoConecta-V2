# Fase 3.28 — readiness técnico final

Fecha: 2026-10-07. Este es el source of truth posterior a Fase 3.27. Producción **solo se inspeccionó con lecturas** durante esta fase; no se aplicaron migraciones, cambios de roles/datos, despliegues ni cambios de configuración. El hotfix `20261007160000` se aplicó antes de esta fase y permanece en 0/0/0 según el reporte 3.26.2A.

## Resumen ejecutivo

El repo tiene 58 migraciones, incluyendo una migración nueva de autorización global. La cola anterior era 25 pendiente: 24 migraciones funcionales y la revocación de helpers internos. Ahora hay 26 pendientes: esas 25 más `20261007180000_finalize_platform_admin_gate.sql`. El remoto conserva 32 versiones registradas. No se alteró migration history remoto.

El cierre local esperado usa `05006000` para separar SuperAdmin de admin tenant mediante `is_super_admin()` + `super_admin_sessions`; la nueva migración `07180000` reinstala ese contrato al final de la cola, elimina EXECUTE anónimo/PUBLIC de RPC globales, repite el cierre de los tres helpers y falla si faltan tablas/helpers o hay SECURITY DEFINER sin `search_path`. El EXECUTE de las RPC globales para `authenticated` se conserva deliberadamente: el frontend llama con JWT de usuario; la autorización efectiva reside en los cuerpos que validan el gate de sesión. Revocarlo rompería la consola incluso para SuperAdmin. Requiere revisión de esos cuerpos y pruebas role-aware antes de apply.

**No es técnicamente seguro declarar listo el apply**: Docker daemon no disponible; no se pudo repetir reset local ni simular las 26 migraciones pendientes sobre un snapshot remoto equivalente. El runbook queda preparado, pero esta simulación es condición previa técnica, no decisión humana.

## Estado inicial / límites

- Los tres informes requeridos de Fase 3.27/3.26.2A fueron leídos. Los detalles históricos y outputs originales se preservan allí.
- `git status` mostraba decenas de modificaciones preexistentes y archivos nuevos de fases previas; no hay evidencia fiable para atribuirlos a Claude/Codex. No se revirtió nada.
- Docker CLI está presente, daemon `dockerDesktopLinuxEngine` ausente.
- El clúster PostgreSQL temporal de pruebas consta como detenido en `%TEMP%\ranco-3262a-grants-model`, fuera del repo. No se eliminó; limpieza manual opcional: detener/verificar estado y borrar esa carpeta exacta si ya no se necesita.
- `.playwright-cli/` contiene capturas/YAML de smoke previo y no se debe versionar; ahora queda ignorado por `.gitignore`. No se borraron artefactos útiles.
- Ningún valor de secreto, PII o connection string se incluyó aquí.

## Validaciones

| Validación | Resultado |
|---|---|
| `dart format .` | PASS, 203 archivos, 0 cambios |
| `flutter analyze` | PASS, sin issues |
| `flutter test --reporter compact` | PASS, 630/630 |
| `scripts/check_text_encoding.ps1` | PASS |
| `git diff --check` | PASS; avisos informativos LF→CRLF en archivos existentes |
| `flutter build web --release` | PASS, `build/web` generado |
| `npx --yes deno test supabase/functions` | PASS, 4/4 |
| `npx --yes deno check` (3 funciones) | PASS |
| SQL contracts | Hotfix grants/helper pasó modelo PG aislado previo; el nuevo gate aún requiere modelo/reset completo |
| Simulación completa 26 migraciones | NO EJECUTADA: Docker daemon no disponible y no hay snapshot equivalente adjunto/verificable en el repo |
| SQL suites de integración / RLS / bootstrap | 11 archivos SQL contract; no repetibles completas sin DB de Supabase local |

## Seguridad y roles

### Consumidores de `current_user_is_admin()`

Todos los usos de autorización `current_user_is_admin()`/`is_admin()` en migraciones y policies corresponden a **GLOBAL PLATFORM ADMIN**: review queue/mutations, analytics, usuarios/roles, audit read, Contacto/configuración y branches de policies o lógica global de requests/chat/admin. Usos que incluyen `is_business_owner`, `is_business_admin` o `user_can_manage_business` son alcance de negocio separado; el branch SuperAdmin no debe convertirse en requisito para owner/manager. El alias `is_admin()` queda evaluable por anon para policies, pero devuelve false sin JWT de SuperAdmin y sesión activa.

| Uso | Remoto auditado previamente | Local final esperado | Riesgo |
|---|---|---|---|
| Consola global / admin_* | Acepta perfil `admin`; no requiere sesión global | SuperAdmin activo + sesión explícita vigente | CRÍTICO en remoto hasta migración y prueba |
| Moderación/usuarios/settings/audit | tenant admin puede satisfacer helper remoto | gate global hardened | CRÍTICO en remoto |
| Owner/manager de negocio | helperes de negocio | ownership/membership scoped; no global | No elevar a platform admin |
| `is_admin()` en policies | alias heredado del helper remoto | alias del gate final, `anon` puede evaluarlo como false | Probar grants/RLS por rol |
| Funciones transversales requests/chat | branches helper global junto a ownership | global branch exige sesión, branch tenant/owner sigue su ámbito | Revisar casos role matrix en QA |

Las 12 RPC de Fase 3.26.2A son platform-global: `admin_analytics_summary()`, `admin_business_review_detail(uuid)`, `admin_business_review_queue(text,text,text,integer,integer)`, `admin_business_review_stats()`, `admin_get_business_review(uuid)`, `admin_list_users(integer,integer)`, `admin_publish_business(uuid)`, `admin_reject_business(uuid,text,boolean)`, `admin_request_business_changes(uuid,text)`, `admin_restore_business(uuid)`, `admin_suspend_business(uuid,text)`, `admin_update_whatsapp_settings(text,boolean,boolean,boolean,boolean)`. Las dos RPC agregadas después (`admin_mark_user_deleted`, `admin_set_contact_message_status`) también son globales. No hay RPC global que deba ser callable por tenant admin. EXECUTE para `authenticated` queda sujeto a body-check global, pues la consola requiere invocarlas con la sesión autenticada.

Los tres helpers internos exactos son `notify_business_managers(uuid,text,text,text)`, `record_business_review_event(uuid,text,uuid,text,text,text,jsonb)` y `sync_context_conversation_members(uuid)`. `07170000` y la nueva `07180000` los retiran de PUBLIC/anon/authenticated, preservando service_role solo si ya lo tenía. Otros SECURITY DEFINER se cubren parcialmente por `05006000`; el reporte previo enumeraba 79, 0 sin `search_path`, pero el análisis de cuerpos/grants de las 54 anon-executable no está cerrado por completo. El nuevo contrato también detecta funciones públicas sin search_path, no prueba automáticamente cada body ni SQL injection.

### Bootstrap

`scripts/bootstrap-first-super-admin.sql` exige parámetro psql `bootstrap_user_id`, owner de base, lock asesorado, y core con guard de cero SuperAdmin/auditoría. El ID queda intencionalmente sin valor. El test histórico `phase_3_25_8_bootstrap.sql` cubrió 0→1, idempotencia, no autopromoción admin/provider/customer y protección del último SuperAdmin; no se repitió ahora sin Docker. No se eligió usuario real.

### Matriz resumida de autorización final

| Rol | Global platform admin | Ámbito de negocio | Contacto directo | Notificaciones |
|---|---|---|---|---|
| ANON | No | Lectura pública | Solo Edge validada | No |
| CUSTOMER | No | Propio | No | Propias |
| PROVIDER | No | Asignado/propio según business membership | No | Propias/ámbito autorizado |
| OWNER | No | Negocio propio | No | Propias/ámbito autorizado |
| TENANT ADMIN | No | Solo membresía/tenant que el backend permita | No | Tenant si política implementada |
| SUPER ADMIN | Solo sesión explícita vigente | Según operación autorizada | No vía tabla directa | Global según diseño |

La suite SQL role-aware no se pudo repetir en esta fase; este cuadro describe contrato esperado, no una ejecución observada ahora.

## Migraciones y orden

Antes: 57 locales, 32 remotas, 25 pendientes. Después de añadir `07180000`: **58 locales**, 32 registradas remotas, **26 pendientes**. Lista exacta local pendiente, en timestamp:

1. `20261004120000_provider_identity_and_draft_reuse.sql` — FUNCTIONALITY / transformación de funciones y trigger Auth; revisar definiciones remotas.
2. `20261004121000_admin_user_role_management.sql` — SECURITY / FUNCTIONALITY; role RPC y guard.
3. `20261004122000_notification_recipients_and_activity.sql` — FUNCTIONALITY / DATA; helpers, recipients, triggers.
4. `20261004123000_category_audit.sql` — DATA / auditoría.
5. `20261004124000_review_requirements_by_type.sql` — FUNCTIONALITY; reemplazo de función, revisar schema remoto.
6. `20261004125000_admin_audit_read.sql` — SECURITY / FUNCTIONALITY; policy global.
7. `20261004130000_suspended_session_gate.sql` — SECURITY; **REPLACE**, no aplicar tal cual (gate transversal `db_pre_request`/policies/storage).
8. `20261004131000_admin_account_suspension.sql` — SECURITY / FUNCTIONALITY.
9. `20261004132000_pre_request_execute_roles.sql` — SECURITY; revisar duplicidad con 050030.
10. `20261004132500_capture_provider_role_candidates.sql` — DATA; staging de candidatos.
11. `20261004133000_provider_role_separation.sql` — TRANSFORMATION / DATA; mantener 3 perfiles ambiguos sin reclasificar automáticamente.
12. `20261004134000_admin_mutation_capability.sql` — SECURITY / FUNCTIONALITY; tenant scope separado.
13. `20261004135000_restrict_notification_helper.sql` — SECURITY.
14. `20261004140000_role_business_transition_guard.sql` — SECURITY; **REPLACE**, trigger actual necesita reconciliación.
15. `20261004141000_admin_settings_audit_and_user_status.sql` — SECURITY / FUNCTIONALITY / DATA.
16. `20261005000000_contact_messages.sql` — FUNCTIONALITY / DATA; tabla/RLS, dependencia Edge.
17. `20261005001000_admin_user_deletion.sql` — SECURITY / DATA; soft delete.
18. `20261005002000_contact_and_notification_settings.sql` — FUNCTIONALITY / DATA; requiere tabla/contact y recipients.
19. `20261005003000_pre_request_service_role.sql` — SECURITY; revisar duplicidad con 041320.
20. `20261005004000_revoke_anon_admin_rpc.sql` — SECURITY; grants admin anon/PUBLIC.
21. `20261005005000_reconcile_business_home_fields.sql` — FUNCTIONALITY / schema contract Home; guardada/idempotente según baseline anterior.
22. `20261005006000_security_roles_grants_owner.sql` — SECURITY / TRANSFORMATION; tabla de sesión, gate, grants, FK owner restrict, reconciliation; secuencia crítica.
23. `20261005007000_allow_soft_deleted_profiles.sql` — FUNCTIONALITY / schema.
24. `20261005008000_install_profile_privilege_guard.sql` — SECURITY.
25. `20261007170000_revoke_internal_definer_helpers.sql` — SECURITY; revoca 3 helpers internos.
26. `20261007180000_finalize_platform_admin_gate.sql` — SECURITY; gate/authz assertions finales.

No se probó duplicación de objetos en la cola completa ni equivalencia del remoto. Según el plan previo, los tipos/columnas/policies remotos tienen drift histórico, hay que reconciliar/reemplazar antes de aplicar; aplicar 58 por timestamp no basta. No alterar migraciones históricas. El hotfix 071600 es excepción remota ya registrada fuera del flujo funcional.

## Owner/FK

Esperado local: `businesses.owner_id → profiles(id) ON DELETE RESTRICT`, con preflight de cero huérfanos, no cascade destructivo; soft delete mantiene perfil/Auth y negocio/historial. Remoto reportado: referencia `auth.users(id) ON DELETE CASCADE`, 0 huérfanos al muestreo. Es drift material que requiere respaldo y simulación; no corregido remotamente.

## Categorías y Home

Seis negocios publicados observados con `primary_category_id=NULL`. Tres inferencias objetivas, todas categorías activas y todos los servicios activos del negocio en una sola categoría:

| BUSINESS_ID | CATEGORY_ID | SOURCE | STATUS |
|---|---|---|---|
| `33595129-2e00-4abb-bb72-61c5f5b9f990` | `2b0fff8e-10fd-488f-9471-31a8ab447467` | business_services → subcategories.category_id | HIGH |
| `b163593b-ce67-458f-92c8-faeb6b4d74b5` | `9a583338-a707-4d47-9985-557b7b189aa1` | business_services → subcategories.category_id | HIGH |
| `e325ad8f-7720-4517-abff-1ec0050676f6` | `6521897c-a7c7-46ff-95f4-587cb252c0ce` | business_services → subcategories.category_id | HIGH |

`docs/sql/category-backfill-reviewed.sql` conserva guarda transaccional/ROLLBACK; no se ejecuta. El diagnóstico de causa no encontró flujo actual capaz de publicar sin categoría: UI y requisitos de revisión exigen categoría y RPC de servicios la completa desde la única categoría. La causa probable es histórica/out-of-band, no demostrable. `primary_category_id` debe seguir nullable para drafts. No forzar NOT NULL.

Tres casos sin evidencia de servicios/categoría y sin metadata:

| BUSINESS_ID | MOTIVO | CANDIDATAS | STATUS |
|---|---|---|---|
| `487a5eee-cb79-4cb3-8a5c-c5e3ad706677` | Alojamiento sin evidencia de categoría | No objetivas | MANUAL_REVIEW_REQUIRED |
| `a23c6ce8-a186-4e1a-8b09-3100cc142bc7` | Gastronomía sin evidencia de categoría | No objetivas | MANUAL_REVIEW_REQUIRED |
| `bec6390b-5782-422f-9654-82687553b84e` | Alojamiento sin evidencia de categoría | No objetivas | MANUAL_REVIEW_REQUIRED |

No se editaron los seis negocios reales. Home ya consulta destacados, `is_featured`, `accepts_requests`, `rating_avg`, `review_count`, imágenes y categoría; no se agregan fallbacks artificiales. Smoke real previo de Home/Explore/detalle fue 200, sin 42703 observado.

## Contacto, Admin y Edge

`contact_messages` usa `name/email/subject/message`, status `new/in_review/resolved`, `user_id nullable → profiles ON DELETE SET NULL`, índice status/created_at, RLS y select solo con gate global; no concede insert directo API. El trigger guarda notificación para SuperAdmin en el modelo hardened. Edge `submit-contact` valida whitelist/payload, email, motivo, longitudes y límite de cuerpo 10KB; permite anónimo/autenticado y asocia usuario solo tras validar token. CORS es exacto, no wildcard. No hay protección durable contra burst/reintentos duplicados más allá del estado/loading cliente; esto queda como bloqueo técnico para deploy público hasta definir/pruebar rate/idempotency. La función devuelve errores genéricos.

`admin-user` exige bearer JWT y revalida con Auth; llama `current_user_is_admin` y usa service role solo dentro Edge. CRUD vía ramas invite/delete; no expone service role frontend. Mutaciones dependen de migraciones/RPC; global gate final restringe tenant admins. Se revisaron validaciones básicas y auditoría. `notify-provider-review` procesa webhook internal y requiere `ADMIN_NOTIFICATION_WEBHOOK_SECRET`; ahora solo selecciona perfiles `super_admin` activos (corrección local de recipients). Su secret es REQUIRED, producción MISSING; SUPABASE_URL/service role son runtime-managed. La función no se debe desplegar/activar hasta tener secret configurado y corregir esquema/trigger de destino.

| SECRET | FUNCTION | REQUIRED | PROD STATUS |
|---|---|---:|---|
| `ADMIN_NOTIFICATION_WEBHOOK_SECRET` | `notify-provider-review` | REQUIRED | MISSING |
| `SUPABASE_URL` | 3 functions | REQUIRED | RUNTIME_MANAGED |
| `SUPABASE_SERVICE_ROLE_KEY` | 3 functions | REQUIRED | RUNTIME_MANAGED |
| `SUPABASE_ANON_KEY` | `admin-user` | REQUIRED | RUNTIME_MANAGED |

Edge order: migrations/RLS/RPC → secret config → deploy submit-contact → HTTP checks → deploy admin-user → authz checks → secret webhook + webhook trigger setup → deploy notify-provider-review → signed/invalid health checks. Ninguna Edge fue desplegada.

## UI y flujos existentes

- Admin UI: global access se basa en `ProfileRole.superAdmin`; inicia sesión global por RPC al entrar a consola. Tenant admin no recibe consola global. Confirmación de bloqueo solo con Flutter/tests existentes; backend nuevo requiere QA.
- Configuración: global settings bajo el gate SuperAdmin; WhatsApp sigue manual; integraciones no fingen disponibilidad. Las tablas/keys nuevos siguen migración pendiente.
- Notificaciones: servicio filtra `user_id`, read-state/contador; nuevas preferencias/recipient policies dependen migraciones pendientes.
- Provider/Owner: profile role provider y business membership son distintos; helpers owner/manager tienen alcance de negocio y no confieren acceso global.
- Legales/Auth: validación Flutter previa pasa; no se alteró auth real ni se modificó texto legal.
- Navegador visual: smoke anterior real de producción (lecturas públicas) quedó documentado en 3.27; esta fase no repitió un navegador por no ser condición para SQL/migración. No reportar ese smoke como ejecutado ahora.

## Matriz final

| FUNCIÓN | CÓDIGO | TESTS | LOCAL | PRODUCCIÓN | ACCIÓN |
|---|---|---|---|---|---|
| Home | READY | READY baseline | NOT TESTED con Supabase local actual | WORKING, smoke previo | Mantener contrato; categoria backfill antes de activar filtro real |
| Explore/detalle/legales/Auth UI | READY | READY baseline | WORKING por Flutter | WORKING visual read-only previo | Smoke tras backend apply |
| SuperAdmin gate | READY local | contrato agregado | NOT TESTED completo | SECURITY BLOCKED | Simular migraciones y aplicar tras aprobación |
| Admin RPC | READY con gate | 12 existentes + contrato agregado | NOT TESTED end-to-end | SECURITY BLOCKED | Mantener authenticated execute con body gate y cerrar QA |
| Tres helpers internos | READY local | SQL contract | modelo previo | SECURITY BLOCKED | Migración posterior a roles |
| Owner FK | READY en migración | tests previos reportados | NOT TESTED actual | PENDING MIGRATION | snapshot/huérfanos/restore y validación |
| Categoría principal | READY, nullable para draft | preview/backfill SQL | 3 candidatos aislados | PENDING DATA FIX | backfill 3 solo con transacción; 3 decisión manual |
| Contacto | WORKING local | Deno validación | HTTP local no repetido | PENDING MIGRATION | agregar rate/idempotency antes de público |
| Admin user | READY local | Deno/typecheck baseline | HTTP no repetido | PENDING MIGRATION / EDGE DEPLOY | QA con usuarios sintéticos |
| Notify provider review | READY local | Deno/typecheck a repetir | HTTP no repetido | PENDING EDGE DEPLOY | secret REQUIRED y recipients SuperAdmin |
| Docker/Supabase reset | NOT TESTED | 10 SQL suites existentes | BLOCKED | N/A | Activar daemon y ejecutar reset/simulación |

## Pendientes y decisiones humanas

### Bloqueos técnicos

1. Simulación completa de las 26 migraciones contra un baseline remoto equivalente y reset Supabase limpio no se ejecutaron por Docker ausente/snapshot no disponible en el repo. La historia remota tiene drift (roles/type text y FK ownership); no se debe ejecutar en lote.
2. Auditar en snapshot los cuerpos/grants de todos los SECURITY DEFINER; que 0 carezcan de `search_path` no demuestra que todos tengan checks de auth/tenant correctos. 54 funciones anon-executable históricas requieren clasificación de allowlist/callers.
3. `submit-contact` no implementa rate limiting durable ni idempotency key. Se requiere control probado contra burst/retry antes de habilitar endpoint público.
4. El gate final, trigger/replacements de 041300/041400, grants de `authenticated`, FK owner y role candidate reconciliation deben probarse en QA con datos sintéticos equivalentes antes del apply.

### Decisiones humanas necesarias (máximo real)

A. Identidad/User ID del primer SuperAdmin.
B. Categoría confirmada para cada uno de los tres negocios `MANUAL_REVIEW_REQUIRED`.
C. Valor nuevo para `ADMIN_NOTIFICATION_WEBHOOK_SECRET` si se decide desplegar esa función.

## Archivos principales de esta fase

- `supabase/migrations/20261007180000_finalize_platform_admin_gate.sql` — gate final y grant assertions.
- `supabase/tests/phase_3_28_platform_admin_gate.sql` — contrato de postcondiciones.
- `supabase/functions/notify-provider-review/index.ts` — destinatarios de revisión global limitados a SuperAdmin activo.
- `.gitignore` — ignora artefactos de Playwright y dumps/backups comunes.
- `docs/phase-3-28-production-apply-runbook.md` — pasos, abort conditions y recuperación.

## Resultado

El hotfix anterior permanece aplicado con TRUNCATE anon/authenticated 0 y RPC admin anon 0. Sin embargo, sigue habiendo bloqueos técnicos de simulación, auditoría completa de SECURITY DEFINER y anti-duplicados/contact rate protection. Los datos/roles remotos no fueron modificados.

**READY FOR PRODUCTION APPLY: NO**
