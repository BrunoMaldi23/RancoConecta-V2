# Fase 3.25.3 — Validación controlada de Supabase real

Fecha: 2026-10-05. Auditoría remota de solo lectura del proyecto vinculado. No se ejecutaron migraciones, llamadas de escritura, pruebas con usuarios, deploys ni cambios remotos.

## Resultado ejecutivo

**Fase no cerrada.** El proyecto remoto consultado es `exdaagbftotnnoyetcpg` (`ranco_conecta_2`). El historial remoto registra 31 migraciones hasta `20261003181310`, mientras el repo contiene 50; están pendientes 19, incluidas `20261005000000_contact_messages.sql` y `20261005004000_revoke_anon_admin_rpc.sql`. La lista remota de Edge Functions está vacía. Contacto y creación/invitación de administradores no se pueden probar contra las funciones previstas porque no están desplegadas.

El control remoto confirmó que `businesses` sí tiene `is_featured`, `accepts_requests`, `rating_avg` y `review_count`, con defaults `false`, `true`, `0` y `0`, respectivamente; existe también `idx_businesses_featured`. Esta instancia representa la situación **A parcialmente**: producción ya tiene esos campos, pero no hay una migración del repo que los declare en la tabla base. La discrepancia local de Home es reproducible en un reset limpio local y no se resuelve cambiando nombres del frontend. El modelo de producción debe documentarse en una migración local reproducible antes de volver a desplegar.

Además, varias funciones `SECURITY DEFINER` con prefijo `admin_` conservan `EXECUTE` efectivo para `anon`. Las funciones inspeccionadas validan internamente el usuario administrador, pero el permiso de invocación anónima sigue siendo innecesario; la migración local `20261005004000_revoke_anon_admin_rpc.sql` está pendiente y apunta a corregirlo. No se aplicó por tratarse de una alineación remota que exige revisar y ejecutar el conjunto pendiente en orden, no un `db push` ciego.

## 1. Entorno remoto auditado

- `supabase/.temp/project-ref` y el proyecto enlazado por CLI identifican el ref `exdaagbftotnnoyetcpg`; `supabase/config.toml` usa el project id local `ranco_conecta_2`.
- URL derivada del ref: `https://exdaagbftotnnoyetcpg.supabase.co`.
- Se usó Supabase CLI 2.116.0. Consultas realizadas con `migration list --linked`, `functions list` y consultas SQL `--linked` de solo lectura.
- `functions list` devolvió cero funciones desplegadas. Esto incluye `submit-contact`, `admin-user` y `notify-provider-review`, que existen en el repo.
- `secrets list` devolvió cero secrets configurados en el proyecto. No se consultaron ni imprimieron valores de credenciales. Las variables gestionadas por la plataforma no se pueden inferir de esa lista.
- Auth no se modificó ni se probaron inicios de sesión; no se proporcionaron credenciales de QA remoto. La presencia de los esquemas `auth`/`public` y de perfiles asociados se verificó indirectamente desde catálogos PostgreSQL.

## 2. Migraciones y drift

- Repo: 50 archivos SQL de migración.
- Remoto: 31 versiones aplicadas, consecutivas hasta `20261003181310_reconcile_is_admin_users_bounds.sql`.
- Pendientes en remoto: las 19 migraciones locales desde `20261004120000_provider_identity_and_draft_reuse.sql` hasta `20261005004000_revoke_anon_admin_rpc.sql`.
- En particular, `20261005000000_contact_messages.sql` y `20261005004000_revoke_anon_admin_rpc.sql` no están registradas como aplicadas.
- Remoto no tiene `public.contact_messages`, `public.public_contact_channels()`, `public.admin_set_contact_message_status(...)` ni la tabla/campos de configuración que introduce `20261005002000_contact_and_notification_settings.sql`.
- La tabla remota `system_settings` contiene las claves preexistentes `admin_whatsapp_number`, `whatsapp_notifications_enabled`, `whatsapp_notify_new_business`, `whatsapp_notify_business_changes` y `whatsapp_notify_user_reports`. No se leyeron valores ni se escribieron cambios.
- La tabla remota `audit_logs` tiene actor, action, entidad, old/new data y fecha. `public.admin_search_users(...)` existe, está declarada `SECURITY DEFINER`, fija `search_path=pg_catalog` y no concede EXECUTE a `anon`.

### Drift local esperado vs remoto observado

| Severidad | Local espera | Remoto tiene | Impacto / acción recomendada |
|---|---|---|---|
| CRÍTICO | `contact_messages`, políticas/RPC de contacto y Edge Function `submit-contact` | No existe la tabla/RPC y hay cero Edge Functions desplegadas | No hay forma segura de validar envío remoto. Revisar todas las migraciones pendientes y desplegar la función solo después de resolver el drift y preparar QA controlado. |
| CRÍTICO | `admin-user` para crear/invitar usuarios y administrar cuentas | Cero Edge Functions desplegadas; las RPC de rol/eliminación de migraciones recientes no están registradas | No se pudo validar CRUD remoto ni creación de administrador. No usar RPC antiguas como sustituto del endpoint. |
| CRÍTICO | RPC administrativas sin EXECUTE para `anon` tras `20261005004000` | Varias funciones `admin_*` SECURITY DEFINER tienen `anon_exec=true`; por ejemplo `admin_list_users`, `admin_update_whatsapp_settings` y funciones de revisión/analítica | Aunque las funciones inspeccionadas comprueban el rol en su cuerpo, su grant anon es excesivo. Aplicar el revoke tras revisar el conjunto ordenado de migraciones y probar roles. |
| IMPORTANTE | Todas las migraciones 3.25.1/3.25.2 registradas | Solo 31/50; están pendientes las 19 | Hay drift amplio en identidad de provider, cuentas suspendidas, auditoría, roles, preferencias, settings y contacto. No ejecutar push masivo a ciegas. Comparar SQL uno por uno contra catálogos/efectos existentes. |
| IMPORTANTE | Las cuatro columnas de Home reproducibles desde DB reset local | Las cuatro columnas existen con defaults productivos y hay índice `idx_businesses_featured`; ninguna migración local crea las columnas en `businesses` | Situación A parcial. La base local limpia carece de parte del modelo que producción sí tiene. Añadir una migración local explícita/idempotente con los defaults observados, después de validar restricciones e índices semánticos; no cambiar frontend ni inventar columnas remotas. |
| IMPORTANTE | Configuración de canales/email/WhatsApp y eventos de notificación recientes | Solo claves WhatsApp antiguas; no existen claves `support_email`, `support_whatsapp` ni `notify_contact_message` | Los ajustes nuevos no están disponibles para UI/funciones remotas. Preservar valores actuales y revisar `ON CONFLICT`/auditoría antes de migrar. |
| MENOR | Historial de migración totalmente reconciliado | Tabla remota de migraciones termina en 20261003181310 pese a objetos/campos presentes que no tienen una migración local de origen identificable | Investigar si hubo cambios manuales u otro repo antes de reconciliar historial; no marcar versiones como aplicadas manualmente. |

## 3. Home y `businesses`

Consultas a `information_schema.columns` confirman:

| Campo | Remoto | Default remoto | Migración local que lo crea |
|---|---|---|---|
| `is_featured` | Sí, boolean NOT NULL | `false` | No encontrada |
| `accepts_requests` | Sí, boolean NOT NULL | `true` | No encontrada |
| `rating_avg` | Sí, numeric NOT NULL | `0` | No encontrada |
| `review_count` | Sí, integer NOT NULL | `0` | No encontrada |

También se encontró `idx_businesses_featured` en producción. Las referencias a estos nombres en migraciones locales aparecen como columnas devueltas por funciones de búsqueda, no como definición de tabla. Con los datos observados no hay evidencia para cambiar el query Flutter ni renombrar campos: el origen correcto es agregar al historial del repo la migración de esquema faltante, tras contrastar constraints/índices y semántica con producción. No se hizo esa modificación en esta fase porque el proyecto ya tiene 19 migraciones pendientes y aún no existe un diff de aplicación seguro para el conjunto.

## 4. RLS, policies y RPC

- RLS está habilitada en `businesses`, `profiles`, `notifications`, `service_requests`, `lodging_bookings`, `gastronomy_table_reservations`, `system_settings` y `audit_logs`.
- `businesses` tiene lectura pública limitada por publicación, ownership o admin; además hay políticas de escritura de propietarios/proveedores y borrado restringido a owner/admin.
- `profiles` permite lectura/actualización del propio perfil o administrador.
- `notifications` limita lectura y actualización a `auth.uid() = user_id`.
- `service_requests` y tablas de reservas tienen policies de lectura/escritura por cliente/proveedor/miembro; no se ejecutaron pruebas de acceso usando tokens anon/authenticated, así que se consideran revisadas por catálogo, no probadas por API.
- `system_settings` tiene RLS habilitada; no se hizo intento de lectura/escritura como anon por falta de un token público obtenido de manera que no expusiera secretos en logs.
- No existe tabla `contact_messages`, por lo que no hay RLS/policy que validar allí.
- Encontradas funciones administrativas `SECURITY DEFINER` con `search_path` fijo `public, auth` o `pg_catalog`. En las consultadas no se observó `search_path` vacío o sin configurar entre las funciones admin sensibles descritas. La invocabilidad anon estática sí es excesiva como se describe arriba.
- `admin_search_users` tiene `search_path=pg_catalog`, guard de admin dentro de la función y `anon_exec=false`. `admin_list_users` comprueba `auth.uid()`, sesión anónima y rol admin en el cuerpo, pero tiene `anon_exec=true`.
- No se verificó por HTTP el comportamiento real de API/RLS; al faltar las Edge Functions y no contar con JWT de prueba, no se hicieron solicitudes de mutación.

## 5. Contacto y Edge Functions

- El código fuente local existe para `submit-contact` y valida el payload en el servidor; el endpoint no está desplegado.
- No hay `contact_messages`; por tanto no se puede comprobar inserción, timestamps, estado, notificación, auditoría ni rechazo de RLS mediante PostgREST.
- No se envió un mensaje a soporte ni se generaron notificaciones a administradores reales.
- El código local de `admin-user` requiere claves de servicio/anon tomadas de entorno; no se encontró ningún despliegue al que llamar.
- `notify-provider-review` tampoco está desplegada. No se inspeccionó una versión remota porque no hay ninguna.
- CORS y `verify_jwt` se revisaron únicamente en `supabase/config.toml` y fuentes locales; no aplican a una versión remota inexistente.

## 6. CRUD, settings y notificaciones

No se ejecutó ninguna acción con cuentas reales. No se listaron usuarios ni se leyeron PII de `auth.users`; no se cambió rol/estado, no se invitó ni eliminó ningún usuario. No hay cuenta administrativa de prueba autorizada ni Edge Function de administración desplegada.

Se comprobó por esquema que perfiles/notificaciones y tablas de reserva existen y tienen RLS. Las columnas de notificación incluyen `read_at`, `deep_link` y `metadata`; no se probaron filtros, contador, agrupación, navegación ni persistencia por UI en remoto. En configuración solo se listaron nombres de keys de `system_settings`; sus valores originales no fueron leídos ni modificados. El WhatsApp sigue siendo un flujo manual en el código local revisado; no se enviaron mensajes.

## 7. Auth, secretos y código cliente

- La lista de secretos gestionados por CLI devolvió cero entradas; los valores nunca se solicitaron ni imprimieron.
- Edge Functions remotas: cero; por tanto no hay versión ni configuración remota que auditar.
- En código cliente, la referencia a `SUPABASE_ANON_KEY` está en la configuración pública Flutter; no se encontró `service_role` en Flutter durante la revisión de referencias conocidas. `SUPABASE_SERVICE_ROLE_KEY` aparece solo en fuentes de Edge Functions del repo y se obtiene de entorno.
- La cuenta/Auth remota no se probó; no se usaron credenciales de producción.

## 8. Cambios, pruebas y acciones remotas

- Cambios aplicados en remoto: ninguno.
- Datos reales eliminados o modificados: ninguno.
- Secrets expuestos: ninguno.
- No se ejecutó `db push`, deploy/publicación de Edge Functions, commit ni push.
- No se probaron Home, contacto, notificaciones, admin ni provider flow contra UI remota autenticada, porque los endpoints no están desplegados y no se suministraron credenciales de QA. La consulta SQL confirmó que las columnas de Home existen en producción.
- No se ejecutaron suites Flutter/Deno como parte de esta auditoría remota; se conserva el baseline reportado por Fase 3.25.2 (Flutter 630/630, analyze/build/UTF-8/diff-check OK; Deno 2/2 y type-check OK).

## 9. Plan seguro recomendado

1. Comparar individualmente las 19 migraciones pendientes contra el catálogo remoto (columnas, constraints, índices, funciones, triggers, policies y grants), especialmente las transiciones de identidad, suspensión y settings que pueden afectar cuentas reales.
2. Añadir al repo una migración reproducible para las cuatro columnas existentes en producción y el índice destacado, con `IF NOT EXISTS`, defaults observados y pruebas de reset local. No desplegarla como sustituto de la revisión completa del drift.
3. Preparar y revisar una secuencia ordenada de migraciones y diff; resolver primero si objetos ya existentes proceden de cambios manuales o migraciones fuera del repo. No usar `migration repair` para ocultar diferencias.
4. Aplicar las migraciones remotas aprobadas en ventana controlada; comprobar en particular el revoke anon de RPC administrativas y las policies de contacto/settings.
5. Desplegar funciones tras verificar secretos/configuración de entorno. Después, usar una cuenta de QA y mensaje identificable que pueda resolverse/limpiarse con auditoría comprobada; no usar cuentas reales para CRUD.
6. Solo entonces completar smoke tests remotos de Home, contacto, admin, notificaciones, configuración y provider flow.

## 10. Cierre

El criterio de cierre no se cumple: el backend real no está alineado con el historial local y faltan las funciones requeridas para flujos críticos. Se confirmó que producción tiene las columnas Home y que el repo necesita una migración reproducible. La fase debe continuar después de preparar y revisar el plan exacto de migraciones; esta auditoría no autoriza un `db push` indiscriminado.

