# Fase 3.26 ? regresi?n general del estado actual

Fecha: 2026-10-07. Alcance: validaci?n local del repositorio tal como se encontr?. No se agregaron funcionalidades ni se redise??. No se consult? ni modific? Supabase remoto, no hubo `db push`, despliegues, cambios de Auth remoto, commit ni push.

## 1. Estado inicial

Antes de validar se ejecutaron `git status --short` y `git diff --stat`. El ?rbol ya conten?a un conjunto amplio de modificaciones y archivos sin seguimiento de las fases previas (Flutter, tests, SQL, migraciones, scripts, reportes y artefactos web). No se descart? ni revirti? trabajo preexistente. La salida ?ntegra corresponde al estado de trabajo del usuario; no se atribuye a esta fase.

Se leyeron `phase-3-25-8-codex-production-readiness.md`, `phase-3-25-9-codex-qa-recovery-and-secrets.md`, `phase-3-25-7-codex-remote-snapshot-dry-run.md` y `phase-3-25-6-codex-security-hardening.md`. No se continu? QA remoto.

## 2. Validaci?n base y Supabase

| Comprobaci?n | Resultado |
|---|---|
| Migraciones SQL actuales | **55** (`supabase/migrations/*.sql`) |
| `dart format .` | PASS ? 203 archivos, 0 cambios |
| `flutter analyze` | PASS ? sin issues. Una primera ejecuci?n concurrente con Flutter test tropez? con `.packages` ef?mero; la repetici?n secuencial pas?. |
| `flutter test` | PASS ? **630/630** |
| `scripts/check_text_encoding.ps1` | PASS ? UTF-8 estructural OK |
| `git diff --check` | PASS ? sin errores; Git reporta avisos informativos LF?CRLF |
| `flutter build web --release` | PASS ? build web completo |
| `npx supabase start` | BLOCKED ? no hay Docker Desktop/daemon disponible (`dockerDesktopLinuxEngine` pipe ausente) |
| `npx supabase db reset --local --no-seed` | BLOCKED por la misma ausencia de Docker; no se conect? a remoto |
| SQL suites / reset completo | NO EJECUTADAS ? requieren Supabase local/Docker |
| HTTP de Edge/API local | NO EJECUTADO ? requiere Supabase local y runtime de funciones |

## 3. Resultados por ?rea

| ?rea | Validaci?n disponible y resultado | L?mite actual |
|---|---|---|
| Home / businesses | Contrato/widget de Home incluido en Flutter suite; contrato dedicado `phase_3_25_4_home_contract.mjs` est? presente. No se reprodujo aqu? una consulta HTTP/PostgREST ni se verific? 42703 en runtime. | Sin Supabase local. |
| Explorar / negocios | Suite Flutter completa incluye rutas y layouts responsive; no se observ? fallo. | B?squeda, filtros y lecturas reales no se probaron contra backend. |
| Auth | Tests widget/routing existentes incluidos en 630/630. | Sin signup/signin/signout contra Auth real ni sesi?n persistente de backend. |
| Cuenta | Widgets/rutas incluidas en suite. | Lectura/edici?n de profile en backend no verificada. |
| Provider | Tests de route guards, registro y responsive incluidos. | `/provider/join` no se ejecut? conectado a Auth/DB. |
| Legales | Tests de navegaci?n legal incluidos en suite, incluida preservaci?n de history/return route seg?n fixtures. | No hubo smoke browser real. |
| Contacto | Widgets/validaci?n local incluidos en suite; Deno tests compartidos pasaron 4/4. | Insert, RLS, auditor?a/notificaci?n de la Edge real requieren Supabase local. |
| Notificaciones | Widgets de lista/estado y preferencias incluidos en suite. | Persistencia tras refresh/backend no verificada. |
| Solicitudes | Tests Flutter de actividad/rutas/contratos incluidos y pasaron. | Transiciones y RLS reales no ejecutadas. |
| Reservas | Cobertura widget/contrato existente incluida en suite. | Creaci?n/listado sobre DB local no verificados en esta fase. |
| Admin / usuarios | Suites Flutter de gates, CRUD y responsive pasaron. | Invitaci?n, cambio rol, suspensi?n, reactivaci?n y soft delete HTTP no ejecutados. |
| Configuraci?n | Tests de settings incluidos en suite. | Persistencia real, WhatsApp manual y canales requieren DB/Edge local. |
| Roles / SuperAdmin | Tests unitarios/widget existentes pasaron dentro de 630; suites SQL de bootstrap/seguridad est?n presentes. | Asserts RLS/RPC y bootstrap real de Postgres no se ejecutaron por falta de Docker. No se cre? ning?n SuperAdmin. |
| Security / RLS | Deno CORS/contact validation **4/4**; type-check de las 3 funciones PASS. | SQL de grants, RPC, TRUNCATE, RLS, ownership y SECURITY DEFINER no se pudo correr sin DB local. |
| Edge Functions | `deno check --node-modules-dir=none` en `submit-contact`, `admin-user`, `notify-provider-review`: PASS. | No hubo ejecuci?n HTTP local. |

No se encontr? un bug reproducible durante las validaciones ejecutables, por lo que no se hicieron correcciones de producto/c?digo. Los contratos faltantes por backend no se reportan como aprobados.

## 4. Responsive y navegador

La suite Flutter completa pas? e incluye pruebas de layout para los cuatro anchos requeridos: 390, 768, 1024 y 1440 px, adem?s de otros tama?os. Las pantallas cubiertas incluyen ?reas de acceso, legales, contacto, notificaciones, usuarios/admin, configuraci?n y flujo provider. Es validaci?n widget, no inspecci?n visual manual de todas las p?ginas.

El navegador automatizado no estuvo disponible: la inicializaci?n de la superficie CUA termin? con `trusted Node process exited unexpectedly; kernel reset`. No se afirma un smoke test real, inspecci?n de consola del navegador, solicitudes HTTP ni ausencia de errores visuales runtime. Los tests widget s? completaron sin fallos Flutter.

## 5. Errores corregidos y pendientes reales

- Errores corregidos en esta fase: **ninguno**; no se observ? una regresi?n reproducible en las comprobaciones que s? pudieron ejecutarse.
- Pendiente ambiental: instalar/iniciar Docker Desktop con motor Linux y repetir `supabase start`, reset 55/55, SQL/security/bootstrap suites, HTTP local, RLS e integraci?n real Edge.
- Pendiente de validaci?n visual: repetir smoke en navegador y registrar consola/4xx/5xx/overflow cuando exista una superficie disponible.
- Las llamadas remotas de Auth/PostgREST y todas las acciones reales de admin/configuraci?n quedaron fuera de verificaci?n; los tests widget no las sustituyen.

## 6. Matriz resumida de roles

Esta fase no pudo revalidar las pol?ticas en Postgres. La matriz siguiente refleja el contrato definido y ya documentado en la fase 3.25.6, no una nueva aprobaci?n runtime:

| Rol | Acceso esperado seg?n contrato | Verificaci?n nueva de RLS/RPC |
|---|---|---|
| ANON | Lectura p?blica expl?cita y contacto v?a Edge; sin administraci?n ni TRUNCATE | Bloqueada por falta de DB local |
| CUSTOMER | Datos/acciones propios; sin acceso global | Bloqueada por falta de DB local |
| PROVIDER | Operaciones comerciales permitidas por ownership/membership; sin acceso global | Bloqueada por falta de DB local |
| OWNER | Solo negocio propio y memberships asociadas | Bloqueada por falta de DB local |
| TENANT ADMIN | Solo scope tenant; sin consola/RPC global SuperAdmin | Bloqueada por falta de DB local |
| SUPER ADMIN | Operaciones globales solo con sesi?n expl?cita y auditada; proteger ?ltimo SuperAdmin | Bloqueada por falta de DB local |

## 7. Resultado

**ESTADO ACTUAL: ESTABLE CON PENDIENTES.** Las validaciones Flutter/Dart, web build, encoding, diff check, Deno tests y type-check pasaron. La regresi?n de backend local, RLS/RPC, HTTP Edge real y smoke browser no puede considerarse cerrada porque Docker y el navegador automatizado no estuvieron disponibles. No se toc? Supabase remoto.


## ESTADO CONTRA SUPABASE REAL

Auditor?a read-only ejecutada el 2026-10-07 contra el proyecto enlazado **RancoConecta**, confirmado por el hostname observado desde la aplicaci?n publicada. No se aplicaron migraciones ni cambios de esquema/datos; no se despleg? ninguna funci?n. El `flutter build web --release` de esta fase solo construy? localmente.

### Baseline de c?digo repetido

- `dart format .`: PASS, 203 archivos, 0 cambios.
- `flutter analyze`: PASS, sin issues.
- `flutter test`: PASS, **630/630**.
- `scripts/check_text_encoding.ps1`: PASS.
- `git diff --check`: PASS; solo avisos Git LF?CRLF.
- `flutter build web --release`: PASS.

### Inventario remoto

- Historial de migraciones: **31 aplicadas**, ?ltimo timestamp `20261003181310`; repo: **55**, quedan **24 pendientes** (3.25.x). Se us? solo `supabase migration list --linked`.
- Edge Functions desplegadas: **0**. El listado remoto no contiene `submit-contact`, `admin-user` ni `notify-provider-review`.
- Tablas p?blicas: **42/42** tienen RLS habilitado; **0/42** tienen FORCE ROW LEVEL SECURITY.
- Existen las columnas de Home `is_featured`, `accepts_requests`, `rating_avg`, `review_count`.
- No existen `contact_messages`, `super_admin_sessions` ni `provider_role_migration_candidates` en el schema actual.
- `system_settings`, `notifications`, `profiles`, `business_members` y `businesses` s? existen.

### Tabla funcional

| FUNCIONALIDAD | ESTADO | BACKEND | OBSERVACI?N |
|---|---|---|---|
| Home p?blica | FUNCIONA EN PRODUCCI?N | Supabase remoto | Home se renderiz? en browser. Lecturas PostgREST de `categories`, `locations`, `businesses` y RPC de contadores respondieron 200. Sin 42703 ni 4xx/5xx observado. |
| Campos Home | FUNCIONA EN PRODUCCI?N | Supabase remoto | Cuatro columnas requeridas existen; el request de negocios respondi? 200. Conteo agregado: 12 negocios, 6 publicados, 5 `is_featured=true`, 10 `accepts_requests=true`, 12 con rating y 5 con rese?as. |
| Im?genes/cards Home | FUNCIONA EN PRODUCCI?N | Storage remoto | Imagen p?blica de negocio carg? con 200; cards destacadas visibles. |
| Explorar/listado | FUNCIONA EN PRODUCCI?N | Supabase remoto | Lista visible con 6 publicados; lecturas de `businesses` y `lodging_details` respondieron 200. |
| Buscar/filtros por categor?a | BUG REAL | Supabase remoto + filtro frontend | Seleccionar ?Alojamiento? dio estado vac?o. Los seis publicados tienen `primary_category_id IS NULL`; el join de los dos publicados `lodging` tampoco encuentra categor?a primaria. El filtro actual usa `primary_category_id`, por lo que la categor?a no encuentra esos negocios. No se corrigieron datos productivos. |
| Detalle negocio | FUNCIONA EN PRODUCCI?N | Supabase remoto | Se abri? un detalle publicado; requests de `businesses`, `lodging_details`, `reviews` e im?genes respondieron 200; anal?tica autom?tica respondi? 204. La apertura produjo **un evento de anal?tica no cr?tico** mediante `record_business_analytics_event`; ninguna otra mutaci?n se ejecut?. |
| Auth/login/logout/sesi?n | NO PROBABLE DE FORMA SEGURA EN PRODUCCI?N | Supabase Auth | No se proporcionaron credenciales de una cuenta de prueba autorizada. No se intent? login, signup, logout ni recuperaci?n. La navegaci?n p?blica se prob? sin autenticaci?n. |
| Cuenta/perfil/rol | NO PROBABLE DE FORMA SEGURA EN PRODUCCI?N | Supabase Auth/PostgREST | Requiere cuenta autorizada; no se ley? ni modific? ning?n perfil personal. |
| Provider join | FUNCIONA EN PRODUCCI?N (pantalla p?blica) | Frontend publicado | `/provider/join` renderiza los pasos y CTA. No se inici? alta ni se crearon datos; flujo autenticado no probado. |
| T?rminos y privacidad | FUNCIONA EN PRODUCCI?N | Frontend publicado | Ambas rutas legales renderizaron contenido y navegaci?n ?Volver?. Sin escritura backend. |
| Contacto | IMPLEMENTADA, PENDIENTE DE EDGE DEPLOY/MIGRACI?N | Edge Function + tabla ausentes | Contact route renderiza formulario, pero muestra ?Canal de contacto pendiente de habilitaci?n? y bot?n deshabilitado. Inventario remoto: 0 Edge Functions; `contact_messages` no existe. No se envi? mensaje. No es bug del frontend. |
| Notificaciones | IMPLEMENTADA EN REPO, PENDIENTE DE MIGRACI?N | Supabase remoto | Tabla `notifications` existe y `unread_notification_count` respondi? 200 en modo p?blico. No se probaron lista/read/persistencia sin usuario de prueba; migraci?n de destinatarios/actividad a?n pendiente. |
| Admin/usuarios | IMPLEMENTADA EN REPO, PENDIENTE DE MIGRACI?N/EDGE DEPLOY | Supabase remoto | No se us? sesi?n admin de producci?n ni se consultaron perfiles. Acciones 3.25.x no se probaron: faltan migraciones y Edge `admin-user`. Adem?s se detect? un bloqueo de seguridad abajo. |
| Configuraci?n | IMPLEMENTADA EN REPO, PENDIENTE DE MIGRACI?N | Supabase remoto | Existe `system_settings`; no se leyeron valores ni se escribi? configuraci?n. Defaults/auditor?a recientes dependen de migraciones pendientes. |
| Admin RPC anon | BUG REAL / BLOQUEO DE SEGURIDAD | Grants SQL remotos | **12** RPC `admin_* SECURITY DEFINER` muestran `has_function_privilege('anon', ..., 'EXECUTE') = true`: analytics summary, business review detail/queue/stats/get, list users, publish, reject, request changes, restore, suspend, update WhatsApp settings. No se invoc? ninguna. |
| `TRUNCATE` anon/authenticated | BUG REAL / BLOQUEO DE SEGURIDAD | Grants SQL remotos | Consulta read-only confirm? en las **42/42** tablas p?blicas `TRUNCATE=true` tanto para `anon` como para `authenticated`. No se ejecut? `TRUNCATE` ni ninguna escritura. Esto contradice la suite/hardening local; RLS habilitado no sustituye revocar el privilegio de tabla. |
| Ownership y guard global | IMPLEMENTADA EN REPO, PENDIENTE DE MIGRACI?N | Supabase remoto | La transici?n `owner_id ? profiles(id) ON DELETE RESTRICT`, sesi?n SuperAdmin y bootstrap incluidos en migraciones posteriores no existen a?n en el remoto. No se prob? ni se cre? SuperAdmin. |

### Navegador, red y l?mites

La automatizaci?n Playwright funcion? usando Microsoft Edge instalado. Se recorrieron Home, Explorar, un detalle, T?rminos, Privacidad, Contacto y Provider Join. Home/listado/detalle/Storage respondieron 200; el evento de anal?tica mencionado respondi? 204. En consola: **0 errores y 0 warnings** durante la captura consultada. No se observ? request PostgREST 4xx/5xx ni error 42703. Contacto no se envi?; no se ingres? a sesiones Auth/Admin ni se hicieron acciones destructivas. `provider/join` se inspeccion? sin iniciar publicaci?n.

Un query de auditor?a propio inicialmente pregunt? por `categories.is_active`, columna que no existe en el schema remoto (Postgres 42703); se corrigi? a `categories.active`. Este fue error del query de auditor?a, no de la aplicaci?n ni de PostgREST.

### Clasificaci?n final de producci?n

**ESTADO ACTUAL DE PRODUCCI?N: BLOQUEADO.** Home p?blica, listado, detalle, im?genes y legales funcionan en las rutas probadas. Contacto y acciones nuevas de Admin est?n pendientes de migraci?n/deploy; Auth/Cuenta/Admin requieren cuenta de prueba autorizada para pruebas seguras. Tambi?n hay un defecto real de datos que rompe el filtro por categor?a y, de forma prioritaria, grants remotos excesivos: 12 RPC administrativas ejecutables por `anon` y `TRUNCATE` concedido a ambos roles API en las 42 tablas p?blicas. Esta fase solo registr? evidencia; no hizo correcciones remotas ni locales.
