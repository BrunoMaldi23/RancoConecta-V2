# Fase 3.25.6 — Hardening de seguridad y reconciliación de roles

Fecha: 2026-10-05. Alcance: migraciones y pruebas locales; Supabase remoto se consultó solamente en las auditorías previas documentadas en 3.25.5. No se ejecutó ninguna escritura remota, `db push`, deploy, cambio de usuario real, commit ni push.

## Resultado

**READY FOR REMOTE APPLY: NO.** El modelo local ahora separa identidad global `super_admin` de los permisos tenant basados en `businesses.owner_id`/`business_members`, requiere una sesión global explícita y auditada, endurece grants y conserva la historia comercial al eliminar lógicamente una cuenta. Las suites locales cubren estos contratos. Sigue faltando un backup remoto restaurable confirmado (PITR desactivado y CLI sin backups listados) y una simulación integral sobre snapshot fiel del esquema remoto. La base remota no se modificó.

## 1. Modelo de roles

| Identidad | Representación | Alcance autorizado |
|---|---|---|
| SuperAdmin SaaS | `profiles.role='super_admin'` + `super_admin_sessions` activa | RPC/policies globales tras iniciar sesión elevada con propósito y expiración, dejando auditoría. No entra automáticamente en `is_business_owner`/`is_business_admin`. |
| Administrador tenant | perfil `admin` más membership `business_members.role='manager'` activa | Solo operaciones del negocio asociado a la membership; `profiles.role='admin'` no da acceso global. |
| Propietario | `businesses.owner_id` y/o membership `owner` activa | Solo negocio propio. |
| Prestador | perfil `provider` y/o identidad comercial con negocio/membership owner-manager activa | Flujo comercial y operaciones dentro del negocio; sin privilegio global. |
| Cliente | perfil `customer` | Funciones de cliente y datos propios; sin privilegio global. |
| Anónimo | rol API `anon` | Lectura pública según policies y funciones públicas permitidas; ninguna administración. |

`business_members.role` es la fuente del rol de tenant. La función `current_user_is_provider()` también reconoce propietarios/managers activos para no depender de convertir forzosamente su perfil a provider.

## 2. Helpers y políticas

La migración nueva `20261005006000_security_roles_grants_owner.sql` define `is_super_admin()`, `start_super_admin_session()`, `end_super_admin_session()`, `is_business_owner(uuid)`, `is_business_admin(uuid)` y redefine `user_can_manage_business(uuid)` como permiso tenant-scoped. `current_user_is_admin()`/`is_admin()` significan ahora SuperAdmin con sesión explícita activa. La sesión exige propósito de 12–400 caracteres, dura 5–60 minutos y se registra en `audit_logs`.

Las RPC que usan el helper global —configuración, usuarios, auditoría, moderación global, mensajes de contacto— quedan cerradas a `admin` tenant, provider, customer y anon. Las políticas tenant se basan en owner/membership, sin una excepción global automática. Los destinatarios de alertas globales de moderación/contacto se limitaron a perfiles SuperAdmin activos.

La revisión de policies existentes encontró expresiones históricas que llaman `is_admin()`; siguen funcionando con el nuevo significado y evalúan falso sin sesión elevada. `system_settings` global solo se puede cambiar mediante RPC con sesión SuperAdmin; el acceso directo UPDATE no recibe grant. `contact_messages` no recibe INSERT/SELECT para anon; el envío público queda a cargo de la Edge Function validada. Audit conserva escritura por mecanismos de servidor/función, sin INSERT/UPDATE/DELETE de anon/authenticated.

## 3. Matriz de RPC globales y tenant

| RPC / clase | SuperAdmin con sesión | Owner | Tenant admin | Provider | Customer | Anon |
|---|---:|---:|---:|---:|---:|---:|
| `admin_*` globales: usuarios, settings, contacto, auditoría y moderación | Sí | No | No | No | No | No |
| `user_can_manage_business(uuid)` / helpers de negocio | Solo por owner/membership propia | Negocio propio | Negocio de membership manager | Solo membership/propiedad explícita | No | No |
| RPC públicas de lectura/lista autorizadas por diseño | Según policy pública | Sí | Sí | Sí | Sí | Sí, solo lectura pública |
| `start_super_admin_session(text,integer)` | Sí, requiere perfil SuperAdmin activo | No | No | No | No | No |
| `end_super_admin_session()` | Sí | No | No | No | No | No |

El inventario remoto previo detectó 12 RPC `admin_* SECURITY DEFINER` ejecutables por anon: `admin_analytics_summary()`, `admin_business_review_detail(uuid)`, `admin_business_review_queue(text,text,text,integer,integer)`, `admin_business_review_stats()`, `admin_get_business_review(uuid)`, `admin_list_users(integer,integer)`, `admin_publish_business(uuid)`, `admin_reject_business(uuid,text,boolean)`, `admin_request_business_changes(uuid,text)`, `admin_restore_business(uuid)`, `admin_suspend_business(uuid,text)` y `admin_update_whatsapp_settings(text,boolean,boolean,boolean,boolean)`. `20261005004000_revoke_anon_admin_rpc.sql` cubre las 12 por el predicado `proname` `admin_` + SECURITY DEFINER + privilegio efectivo anon. La migración nueva vuelve a retirar anon/PUBLIC de todas las funciones SECURITY DEFINER salvo allowlist revisada; local quedó en **0 RPC admin anon**.

## 4. SECURITY DEFINER y grants

La nueva migración audita **todas** las funciones SECURITY DEFINER del schema `public`: exige `search_path` explícito, propietario `postgres`/`supabase_admin`, retira EXECUTE de PUBLIC/anon, conserva los grants autenticados previamente explícitos y limita las excepciones anon a `is_admin()`, `user_can_manage_business(uuid)`, `user_can_manage_business_path(text)`, `record_business_analytics_event(uuid,text)`, `reject_suspended_api_request()` y `public_contact_channels()`.

A anon/authenticated se les revocan todos los privilegios de tablas existentes y después se reotorgan solo SELECT/INSERT/UPDATE/DELETE que tienen policy RLS permisiva equivalente. Nunca se concede a esos roles `TRUNCATE`, `REFERENCES` ni `TRIGGER`. Tablas futuras tampoco se exponen automáticamente (`auto_expose_new_tables=false`) y los default privileges de postgres no conceden acceso a anon/authenticated. `service_role` mantiene permisos backend necesarios para las Edge Functions y no debe aparecer en Flutter ni en el navegador.

En una corrida HTTP inicial, la reducción de grants reveló que faltaba `INSERT` backend para `service_role` en `contact_messages` (la Edge Function devolvía 503). Se corrigió la migración con grants de servidor explícitos a service_role y se verificó de nuevo el flujo HTTP anónimo/autenticado. No se amplió acceso cliente.

## 5. Protección de perfil y roles ambiguos

No se editó `20261004133000_provider_role_separation.sql`. La nueva migración `20261004132500_capture_provider_role_candidates.sql`, situada antes de la histórica, guarda una fotografía no PII de los customers con negocio o membership owner/manager: id, rol previo y señales objetivas (provider registration, negocio publicado, onboarding iniciado). `050060` reconcilia esa fotografía después de la promoción histórica: solo considera confirmado provider con señal objetiva explícita; marca onboarding sin señal como `AMBIGUO` y restaura customer; guarda la resolución/auditoría.

La simulación remota agregada en 3.25.5 encontró **3 customer** afectados por el UPDATE masivo. Los tres tienen negocio y membership owner/manager, sin provider registration ni negocio publicado y con onboarding iniciado; los tres quedan **AMBIGUO**, no se cambian a provider. El acceso comercial sigue resuelto por owner/membership. El snapshot conserva evidencia mínima; no incluye nombres/correos.

Se detectó y corrigió además una falla de lógica SQL NULL en el guard del trigger: `auth.role() <> 'service_role'` y `current_setting(...) <> 'on'` podían evaluar NULL y no activar el bloqueo. La nueva definición usa `IS DISTINCT FROM` y `coalesce`, y el test cubre intento de cambiar a administrador a un propietario/prestador.

## 6. `businesses.owner_id`

Modelo local elegido: `businesses.owner_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT ON UPDATE NO ACTION`. En el remoto auditado previamente, el FK apunta a `auth.users(id) ON DELETE CASCADE`. Se cambia solo en migración local tras comprobar que todos los `owner_id` poseen profile y que los tipos son UUID; aborta con error si hay huérfanos, no corrige ids y valida la FK antes de terminar. Conserva todos los owner_id. Eliminación Auth física de un owner se bloquea mientras tenga business; el producto usa soft delete de profile.

El endpoint `admin-user` ya no llama `auth.admin.deleteUser()` tras `admin_mark_user_deleted()`: conserva auth.users y FKs/historial, mientras `account_status='deleted'` bloquea sesión y el profile queda anonimizado/auditado. Se actualizó la prueba HTTP para confirmar Auth conservado y relaciones persistentes.

## 7. Backup y recuperación

El estado de 3.25.5 informa remoto `pitr_enabled=false` y `backups=[]` en CLI. Esta fase no volvió a ejecutar una consulta remota de estado de plan ni pudo confirmar Dashboard. **Antes de Fase 3.25.7 se debe confirmar manualmente en Supabase Dashboard**: backup diario disponible, fecha/retención, capacidad de restaurar a proyecto alterno, y si PITR puede habilitarse. No considerar backup probado hasta restaurar una copia aislada.

Procedimiento mínimo alternativo si el plan no ofrece backup restaurable: desde una estación segura con CLI actualizado y credenciales vía `SUPABASE_DB_PASSWORD` cargadas en entorno privado (nunca en argumentos/logs), ejecutar dump schema-only y dump data-only de tablas críticas (`profiles`, `businesses`, `business_members`, providers si existiera, requests, bookings/reservations, settings, notifications y audit); cifrar archivos fuera del repo; comprobar checksums; restaurar ambos dumps en proyecto Supabase aislado, verificar FKs/conteos y retener clave cifrada separada. Añadir buckets/storage y Auth export mediante procedimiento aparte; dump SQL no recupera automáticamente esos servicios. Si no se confirma backup/recovery razonable, detener la aplicación remota.

## 8. Migraciones nuevas y orden futuro

Nuevas migraciones locales de esta fase:

1. `20261004132500_capture_provider_role_candidates.sql` — antes de 041330, snapshot no PII y bloqueado por RLS/grants.
2. `20261005006000_security_roles_grants_owner.sql` — después de reconciliación Home 050050; adapta FK owner, separa sesiones SuperAdmin, redefine helpers, reconcilia roles, ajusta recipients, minimiza grants y audita SECURITY DEFINER.

No se cambia historial anterior. La aplicación futura debe ejecutar el lote remoto completo en modo mantenimiento, con captura justo antes de 041330 y `050060` después de 050050; mantener el tráfico detenido hasta finalizar ambas y verificar resolución de candidatos. No usar `migration repair`. No hacer `db push` de lote no revisado.

## 9. Pruebas locales

- SQL nueva `supabase/tests/phase_3_25_6_security.sql`: grants `TRUNCATE/REFERENCES/TRIGGER`; cero admin SECURITY DEFINER anon; zero SECURITY DEFINER sin search_path; allowlist anon; RLS y grants de `contact_messages`; audit sin escritura directa; owner FK RESTRICT; SuperAdmin/tenant admin/owner/provider/customer/anon; acceso settings global; sesión SuperAdmin explícita y auditada; rechazo delete Auth que borraría negocio.
- Se actualizaron fixtures SQL previos para usar rol `super_admin` + sesión auditada, manteniendo sus escenarios de contrato.
- Flujos HTTP local cubren contacto Edge válido/inválido/anónimo/autenticado, RLS directo, no JWT/usuario normal/admin, invitación, rol, suspensión/reactivación, protecciones, settings, WhatsApp manual, notificaciones y soft-delete con historial/negocio/solicitud/reserva.
- Home contract: HTTP 200 y cero filas visibles.
- Supabase reset limpio: por validar tras la última edición de grants backend.
- Flutter/Dart, encoding, build y Deno: resultados finales por incorporar tras validar cambios de guard global.

## 10. Limitaciones/riesgos

- El entorno remoto sigue sin backup restaurable confirmado y 20 migraciones remotas pendientes según el inventario previo. No se tocó.
- No existe aún un procedimiento de bootstrap de la primera cuenta `super_admin` dentro de esta fase; la primera asignación debe hacerse mediante mecanismo de operador controlado y auditado, independiente del rol `admin` tenant, antes del primer uso de las RPC globales.
- Un snapshot completo remoto con tipos text, columnas adicionales y expresiones completas de policies no se restauró en esta fase; reset limpio valida migraciones desde cero, no reemplaza ese ensayo requerido antes de producción.
- Las tres filas candidatas observadas son agregadas y anonimizadas; repetir la simulación justo antes del futuro apply y abortar si el conjunto/cantidad cambió.

## 11. Estado final

**READY FOR REMOTE APPLY: NO.** Código local y pruebas definen el hardening, pero aplicación remota queda condicionada a: backup restaurable confirmado y ensayado; snapshot remoto íntegro; bootstrap explícito y auditado de SuperAdmin; plan de mantenimiento que no deje tráfico entre 041330 y 050060; assertions de conteos/roles y FK ejecutadas en copia aislada.

Confirmación: Supabase remoto no se modificó, no se desplegaron Edge Functions, no se cambiaron usuarios reales, no se borraron datos remotos, no se expusieron secretos, no hubo commit ni push.
