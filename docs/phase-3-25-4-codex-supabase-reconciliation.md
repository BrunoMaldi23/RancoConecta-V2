# Fase 3.25.4 — Reconciliación segura Supabase remoto ↔ migraciones locales

Fecha: 2026-10-05. Proyecto consultado: `ranco_conecta_2` (`exdaagbftotnnoyetcpg`, `https://exdaagbftotnnoyetcpg.supabase.co`). El remoto fue consultado solo en lectura. No se aplicó ninguna migración, no se desplegaron Edge Functions y no se modificaron datos remotos.

## Resultado ejecutivo

La reconciliación remota **se detuvo antes de aplicar cambios**, conforme al punto 25. La migración pendiente `20261004133000_provider_role_separation.sql` actualiza los roles de perfiles existentes a `provider` según negocios/membresías. Además, el esquema remoto difiere del repo en tipos, columnas y FK de negocio, y no se confirmó un mecanismo remoto de recuperación. Un dump lógico es técnicamente posible con Supabase CLI, pero no se creó un archivo de PII ni se verificó cifrado/retención; el estado de backups/PITR del proyecto no es visible desde las consultas usadas.

Sí se reconcilió localmente la discrepancia de Home con la nueva migración `20261005005000_reconcile_business_home_fields.sql`. Un reset desde cero aplicó 51 migraciones. También se simuló en local el historial remoto de 31 migraciones con los campos/constraints/índice productivos ya presentes antes de aplicar las 20 siguientes: se aplicaron sin duplicados ni error. **Esto no constituye autorización ni prueba para aplicar el lote remotamente.**

## 1. Migraciones pendientes auditadas

Antes de esta fase, el repo tenía 50 migraciones y el remoto tenía aplicadas las primeras 31 hasta `20261003181310`. Estas son las 19 pendientes originales:

En la tabla, cuando no se indica RLS/policy, la migración no altera policies. Ninguna migración salvo 041330 ejecuta un backfill/update sobre filas existentes: las RPC/triggers modifican datos solo cuando se invoquen o disparen después. 050020 inserta keys de settings con `ON CONFLICT DO NOTHING`, por lo que conserva valores existentes.

| Migración | Propósito y objetos/tables | Estado remoto / duplicados | Riesgo y clase |
|---|---|---|---|
| `20261004120000_provider_identity_and_draft_reuse.sql` | Reemplaza `handle_new_auth_user` y `create_business_draft`; perfiles, businesses, business_members, audit_logs. Sin tabla/policy nueva. | Ambas funciones ya existen con las mismas firmas; usa `CREATE OR REPLACE`. | Cambia el comportamiento de futuros registros/creación de drafts. **REQUIERE ADAPTACIÓN**: confirmar trigger Auth actual y revisar función remota antes de reemplazar. |
| `20261004121000_admin_user_role_management.sql` | Protección de campos privilegiados de profiles y RPC `admin_change_user_role`; grants restringidos. | La función de protección ya existe; la RPC de cambio de rol no aparece en remoto. | Cambia guardas de escritura; operación de rol solo ocurre al invocar la RPC. **REQUIERE ADAPTACIÓN** a usuarios/roles reales y prueba de grants. |
| `20261004122000_notification_recipients_and_activity.sql` | Funciones y triggers de eventos para service_requests, lodging_bookings y gastronomy_table_reservations; inserta notifications para destinatarios. | `notify_business_managers` ya existe; no se encontraron los triggers de actividad con esos nombres. Los triggers usan DROP IF EXISTS antes de crear. | Puede cambiar notificaciones de eventos futuros; no backfill. **SAFE** tras revisar destinatarios y deduplicación. |
| `20261004123000_category_audit.sql` | Función/trigger de auditoría para categories y audit_logs. | El objeto con ese nombre no se encontró. DROP IF EXISTS antes de crear trigger. | Solo audita futuros cambios de categorías. **SAFE**. |
| `20261004124000_review_requirements_by_type.sql` | Reemplaza `business_review_requirements(uuid)`; lectura de businesses y tablas por tipo. | La función ya existe con igual firma. | Cambia la validación de revisión de negocios. **REQUIERE ADAPTACIÓN**: cotejar definición y despliegue antes de reemplazar. |
| `20261004125000_admin_audit_read.sql` | Reemplaza la policy de lectura de audit_logs para admins. | RLS está activa en audit_logs; la policy objetivo no aparece. DROP IF EXISTS; luego crea policy admin. | Cambio de acceso a auditoría, limitado a admin. **SAFE** después de comprobar la expresión y grants efectivos. |
| `20261004130000_suspended_session_gate.sql` | Define `account_session_allowed`/`reject_suspended_api_request`, configura pre-request de `authenticator`, agrega policies restrictivas a todas las tablas públicas con RLS y storage.objects. | Funciones/policy de sesión no encontradas. El bucle elimina policy por nombre antes de crearla. | Cambio transversal de acceso para todas las sesiones y storage. **REQUIERE ADAPTACIÓN** y prueba de todos los clientes antes de producción. |
| `20261004131000_admin_account_suspension.sql` | RPC de suspensión/reactivación, profiles y audit_logs; exige admin y protege último admin. | RPC no encontrada. | Cambia estado al invocarla; el archivo no hace backfill. **SAFE** tras pruebas con cuentas QA y revisión de guardas. |
| `20261004132000_pre_request_execute_roles.sql` | GRANT EXECUTE de `reject_suspended_api_request` a service_role. | La función depende de 041300 y hoy no existe. | Permiso aditivo e idempotente. **SAFE**, pero dependiente de 041300. |
| `20261004133000_provider_role_separation.sql` | Cambia perfiles customer a provider si poseen negocio o membership owner/manager; crea/actualiza funciones de identidad y guardas. | Las funciones `current_user_is_provider`, `create_business_draft` y `protect_profile_privileged_fields` existen ya; el backfill de roles sí afectaría perfiles reales que cumplan el filtro. | **NO APLICAR TODAVÍA**. Requiere inventario y aprobación explícita de los perfiles afectados; el punto 25 obliga a detener la aplicación remota de este lote. |
| `20261004134000_admin_mutation_capability.sql` | Función de capacidad/readiness para mutaciones admin y grants. | No encontrada. | Sin DML durante migración. **SAFE** después de probar el chequeo y sus grants. |
| `20261004135000_restrict_notification_helper.sql` | Revoca ejecución directa de `notify_business_managers`. | La función existe en remoto. | Endurecimiento de permisos; triggers la siguen ejecutando como función de trigger/helper según ownership. **SAFE** tras probar invocación legítima y grants. |
| `20261004140000_role_business_transition_guard.sql` | Reemplaza trigger function de profile role guard para impedir transiciones incompatibles con negocios activos. | La función actual ya existe. | Cambia futuras operaciones de rol de perfiles con negocios. **REQUIERE ADAPTACIÓN**: probar con propietarios/administradores y membresías productivas. |
| `20261004141000_admin_settings_audit_and_user_status.sql` | Elimina policy de UPDATE directo y revoca UPDATE en system_settings; reemplaza RPC de WhatsApp y agrega overload de búsqueda admin por estado; audit_logs. | `admin_update_whatsapp_settings` existe; existe overload de `admin_search_users` con 4 args, no el de 5; la policy de UPDATE directo sí existe. | Cambia permisos actuales y el endpoint de settings. **REQUIERE ADAPTACIÓN**: comprobar cliente desplegado y grants antes de retirar acceso directo. |
| `20261005000000_contact_messages.sql` | Crea contact_messages, CHECKs/FK/index, RLS/policy admin, RPC estado auditada y trigger de notificación. | Tabla/RPC/trigger ausentes en remoto. CREATE TABLE/INDEX IF NOT EXISTS; la policy se crea sin guard, pero la tabla remota hoy no existe. | Inserciones se harán por Edge Function; cambios de estado auditados. **SAFE** si se aplica después de revisar dependencias y grants. |
| `20261005001000_admin_user_deletion.sql` | Crea RPC de eliminación lógica; solo al invocarse marca profile deleted y anonimiza PII conservando relaciones/historial. | RPC ausente. | No elimina Auth ni ejecuta DML al migrar. **SAFE** tras validar FKs dinámicas/último admin en QA. |
| `20261005002000_contact_and_notification_settings.sql` | Inserta cinco keys de settings con ON CONFLICT DO NOTHING; crea RPC públicas/admin, audita settings y reemplaza funciones de avisos. | Keys nuevas y RPC ausentes; `notify_admins_on_business_review` ya existe y será reemplazada. | Preserva valores preexistentes por ON CONFLICT; cambia avisos futuros. **SAFE** tras respaldar/validar valores y comparar el trigger de avisos existente. |
| `20261005003000_pre_request_service_role.sql` | Repite GRANT EXECUTE para service_role en `reject_suspended_api_request`. | Función depende de 041300. El mismo grant ya está en 041320. | **Duplicado idempotente**; no crea objeto ni altera datos. **SAFE**, redundante. |
| `20261005004000_revoke_anon_admin_rpc.sql` | Revoca PUBLIC/anon de todas las funciones SECURITY DEFINER `admin_*` con permiso anon. | 12 RPC admin anon-executable; ver sección seguridad. | Reduce permisos y puede interrumpir consumidores que usen RPC admin sin sesión. **SAFE** como endurecimiento después de migrar/validar el uso autenticado; debe verificarse con catálogo tras aplicarla. |

El orden funcional de migraciones es el orden cronológico local. Dependencias directas: 041300 define el pre-request usado por 041320/050030; 041310 usa las guardas de rol introducidas por 041210; 050000 usa perfiles, notifications y `current_user_is_admin`; 050020 usa system_settings/audit_logs y reemplaza la función de aviso existente; 050040 conviene al final para revocar también las RPC creadas/reemplazadas por el bloque. La migración nueva de Home se aplica después de ese bloque en reset local y no depende de él.

## 2. Drift remoto capturado

### `public.businesses`

| Elemento | Remoto | Local después de reset |
|---|---|---|
| `is_featured` | boolean, NOT NULL, default false | añadido por nueva migración, igual |
| `accepts_requests` | boolean, NOT NULL, default true | añadido por nueva migración, igual |
| `rating_avg` | numeric, NOT NULL, default 0; CHECK 0–5 | añadido con default/check iguales |
| `review_count` | integer, NOT NULL, default 0; CHECK >=0 | añadido con default/check iguales |
| Índice destacado | `idx_businesses_featured` btree sobre `is_featured` | creado con migración nueva |
| Comentarios | null en los cuatro campos | sin comentario |
| Campos restantes | remoto contiene `published_at`; no contiene `latitude`/`longitude` | local conserva `latitude`/`longitude`; no contiene `published_at` |
| Tipos | `business_type`, `publication_status`, `verification_status` son text con CHECKs | los tres son tipos enum PostgreSQL |
| FK owner | `businesses.owner_id → auth.users(id) ON DELETE CASCADE` | `businesses.owner_id → profiles(id) ON DELETE RESTRICT` |
| Otros constraints | Checks de business/publication/verification status, rating y review_count; PK, slug unique y FK a categories | enums/checks y FK heredados del historial local; modelo de owner no coincide |

No se convirtió ni eliminó ninguna columna/FK: el FK CASCADE remoto y las diferencias de tipos/columnas son ambiguas y requieren decisión del dueño del modelo antes de cualquier reconciliación adicional. El nuevo migration corrige solo el subconjunto aditivo acordado de Home.

### Otras tablas auditadas

- Remoto tiene RLS en businesses, profiles, notifications, system_settings, audit_logs, service_requests, lodging_bookings y gastronomy_table_reservations.
- Remoto no tiene contact_messages.
- `profiles.role/account_status` son text en remoto y enums `app_role/account_status` en local.
- `service_requests.urgency/status` son text en remoto; local usa enums. Además, remoto carece de latitude/longitude que sí existen en local.
- `notifications`, `system_settings`, `audit_logs`, business_members y las dos tablas de reservas consultadas coinciden en las columnas revisadas.
- Remoto conserva políticas directas de actualización de system_settings, mientras que 041410 las retira y ofrece RPC auditada.
- Remoto conserva trigger de notificación al cambiar business a revisión, pero no tiene trigger de actividad para contacto ni las policies/routines de contacto.
- No se encontró función ni trigger de auditoría de categorías con el nombre de la migración pendiente. `business_review_requirements`, `handle_new_auth_user`, `create_business_draft`, `protect_profile_privileged_fields` y `notify_business_managers` sí existen ya en remoto; los cambios correspondientes son reemplazos, no creaciones de funciones nuevas.

Estas diferencias muestran que el drift supera las 19 versiones pendientes y no se arregla marcando migraciones como aplicadas. Varias columnas presentes en remoto no tienen una definición de tabla en el historial local y algunos tipos/FK son distintos.

## 3. Migración nueva de Home

Creada `supabase/migrations/20261005005000_reconcile_business_home_fields.sql` sin editar migraciones anteriores. Esta:

- agrega las cuatro columnas con IF NOT EXISTS y defaults/no-null de producción;
- valida que columnas preexistentes tengan tipo, default y nullability esperados, y falla explícitamente si no coinciden;
- crea/valida los checks de rating y contador sin duplicar checks semánticamente equivalentes;
- evita duplicar un índice btree equivalente y falla si el nombre canónico existe con definición incompatible.

La migración se aplicó sobre base limpia y sobre simulación con esos objetos ya preexistentes. El catálogo resultante coincidió con las definiciones de las columnas, checks e índice observados remotamente. Las demás diferencias de `businesses` se dejan documentadas; no se forzaron cambios tipo/FK ni DROP.

## 4. Dry run local y simulación

- Docker Desktop/Engine disponible; Supabase local levantado.
- `npx supabase db reset`: aplicó 51/51 migraciones y seed desde cero.
- Escenario remoto simulado: reset hasta 20261003181310 (31 migraciones), se añadieron localmente los cuatro campos, checks e índice presentes en remoto y se cambió el FK owner al destino/acción de borrado remotos; `npx supabase migration up --local` aplicó las 20 restantes sin conflictos de columna, constraint, índice, función, trigger o policy.
- La simulación no reproduce todas las divergencias de tipos/columnas observadas en profiles/service_requests/businesses; por ello no prueba seguridad de migrar el remoto.
- Pruebas SQL `phase_3_21_security_flow.sql`, `phase_3_22_admin_contracts.sql` y `phase_3_25_2_local_integration.sql`: pasaron en base limpia.
- Edge HTTP local `phase_3_25_2_local_api.mjs`: PASS. Incluyó contacto anónimo/autenticado, validaciones, RLS, Edge admin, invitación, roles, suspensión/reactivación, protecciones de último admin, settings, notificaciones, negocio/solicitud/reserva, soft-delete y auditoría.
- Nuevo contrato PostgREST local `phase_3_25_4_home_contract.mjs`: HTTP 200 para los cuatro campos de Home; no hubo error 42703.
- Deno: 2/2 tests; type-check de submit-contact y admin-user pasó.

## 5. Recuperación antes de tocar remoto

No se confirmó en esta sesión si el proyecto tiene backups automáticos o PITR habilitado. CLI permite `supabase db dump --linked`, pero no se generó dump completo porque contendría datos/PII de producción y no se confirmó ubicación cifrada, acceso ni retención. Por lo tanto, no hay una copia de recuperación comprobada para esta fase. Esto es un bloqueador independiente para cualquier aplicación remota.

## 6. Edge Functions y secrets

- Remote: 0 Edge Functions desplegadas; ninguna versión remota que comparar.
- Para los flujos de Fase 3.25.1, el frontend invoca `submit-contact` y `admin-user`. `notify-provider-review` no tiene referencias de invocación en el frontend y no se desplegó ni se propone desplegar como parte de los dos flujos.
- Las funciones usan variables gestionadas por Supabase `SUPABASE_URL`, `SUPABASE_ANON_KEY` y `SUPABASE_SERVICE_ROLE_KEY`; el código las lee del entorno y no hay claves administrativas en Flutter. CLI reportó cero secrets custom configurados; no se imprimieron valores.
- `submit-contact` permite envío según contrato, valida servidor y configura CORS local; `admin-user` valida JWT real y rol/status admin server-side aunque Gateway `verify_jwt=false`. No se hizo deploy; CORS/Auth de un endpoint remoto no están validados.

## 7. Decisión sobre aplicación remota

**Detenido antes de cualquier escritura remota.** Motivos:

1. 041330 actualiza roles de perfiles existentes; no se conoce qué perfiles afectaría y el punto 25 exige detenerse.
2. El FK owner remoto con ON DELETE CASCADE no coincide con el local ON DELETE RESTRICT; tipos enum/text y columnas geográficas/published_at también divergen. Cambiarlos sin conocer su origen puede alterar compatibilidad e historial.
3. Backup/PITR/recuperación no se confirmó.
4. No hay Edge Functions remotas y no se proporcionaron cuentas remotas de QA autorizadas.
5. Aunque la simulación local pasó, no fue un diff exhaustivo de cada objeto remoto.

Por estos motivos no se aplicó `db push`, ni `migration up --linked`, ni migrations individuales al remoto. Tampoco se desplegaron funciones ni se hicieron pruebas de escritura/contacto contra usuarios reales.

El catálogo remoto vuelve a confirmar **12 RPC `admin_* SECURITY DEFINER` con EXECUTE para anon**; las funciones sensibles inspeccionadas incluyen chequeo interno de admin, pero el permiso es más amplio de lo necesario. La migración 050040 no se aplicó remotamente. En local, tras reset y 050040, el mismo conteo fue 0.

## 8. Validación final y estado remoto

- Flutter format: 203 archivos inspeccionados, 0 cambiados.
- `flutter analyze`: OK.
- `flutter test`: 630/630.
- UTF-8: OK.
- `git diff --check`: OK; solo advertencias CRLF de Git en archivos preexistentes.
- `flutter build web --release`: OK.
- Deno: 2/2; type-check: OK.
- Antes de esta fase: remoto 31 aplicadas, 19 pendientes.
- Después de esta fase: remoto sigue en 31 aplicadas, sin cambios. Repo tiene ahora 51 migraciones; por tanto 20 versiones locales están pendientes contra el historial remoto.
- Home funciona contra PostgREST local con los cuatro campos; Home remoto no se probó en navegador en esta fase.
- Contacto/Admin/CRUD/RLS fueron probados localmente, no contra producción.
- No se eliminaron datos reales; no se ejecutaron cambios remotos destructivos; no se expusieron secretos; no hubo commit ni push.

**Fase no cerrada.** Para continuar hace falta resolver la clasificación/destino de roles existentes en 041330, explicar el origen de las diferencias estructurales de businesses/profiles/service_requests, y confirmar recuperación del proyecto. Después se puede preparar una secuencia remota revisable en bloques y desplegar únicamente las funciones aprobadas.
