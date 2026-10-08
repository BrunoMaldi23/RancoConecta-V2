# Fase 3.25.2 — QA de integración local Supabase

Fecha: 2026-10-05. Alcance exclusivamente local; no deploy, DB push, commit ni push.

## 1. Estado inicial

- Se revisaron `git status`, `git diff --stat`, los archivos sin seguimiento y los reportes de 3.25 Claude y 3.25.1 Codex.
- El árbol ya contenía cambios staged/unstaged y archivos sin seguimiento de las fases previas (incluidos `vercel_output`, configuración, migraciones, funciones y pruebas). Se conservaron; no se atribuyen a esta fase.
- La migración 3.25.1 inspeccionada fue `20261005000000_contact_messages.sql`. También están presentes las migraciones `20261005001000`, `20261005002000` y `20261005003000`.
- Baseline reportado por 3.25.1: 630/630 tests Flutter, analyze, UTF-8, diff check, build web y 2 tests Deno; sin validación real de Supabase.
- `dart format .`: 203 archivos inspeccionados, 0 cambios.

## 2. Docker y Supabase CLI

- Docker CLI: 29.7.2, contexto `desktop-linux`.
- El daemon no estaba disponible: no existe el pipe `//./pipe/dockerDesktopLinuxEngine`.
- Supabase CLI local del proyecto: 2.116.0 mediante `npx supabase`.
- `npx supabase start` terminó con `LegacyDockerLifecycleInspectError` al intentar inspeccionar la salud de contenedores porque no pudo conectar al daemon.
- No se levantó Supabase local; por ello `supabase db reset` y las pruebas SQL/HTTP locales no pudieron ejecutarse. No se intentó usar la instancia enlazada/remota.

## 3. Migraciones y esquema

- Hay 49 archivos de migración SQL en `supabase/migrations`.
- No se aplicó ninguna migración en esta ejecución; no es posible afirmar que la cadena completa desde cero ni la nueva migración compilen/apliquen correctamente.
- Revisión estática de `20261005000000_contact_messages.sql`: tabla con validaciones CHECK, estado inicial `new`, timestamp `now()`, FK de `user_id` con `ON DELETE SET NULL`, índice por estado/fecha, RLS habilitado, policy de lectura administrativa, RPC de cambio de estado auditada y trigger para notificaciones a administradores activos.
- La revisión estática no sustituye las pruebas de privilegios efectivos, RLS, ejecución de funciones, triggers ni auditoría sobre PostgreSQL local.

## 4. Contacto, seguridad y Edge Functions

- No se ejecutó `phase_3_25_2_local_api.mjs`; sus escenarios requieren Supabase local y Docker. Por tanto no se verificaron solicitudes HTTP reales, creación de contactos, asociación de usuario, RLS efectiva ni llamadas Edge locales.
- No se comprobó envío anónimo/autenticado ni rechazos del servidor, CORS, métodos HTTP o respuestas con JWT admin/usuario.
- Pruebas unitarias Deno del validador: 2/2 pasaron.
- `deno check --node-modules-dir=none` pasó para `submit-contact/index.ts` y `admin-user/index.ts`.
- Búsqueda de `service_role`, `SERVICE_ROLE_KEY`, `SUPABASE_SERVICE_ROLE` y `admin_secret` en `lib`, `web` y `test`: sin coincidencias.

## 5. Funciones administrativas, relaciones y auditoría

- No verificados contra DB local: invitación/creación admin, cambio de rol, suspensión/reactivación, protecciones de último administrador, eliminación lógica, relaciones/FKs, búsqueda, permisos por rol ni registros de auditoría.
- El archivo `supabase/tests/phase_3_25_2_local_integration.sql` contiene comprobaciones transaccionales para parte de estos contratos, pero no se ejecutó.
- Sin backend levantado no se verificaron Auth, perfiles, negocios, solicitudes, notificaciones, reservas, destinatarios ni persistencia.

## 6. Navegación legal y QA autenticado

- No se ejecutó navegador Flutter Web con Supabase ni sesión local. Los casos A–F de navegación legal, origen de retorno y rechazo de URL externa siguen sin validación de navegador en esta fase.
- Tampoco se realizó QA visual autenticado de Notificaciones, Cuenta, Admin/Usuarios, detalle, roles, suspensión/reactivación o Configuración.
- Los contratos y pruebas Flutter de navegación permanecen cubiertos por la suite automatizada indicada abajo; esto no equivale a QA de navegador autenticado.

## 7. Configuración, notificaciones y WhatsApp

- No se verificó persistencia por RPC/tabla, permisos, preferencias, deduplicación, destinatarios ni refresco sobre DB local.
- No se enviaron mensajes WhatsApp. El modo de envío manual no se probó operativamente en esta ejecución.

## 8. Validación ejecutada

- `dart format .`: OK, 0 archivos modificados.
- `flutter analyze`: OK, sin issues.
- `flutter test`: OK, **630/630**. La primera invocación falló al intentar borrar un directorio temporal de iOS mientras Flutter compartía operaciones; se repitió secuencialmente tras terminar el build y pasó completa.
- `scripts/check_text_encoding.ps1`: OK.
- `git diff --check`: código 0; Git mostró avisos de conversión LF/CRLF en archivos ya modificados.
- `flutter build web --release`: OK.
- Deno: 2/2 tests OK.
- Type-check Edge Functions: OK.
- Supabase start, DB reset, SQL local, HTTP local, QA navegador autenticado: no ejecutados por daemon Docker ausente.

## 9. Bugs encontrados/corregidos

- No se confirmó ni corrigió ningún bug funcional del repositorio: no fue posible ejecutar el backend local necesario para reproducir los flujos.
- La primera ejecución concurrente de `flutter test` chocó con el acceso al directorio temporal de iOS; la repetición secuencial pasó 630/630 y no requirió cambios de código.

## 10. Pendientes para cerrar la fase antes de deploy

1. Iniciar Docker Desktop/daemon y repetir `npx supabase start`.
2. Ejecutar `npx supabase db reset` desde una base limpia y confirmar las 49 migraciones en orden.
3. Ejecutar `supabase/tests/phase_3_25_2_local_integration.sql` y `supabase/tests/phase_3_25_2_local_api.mjs`; revisar y corregir cualquier fallo real.
4. Completar comprobaciones de RLS/permisos, contacto anónimo y autenticado, operaciones admin, último administrador, eliminación lógica y relaciones.
5. Completar persistencia y permisos de notificaciones/configuración/WhatsApp y revisar auditoría.
6. Completar navegación legal y smoke tests del navegador autenticado con datos locales, más la regresión indicada.

**Estado de fase: bloqueada por entorno y no cerrada.** La aceptación requiere demostrar un reset limpio y flujos críticos reales; las validaciones Flutter/Deno verdes por sí solas no satisfacen ese criterio.

## 11. Acciones remotas

No se hizo deploy, publicación de Edge Functions, DB push remoto, commit, push ni acceso de escritura a producción.

---

## Reanudación de QA — 2026-10-05

### Docker y Supabase local

- Docker Desktop **4.88.1**, Docker Engine **29.7.2**, contexto `desktop-linux`; `docker version` y `docker info` respondieron correctamente.
- Supabase CLI del repo: **2.116.0**. `npx supabase start` levantó los servicios locales; `npx supabase functions serve` inició `admin-user`, `submit-contact` y `notify-provider-review` en el runtime local Deno 2.1.4.
- `npx supabase db reset` reconstruyó la base desde cero y aplicó las **50/50 migraciones** hasta `20261005004000_revoke_anon_admin_rpc.sql`, además de `supabase/seed.sql`. El último reset terminó con código 0.
- Se hicieron resets repetidos al aislar un escenario de “último admin” que requiere base limpia. Tras el último reset, SQL y HTTP integration terminaron ambos con código 0.

### Contacto, esquema y RLS

- `contact_messages` quedó con 8 columnas: UUID autogenerado, nombre, correo, motivo, mensaje, `user_id` opcional, `status` con default `new` y `created_at` con default `now()`.
- Se comprobaron PK, 5 CHECK, FK a `profiles(id) ON DELETE SET NULL`, índice único de PK e índice `(status, created_at DESC)`, RLS activa, una policy de lectura administrativa y trigger `notify_admins_on_contact_message`.
- Privilegios efectivos: `anon` no tiene lectura ni escritura; `authenticated` solo tiene SELECT sujeto a RLS. Usuario normal recibió cero filas y no pudo insertar, actualizar ni borrar; el admin pudo leer.
- El formulario Flutter anónimo se envió en navegador: mostró el banner de éxito. La fila real quedó como `new`, anónima, con timestamp y una sola copia. El HTTP suite repitió la prueba con usuario autenticado y verificó la asociación `user_id`.
- La Edge Function rechazó nombre/campos requeridos vacíos, email inválido, motivo desconocido, mensaje vacío o >4000, body >10 KB y propiedades inesperadas. GET devolvió 405; OPTIONS devolvió 200 con CORS `*`; los casos válidos anónimo y autenticado devolvieron 201.

### Administradores, privilegios y eliminación lógica

- HTTP local verificó invitación Auth y perfil admin activo, petición sin JWT (401), usuario normal (403), método incorrecto (405) y payload inválido (400). El CRUD de rol, suspensión y reactivación persistió; el intento sin permiso falló.
- Se verificaron autoeliminación/autosuspensión y cambio o suspensión del último admin contra SQL/RPC; las guardas ocurrieron en servidor. El usuario eliminado dejó de aparecer en búsqueda activa.
- El caso de eliminación incluyó negocio de servicio, negocio de alojamiento, solicitud, reserva de alojamiento, notificación y contacto asociado. Tras borrar lógicamente, se conservaron negocio, solicitud, reserva y notificación; el perfil permaneció anonimizado con estado `deleted`, Auth quedó en soft-delete (`deleted_at` presente) y la auditoría permaneció.
- Contacto mantiene `ON DELETE SET NULL`; FKs de negocio y solicitudes usan RESTRICT. La reserva conserva sus referencias porque Auth se soft-delete y el perfil no se borra.
- La auditoría se comprobó con actor, entidad objetivo, acción y fecha. Para admin creado/rol/suspensión/reactivación, metadata solo incluyó el campo de rol o estado. La suite verificó también eliminación lógica y ajustes administrativos.
- Se encontró que RPC administrativas antiguas `SECURITY DEFINER` aún tenían permiso EXECUTE efectivo para `anon`, aunque sus cuerpos rechazaban el acceso. Se añadió `20261005004000_revoke_anon_admin_rpc.sql`, que revoca permisos `PUBLIC`/`anon` de esas funciones y conserva los grants autenticados. La comprobación SQL y llamadas anon a RPC admin confirmaron **0 funciones admin SECURITY DEFINER ejecutables por anon**.
- Todas las funciones `SECURITY DEFINER` de `public` tienen `search_path`; no se encontró ninguna sin él. Las funciones nuevas usan `pg_catalog`. Las antiguas que usan `public, auth` no quedan expuestas a creación de objetos: `anon` y `authenticated` no tienen `CREATE` sobre `public`.

### Notificaciones y configuración

- HTTP local verificó listado, contador, lectura individual y total, persistencia, destinatarios y preferencias. Evento de negocio pendiente/modificado llegó a admins y no se duplicó al repetir el mismo estado.
- Un nuevo contacto generó avisos para los dos admins activos con preferencia habilitada. En Flutter Web se vio `Sistema`, grupo `Hoy`, 1 sin leer/1 total; al marcarlo leído quedó 0 sin leer y se mantuvo leído tras recargar.
- RPC verificó persistencia de correo/WhatsApp de contacto, preferencias de eventos y configuración de WhatsApp tras leer de nuevo; un usuario normal no pudo modificarlas. La UI autenticada mostró el número persistido y **Modo: Envío manual**. No se envió ningún WhatsApp.

### Navegación legal y QA autenticado

- Flutter Web local probó `/sign-in → Privacidad → Términos → Volver = /sign-in` y `/account → Términos → Contacto → Volver = /account` con sesión admin local. También probó el recorrido legal que vuelve a `/` y un `returnTo=https://example.com`, que fue rechazado y volvió a Home. Las páginas legales cambiaron entre sí sin loop.
- Con sesión Auth local se inspeccionaron Admin/Usuarios, detalle, invitación desde UI, cambio de rol y refresco, suspensión/reactivación y Configuración. La UI reflejó los estados persistidos. No se usaron cuentas de producción.

### Validación final y hallazgo de regresión

- `dart format .`: 203 archivos, 0 cambios.
- `flutter analyze`: sin issues.
- `flutter test`: **630/630**.
- Encoding UTF-8: OK. `git diff --check`: código 0; Git conserva avisos LF/CRLF preexistentes.
- `flutter build web --release`: OK.
- Deno: **2/2**. Type-check de `submit-contact` y `admin-user`: OK.
- Se comprobó en navegador el Home y apareció un defecto previo a esta fase: `BusinessRepository._select` pide `is_featured`, `accepts_requests`, `rating_avg` y `review_count`, pero ninguna de esas columnas existe en `public.businesses` después del reset limpio. PostgREST devuelve `42703` y Home muestra el estado de error de destacados. No se añadió una funcionalidad o columna fuera del alcance; queda como **bloqueador independiente que debe corregirse antes de deploy**.
- No se enviaron mensajes externos ni se configuró SMTP de producción. Invitaciones y mensajes de contacto se ejecutaron solo contra Auth/Edge local.

### Estado actualizado

La aceptación local de la fase queda **cumplida para las migraciones y flujos 3.25.1**: stack local levantado, reconstrucción limpia de las 50 migraciones, SQL y Edge HTTP integrados, CRUD/permisos, eliminación lógica con reserva, RLS, settings y navegación legal comprobados. El problema de columnas de Home es un hallazgo adicional que mantiene el repo sin aprobación para deploy hasta resolverse.

No hubo deploy, publicación de Edge Functions, DB push remoto, commit, push ni acceso de escritura a producción.
