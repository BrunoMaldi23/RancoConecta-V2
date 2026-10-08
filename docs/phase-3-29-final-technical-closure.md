# Fase 3.29 — cierre técnico final

Fecha: 2026-10-07. Proyecto objetivo: RancoConecta (`exdaagbftotnnoyetcpg`). Este informe es el estado técnico vigente. **No hubo escrituras ni despliegues remotos durante esta fase.**

## Resultado

**READY FOR PRODUCTION APPLY: NO**

Hay trabajo local listo y probado, pero persiste un bloqueo técnico: la secuencia pendiente no se pudo validar contra un snapshot fiel del schema remoto. Docker no fue el bloqueo: PostgreSQL 16 aislado estuvo disponible y recibió las migraciones. La exportación remota dependía de la imagen Docker de `pg_dump` y no pudo producir un snapshot. El modelo usado para la simulación no reproduce todos los tipos, policies, triggers y grants remotos. Además, el inventario de funciones remotas requiere revisión semántica de los cuerpos señalados como riesgosos antes de afirmar que toda la superficie SECURITY DEFINER está cerrada.

## Estado inicial y remoto (solo lectura)

- Repositorio: **60 migraciones locales**; remoto: **32 versiones registradas**; 28 archivos locales pendientes de aplicar. La diferencia de 28 incluye cuatro migraciones nuevas posteriores al dato histórico de 26: `071700`, `071800`, `071900` y `072000`; `071600` ya estaba registrada. No se marcaron migraciones artificialmente.
- Tablas `public`: 42. Hotfix ya aplicado, confirmado de nuevo por catálogo: TRUNCATE efectivo `anon=0`, `authenticated=0`, admin RPC objetivo ejecutable por anon `=0`.
- Aún remoto: 12 RPC globales ejecutables por `authenticated`; 3 helpers internos SECURITY DEFINER ejecutables por anon; `current_user_is_admin()` todavía trata tenant admin como admin global. El bloque local `071800` cambia el gate, pero aún no está aplicado en producción.
- `contact_messages` y `super_admin_sessions` todavía no existen en remoto. Edge Functions desplegadas: 0. Secrets personalizados en el inventario remoto: ninguno listado. `ADMIN_NOTIFICATION_WEBHOOK_SECRET` es **REQUIRED** por `notify-provider-review` y falta en producción.
- La matriz completa de metadata SECURITY DEFINER remota está en [phase-3-29-security-definer-inventory.csv](phase-3-29-security-definer-inventory.csv); consulta reproducible de solo lectura: [audit-security-definer-readonly.sql](../scripts/audit-security-definer-readonly.sql). Incluye 82 funciones en los esquemas inspeccionados, 79 en `public`; todas las 79 tienen `search_path` explícito, pero no el path final fijado, por lo que se clasifican conservadoramente como NEEDS HARDENING. `072000` fija el path seguro en la secuencia local. La clasificación del CSV usa marcadores estáticos de cuerpo; no reemplaza revisión humana de lógica compleja/dinámica.

## Cambios locales de esta fase

- `20261007190000_contact_abuse_controls.sql`: limita contacto de forma durable y serializada en DB. Guarda hashes SHA-256, no IP/correo en claro en las tablas de control; 10 por IP/hora, 3 por usuario autenticado/hora, 3 por correo normalizado/hora; fingerprint duplica por 10 minutos; idempotency UUID persistente; respuesta 429 y `Retry-After`. Limpieza oportunista limitada a 500 filas expiradas por llamada. Tabla de control con RLS y sin grants directos a roles API/service; único RPC SECURITY DEFINER callable por service_role. La Edge Function valida cuerpo acotado a 10 KB y datos antes del RPC.
- `20261007200000_harden_public_definer_search_path.sql`: fija explícitamente el path de todas las funciones SECURITY DEFINER de `public` a `pg_catalog, public, auth, storage, pg_temp`, después de comprobar que roles de aplicación no pueden crear objetos en esos esquemas. `pg_temp` queda al final.
- Contrato `phase_3_29_authorization_matrix.sql`: tenant admin no cruza el gate global, owner no escapa del negocio propio, provider/customer no son admin y SuperAdmin requiere sesión global explícita, revocable y auditable.
- Contratos `phase_3_29_contact_controls.sql` y `phase_3_29_security_definer_search_path.sql`; tests Deno para idempotencia, hashes, códigos HTTP y CORS.
- Home contract: query de cuatro campos y categoría/imágenes compila y ejecuta en PostgreSQL aislado sin 42703. El fixture sintético contiene drafts sin media; no constituye smoke de datos publicados reales.

## Simulación de migraciones y límites

Se ejecutaron, en timestamp ascendente y con transacción independiente por migración, las 28 migraciones pendientes sobre PostgreSQL 16 aislado. El baseline fue reconstruido de migraciones locales históricas con diferencias remotas conocidas simuladas (FK de owner y campos Home). Se usaron filas sintéticas. La primera ejecución sin transacciones por archivo falló por configuración local de `set_config`; la repetición con límites transaccionales por archivo pasó. No se consideró fallo de la secuencia.

Conteos sintéticos antes → después: profiles `6→6`; businesses `4→4`; owners huérfanos `0→0`; requests `0→0`; lodging/table reservations `0→0`; notifications `0→0`; settings `5→10` (defaults esperados); contact `0→0`; audit `0→3` (auditoría esperada de role reconciliation). Tres perfiles ambiguos permanecieron customer/AMBIGUO. FK owner apunta a `profiles(id) ON DELETE RESTRICT` y queda validada.

**Limitación bloqueante:** el modelo no reproduce por completo el remoto: enums/checks como texto, políticas y grants exactos, triggers y estados de datos. El intento de completar la equivalencia no fue exitoso. No hay dump cifrado restaurado disponible en esta sesión. Por ello, el resultado prueba el orden SQL sobre el modelo local enriquecido, pero no permite declarar la simulación remota-equivalente requerida.

### Las 28 migraciones pendientes

| Timestamp / nombre | Propósito | Riesgo / dependencia | Post-assert mínimo |
|---|---|---|---|
| `20261004120000_provider_identity_and_draft_reuse` | identidad provider y reuso de draft | SECURITY / profiles, businesses | candidates y draft ownership íntegros |
| `20261004121000_admin_user_role_management` | operaciones de rol admin | SECURITY / identidad y audit | solo rol permitido; audit presente |
| `20261004122000_notification_recipients_and_activity` | destinatarios y actividad | FUNCTIONALITY / profiles | recipient scope y counts conservados |
| `20261004123000_category_audit` | auditoría de categorías | DATA / categories | cero cambios de categorías sin audit |
| `20261004124000_review_requirements_by_type` | requisitos por tipo | FUNCTIONALITY / onboarding | categoría requerida al publicar; draft libre |
| `20261004125000_admin_audit_read` | lectura de auditoría admin | SECURITY / gate | no anon; gate global |
| `20261004130000_suspended_session_gate` | gate de cuenta suspendida | SECURITY / auth y profiles | sesión suspendida bloqueada |
| `20261004131000_admin_account_suspension` | suspensión/reanudación | SECURITY / audit | estados y auditoría coherentes |
| `20261004132000_pre_request_execute_roles` | grants previos a request | SECURITY / RPC | grants mínimos preservados |
| `20261004132500_capture_provider_role_candidates` | candidatos de separación | DATA / profiles | candidatos agregados, sin PII |
| `20261004133000_provider_role_separation` | convertir provider identity | TRANSFORMATION / candidates | ambiguos permanecen customer |
| `20261004134000_admin_mutation_capability` | capacidades de mutación admin | SECURITY / gate | tenant/global scope comprobado |
| `20261004135000_restrict_notification_helper` | cerrar helper interno | SECURITY / 041220 | anon/PUBLIC no ejecutan helper |
| `20261004140000_role_business_transition_guard` | bloquear transiciones ilegítimas | SECURITY / roles, ownership | no self-promotion; owners íntegros |
| `20261004141000_admin_settings_audit_and_user_status` | settings y estado de usuario | FUNCTIONALITY/SECURITY / audit | defaults y audit conservados |
| `20261005000000_contact_messages` | tabla Contacto | FUNCTIONALITY / RLS | insert únicamente vía Edge/RPC |
| `20261005001000_admin_user_deletion` | soft delete admin | SECURITY / role management | Auth e historial conservados |
| `20261005002000_contact_and_notification_settings` | settings y notificaciones | FUNCTIONALITY / tablas previas | defaults/canales y scope correctos |
| `20261005003000_pre_request_service_role` | grants de servicio | SECURITY / RPC | backend conserva solo grants necesarios |
| `20261005004000_revoke_anon_admin_rpc` | revocar anon RPC | SECURITY / RPC existentes | anon=0 |
| `20261005005000_reconcile_business_home_fields` | contrato Home | TRANSFORMATION / businesses | columnas, defaults, índices y filas preservados |
| `20261005006000_security_roles_grants_owner` | roles, RLS y FK owner | SECURITY/TRANSFORMATION / profiles | FK RESTRICT, cero huérfanos, matriz de permisos |
| `20261005007000_allow_soft_deleted_profiles` | conservar referencias soft-delete | FUNCTIONALITY / owner FK | relaciones históricas válidas |
| `20261005008000_install_profile_privilege_guard` | guard de perfiles | SECURITY / role grants | auto-promoción imposible |
| `20261007170000_revoke_internal_definer_helpers` | cerrar 3 helpers | SECURITY / funciones remotas existentes | anon/PUBLIC/auth no ejecutan helpers |
| `20261007180000_finalize_platform_admin_gate` | gate global explícito | SECURITY / `050060` y sesiones | tenant=false; super admin requiere sesión |
| `20261007190000_contact_abuse_controls` | rate/idempotency durable | FUNCTIONALITY/SECURITY / `050000` | dedup, límites, RLS y 429 |
| `20261007200000_harden_public_definer_search_path` | path final seguro | SECURITY / esquemas y funciones previas | todas las public definer con path exacto |

Riesgo listado es clasificación operativa; el orden es el timestamp real. En producción no se debe aplicar hasta una simulación equivalente completa. Particularmente, `041300`/`041400` requieren comparar sus policies/gates contra el schema remoto antes de apply.

## Roles y datos

- Modelo final: ANON público; CUSTOMER propio; PROVIDER ámbito provider; OWNER negocio propio; TENANT ADMIN administración de su ámbito; SUPER ADMIN plataforma global solo con sesión explícita y vigente.
- `current_user_is_admin()` local final requiere `is_super_admin()` y fila de `super_admin_sessions` activa/no vencida. La función legacy `is_admin()` delega al gate. RPC `admin_*` globales mantienen EXECUTE autenticado solo porque su body valida gate; no son autorización UI. `071800` revoca anon/PUBLIC de RPC globales y cierra tres helpers.
- Bootstrap está probado en DB aislada: 0→1, audit, segunda ejecución bloqueada, no auto-promoción tenant/provider/customer, y protección último SuperAdmin. No hay ID elegido: `INITIAL_SUPER_ADMIN_USER_ID = HUMAN_DECISION_REQUIRED`.
- Ownership: FK `businesses.owner_id → profiles(id) ON DELETE RESTRICT`; soft delete no borra negocio. No se probaron borrados reales remotos.
- Tres perfiles customer ambiguos preservados como customer en simulación. No se reclasificaron.

## Categorías y Home

Producción conserva 6 negocios publicados sin categoría principal. El backfill transaccional preparado está en [category-backfill-reviewed.sql](sql/category-backfill-reviewed.sql), con tres filas exactas, categoría objetiva proveniente de `business_services → subcategories → categories`, guards de estado/categoría/evidencia única y `ROLLBACK` final intencional. No se ejecutó. Los otros tres IDs están en `phase-3-27-category-data-assessment.md` con `MANUAL_REVIEW_REQUIRED`; no hay categorías candidatas con evidencia de servicios. Las tres categorías requieren decisión humana.

| business_id | categoría candidata con evidencia | estado |
|---|---|---|
| `487a5eee-cb79-4cb3-8a5c-c5e3ad706677` | ninguna | MANUAL_REVIEW_REQUIRED; sin servicios de categoría |
| `a23c6ce8-a186-4e1a-8b09-3100cc142bc7` | ninguna | MANUAL_REVIEW_REQUIRED; sin servicios de categoría |
| `bec6390b-5782-422f-9654-82687553b84e` | ninguna | MANUAL_REVIEW_REQUIRED; sin servicios de categoría |

El código de onboarding y la RPC servidor-side `business_review_requirements`/`submit_business_for_review` requieren categoría antes de enviar a revisión/publicar. Un draft puede conservar NULL. No se impuso NOT NULL global. Home lee `is_featured`, `accepts_requests`, `rating_avg`, `review_count`, `primary_category_id` y media con tipos reales (`logo`, `cover`, `gallery`, `portfolio`); no se añaden ratings falsos.

## Contacto, Edge y secretos

| Función | JWT / scope | Secretos | CORS / datos |
|---|---|---|---|
| `submit-contact` | JWT opcional; anon permitido; token se valida y sólo enlaza profile existente | `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` runtime-managed | orígenes exactos, validación y payload ≤10 KB; RPC controlada, hashing, 429 e idempotency |
| `admin-user` | JWT obligatorio por validación de la función; operaciones globales exigen gate SuperAdmin/sesión | Supabase URL/service role runtime-managed | orígenes allowlist; auditoría; sin key en cliente |
| `notify-provider-review` | JWT del usuario no aplica; webhook entrante requiere header secreto; destinatarios solo SuperAdmin activo | `ADMIN_NOTIFICATION_WEBHOOK_SECRET` REQUIRED; Supabase URL/service role runtime-managed | requiere webhook DB; no almacenar contacto externo, notificaciones internas |

`ADMIN_NOTIFICATION_WEBHOOK_SECRET = REQUIRED / MISSING`. El handler responde 401 si falta o no coincide. No se creó ni mostró valor. Desplegar solo después de configurar secret y crear/validar webhook. CORS contiene `https://rancoconecta.cl`, `https://www.rancoconecta.cl` y desarrollo local explícito; sin wildcard.

Orden de deploy preparado: migraciones aprobadas → secrets de Edge (valor manual del webhook) → `submit-contact` → `admin-user` → `notify-provider-review` y webhook → health/CORS/JWT checks. No se desplegó.

## Validaciones

- Flutter: `flutter analyze` PASS; `flutter test --reporter compact` **630/630 PASS**.
- `dart format .`: PASS, 203 archivos, un archivo nuevo formateado.
- `scripts/check_text_encoding.ps1`: PASS.
- `git diff --check`: PASS; avisos de conversión LF/CRLF del repositorio.
- `flutter build web --release`: PASS (`build/web`). El build regeneró artefactos Vercel ya trackeados; no hubo deploy. Revisar/restaurar esos artefactos sólo con propietario de sus cambios.
- Deno: **7/7 PASS**; `deno check` para las 3 Edge Functions: PASS.
- SQL: **13/13 archivos de contrato** PASS en PostgreSQL aislado (incluye grants hotfix, helpers, platform gate, Contact abuse, search path, matriz, bootstrap y suites anteriores); el backfill de categorías pasó su fixture de tres filas y `ROLLBACK`.
- Contacto: SQL valida submit válido anónimo, duplicado por UUID/contenido, límite email/IP y hash de identidad user, respuesta `rate_limited` y expiración; Deno valida hashes para identidad autenticada/anon, idempotency, payload inválido/largo, códigos HTTP y CORS. No se ejecutó HTTP real de Edge Runtime porque el stack local Supabase/Docker no estaba disponible.
- PostgreSQL aislado de Windows disponible (PG 16); Docker daemon no disponible. `.playwright-cli/` está ignorado. Clúster temporal permanece en `%TEMP%\ranco-3262a-grants-model`; limpieza manual opcional cuando ya no se requiera.
- Las pruebas Flutter imprimen algunos logs `AdminErrorState` por Supabase no configurado en el fixture y una advertencia de `tap()` fuera del hit-test en un test de interacción; suite finalizó PASS, sin analyzer issues. No se clasificaron como regresión confirmada.

## Decisiones humanas y bloqueos

Decisiones humanas una vez resuelto el bloqueo técnico: (1) ID del primer SuperAdmin; (2) categoría de cada uno de los tres negocios ambiguos; (3) configurar el secret requerido; (4) autorizar el apply de producción.

Bloqueos técnicos actuales:

1. Repetir las 28 migraciones con snapshot remoto fiel o modelo que incluya tipos, policies, triggers y grants reales; comprobar before/after reales del snapshot. PostgreSQL aislado cubre ejecución SQL, no reemplaza ese requisito.
2. Cerrar revisión semántica por función sobre los SECURITY DEFINER remotos marcados NEEDS HARDENING, especialmente los 54 efectivamente ejecutables por anon en el remoto actual; el catálogo y marcadores están inventariados, pero los cuerpos completos no se calificaron exhaustivamente contra todos los paths de privilegio. No aplicar `072000` hasta resolver callers/EXECUTE legítimos y comprobar mínimo privilegio.

Producción sigue en estado **parcialmente hardened** por tenant-admin-as-global-admin, RPC authenticated y helpers internos expuestos. No se hicieron nuevas escrituras. No aplicar aún.
