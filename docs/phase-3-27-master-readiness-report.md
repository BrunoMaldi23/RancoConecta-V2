# Ranco Conecta 3.26 / 3.27 — estado maestro de preparación

Fecha de auditoría: 2026-10-07. Proyecto Supabase real: **RancoConecta**, ref `exdaagbftotnnoyetcpg`. Solo se consultaron catálogos/datos agregados en la auditoría general. No se modificaron datos críticos, roles, Auth, esquema ni configuración de producción durante esta fase maestra; no se desplegó frontend ni Edge Functions. El hotfix grants-only registrado abajo se aplicó antes de recibirse la instrucción maestra de no escribir producción.

## 1. Resumen ejecutivo

El código actual supera validación Flutter, análisis, Deno y build release. La Home, Explore, imágenes, detalle, legales, login y Provider Join se abrieron en navegador real contra el sitio publicado sin errores de consola. El backend Supabase local completo no pudo reiniciarse porque el daemon Docker no está activo; los contratos SQL de grants sí pasaron en PostgreSQL 16 aislado.

El hotfix grants-only `20261007160000` ya fue aplicado a producción y comprobado en catálogo: TRUNCATE anónimo 42→0, TRUNCATE authenticated 42→0 y RPC administrativas anónimas 12→0. Producción sigue **parcialmente endurecida**: `current_user_is_admin()` remoto aún trata `admin` tenant como admin global, las 12 RPC admin siguen ejecutables por cualquier `authenticated`, y hay tres helpers SECURITY DEFINER internos expuestos a `PUBLIC`/anon que tienen migración local preparada pero no aplicada.

El remoto carece de `contact_messages`, `super_admin_sessions` y de las tres Edge Functions del repo. Hay 24 migraciones funcionales pendientes; ninguna fue aplicada. Los 6 negocios publicados carecen de categoría principal; tres tienen una categoría objetiva derivable de todos sus servicios activos y tres requieren revisión manual.

Hay bloqueos técnicos de autorización global, helpers SECURITY DEFINER remotos, backfill de datos, restore de QA no comprobado y funciones/secrets no desplegados. Este informe no autoriza ni ejecuta un apply funcional posterior.

## 2. Recuperación del repositorio y procedencia

Al iniciar ya existían decenas de archivos modificados y cientos de archivos nuevos de fases previas, incluidos cambios Flutter, tests, SQL, Edge Functions y artefactos Vercel. Se preservaron sin revertirlos. No hay metadatos confiables en `git status` que permitan separar autoría de Claude/Codex; los reportes de fase y el status permiten clasificar cronológicamente, no atribuir autoría. Los cambios de aplicación existentes son preexistentes a la fase maestra.

Esta sesión añadió/revisó: la migración grants-only `20261007160000` (aplicada antes de la instrucción maestra); su rollback preparado; su contrato SQL; la migración local `20261007170000` y su contrato para helpers internos; allowlist CORS local explícita; scripts/docs de categorías; este reporte y el reporte corregido de 3.26.2A. Ningún otro cambio de código Flutter se hizo en esta sesión.

## 3. Baseline y pruebas

| Comando | Resultado |
|---|---|
| `dart format .` | PASS, 203 archivos, 0 cambios |
| `flutter analyze` | PASS, sin issues (68,2 s) |
| `flutter test` | PASS, 630/630 |
| `scripts/check_text_encoding.ps1` | PASS, UTF-8 estructural OK |
| `git diff --check` | PASS; warnings informativos LF→CRLF en archivos existentes |
| `flutter build web --release` | PASS, build web release generado |
| Deno | PASS, 4/4 pruebas CORS/contact validation; incluye orígenes locales añadidos |
| Edge type-check | PASS, las 3 funciones actuales |
| Hotfix SQL en PostgreSQL 16 aislado | PASS; contrato y reejecución idempotente |
| Helper-definer SQL en PostgreSQL 16 aislado | PASS; contrato de no ejecución directa |
| Category backfill preparado | PASS en fixture aislado; 3 updates elegibles y rollback dejó 0 cambios |
| `docker info` | Cliente disponible, daemon `dockerDesktopLinuxEngine` no disponible |
| `supabase db reset` / suites DB completas | NO EJECUTADAS; requieren Docker/Supabase local completo |

El test Flutter mostró algunos logs de estado `AdminErrorState: Supabase no está configurado` en fixtures; no produjeron fallos y la suite completó 630/630.

## 4. Inventario de migraciones y drift

- Migraciones locales: **57**, 57 timestamps únicos.
- Historial remoto: **32** aplicadas, incluida `20261007160000`; última anterior `20261003181310`.
- Pendientes: **25** = 24 funcionales de octubre 4–5 más `20261007170000_revoke_internal_definer_helpers.sql`.
- Las 24 versiones funcionales, en orden local, son: `20261004120000`, `20261004121000`, `20261004122000`, `20261004123000`, `20261004124000`, `20261004125000`, `20261004130000`, `20261004131000`, `20261004132000`, `20261004132500`, `20261004133000`, `20261004134000`, `20261004135000`, `20261004140000`, `20261004141000`, `20261005000000`, `20261005001000`, `20261005002000`, `20261005003000`, `20261005004000`, `20261005005000`, `20261005006000`, `20261005007000`, `20261005008000`.
- No ejecutar el lote sin adaptación: el plan 3.25.5 marca `20261004130000_suspended_session_gate.sql` para reemplazo por su impacto transversal en PostgREST/RLS/Storage; revisar `20261004132000_pre_request_execute_roles.sql` por solapamiento con 050030; 041330 puede reclasificar tres perfiles ambiguos y requiere conservarlos como customer salvo decisión humana explícita. El reemplazo del gate y el plan de esos perfiles no están terminados.
- El borrador más amplio `20261007150000` se retiró y nunca se ejecutó.
- No hay duplicados de timestamp reportados. `20261007160000` se ejecutó como SQL aislado y solo esa versión se registró; las otras 24 no se marcaron artificialmente.
- El reset limpio de las 57 migraciones no está verificado en esta sesión por falta de Docker. Los reportes 3.25.7/3.25.8 registran validación anterior de 55 migraciones en su entorno de QA/modelo.

Schema remoto read-only: 42 tablas `public` con RLS habilitada, 102 policies. Remoto tiene columnas Home `is_featured`, `accepts_requests`, `rating_avg`, `review_count` y `primary_category_id` (nullable). `contact_messages` y `super_admin_sessions` no existen. La clave foránea remota de `businesses.owner_id` apunta a `auth.users` con `ON DELETE CASCADE`; la migración local 050060 la reconcilia a `profiles(id) ON DELETE RESTRICT` tras comprobar huérfanos. La auditoría actual contó 0 owner huérfanos.

## 5. Estado de seguridad y permisos

### Producción después del hotfix 3.26.2A

| Control | Antes | Ahora |
|---|---:|---:|
| TRUNCATE `anon` | 42 | 0 |
| TRUNCATE `authenticated` | 42 | 0 |
| RPC admin SECURITY DEFINER ejecutables por `anon` | 12 | 0 |
| RPC admin ejecutables por `authenticated` | 12 | 12 |
| ACL directos `PUBLIC EXECUTE` en las 12 RPC admin | 9 | 0 |

La migración es [20261007160000_emergency_grants_only.sql](../supabase/migrations/20261007160000_emergency_grants_only.sql). Se verificó cada firma y el privilegio efectivo; no se cambió el cuerpo de funciones ni grants DML. Rollback exacto preparado (no ejecutado): [`scripts/rollback-phase-3-26-2a-grants-only.sql`](../scripts/rollback-phase-3-26-2a-grants-only.sql).

### Bloqueos de autorización

El helper remoto `current_user_is_admin()` verifica perfil activo con rol `admin` o `super_admin`; no requiere fila activa en `super_admin_sessions`. La tabla de sesión aún no existe remotamente. Conteos actuales: 1 `admin`, 0 `super_admin`. Por lo tanto:

**TENANT ADMIN GLOBAL AUTHORIZATION: STILL PRESENT — BLOQUEO DE SEGURIDAD PENDIENTE.** `authenticated` todavía puede ejecutar las 12 RPC admin y el helper remoto las autoriza para el perfil tenant `admin`.

Local esperado después de 050060: `is_super_admin()` valida perfil `super_admin` activo; `current_user_is_admin()` requiere sesión global explícita y vigente. La sesión inicia con propósito/expiración, deja auditoría y se cierra explícitamente. No se seleccionó ni creó ningún SuperAdmin real. El test `phase_3_25_8_bootstrap.sql` documenta y cubre 0→1, auditoría, segunda ejecución bloqueada, no auto-promoción admin/provider/customer y protección del último SuperAdmin en el reset local anterior; no se pudo repetir hoy sin Docker.

El modelo de aplicación distingue `ProfileRole.admin` de `ProfileRole.superAdmin`; `canAccessAdmin` solo permite SuperAdmin. Los permisos owner/manager son membresías de negocio, no privilegio global. La consola global queda bloqueada para tenant admin, provider y customer. No se halló una consola de administración tenant separada; esa capacidad queda pendiente de producto/dominio, no se soluciona otorgando acceso global.

Tres helpers SECURITY DEFINER internos aún aparecen ejecutables por anon/PUBLIC en producción: `record_business_review_event`, `notify_business_managers`, `sync_context_conversation_members`. Los dos primeros escriben auditoría/eventos y notificaciones sin guard de identidad en su cuerpo; el tercero sincroniza miembros de conversación sin guard en su cuerpo. La nueva migración local `20261007170000_revoke_internal_definer_helpers.sql` revoca `PUBLIC`, anon y authenticated solo sobre esas firmas; si service_role tenía EXECUTE efectivo antes, lo conserva mediante GRANT explícito. Contrato SQL y prueba modelada pasan. **No se aplicó remotamente.** La migración general local 050060 también contiene hardening más amplio de SECURITY DEFINER, y exige validar el lote completo en QA antes de producción.

Catálogo remoto: 79 funciones SECURITY DEFINER `public`; 0 sin `search_path` explícito. 54 continúan ejecutables por anon después de retirar las 12 RPC admin, muchas con guardas de identidad/alcance o usadas como helpers públicos; no se deben revocar globalmente sin revisar sus dependencias. Un filtro de DML encontró tres helpers internos anteriores y cinco funciones de trigger (`ensure_lodging_details`, triggers Auth/consent/rating), no invocables como RPC ordinarias. El contrato amplio local `phase_3_25_6_security.sql` revisa la allowlist de anon y permisos de tablas, pero no se repitió aquí sobre reset completo.

### Matriz conceptual de roles

| Recurso/acción | ANON | CUSTOMER | PROVIDER | OWNER / MANAGER | TENANT ADMIN (`admin`) | SUPER ADMIN |
|---|---|---|---|---|---|---|
| Catálogo y legales | Lectura pública publicada | Lectura pública | Lectura pública | Lectura pública | Lectura pública | Lectura pública |
| Perfil/consentimiento propio | No | Propio | Propio | Propio | Propio | Propio |
| Solicitudes/reservas/mensajes | No | Solo propias/creadas | Solo ámbito negocio asignado | Solo negocio propio/asignado | Solo si además es miembro autorizado | Global solo en sesión local explícita |
| Gestión negocio | No | No | Solo negocio asignado | Propio/miembro activo | No global; acceso por membresía | Según sesión global local |
| Consola global, usuarios, settings, auditoría | No | No | No | No | No local; remoto actual sí es riesgo | Requiere sesión SuperAdmin local |
| `contact_messages` directo | Sin escritura | Sin escritura | Sin escritura | Sin escritura | Lectura solo bajo política local | Lectura bajo política local |

En producción, las políticas basadas en `current_user_is_admin()`/`is_admin()` heredan todavía el acceso global de tenant admin; la matriz local prevista no es el comportamiento remoto actual.

## 6. Owner ID e integridad

La migración local 050060 valida primero que todos los `businesses.owner_id` tengan perfil, cambia FK a `profiles(id) ON DELETE RESTRICT` y usa soft delete para perfiles. Auth e historial quedan preservados; la suite de seguridad previa incluye comprobaciones de negocio y relaciones conservados. Remoto actual sigue `auth.users ON DELETE CASCADE`, aunque el conteo read-only de huérfanos es 0. Esto requiere QA/backup y una migración futura; no se modificó producción.

## 7. Categorías y Home

Remoto: 6 negocios publicados, 6 sin categoría principal, 5 destacados. No existen `business_categories` ni `tags`; las únicas relaciones categóricas disponibles son `business_services → subcategories → categories`; `onboarding_metadata` no aporta claves de categoría. Tres negocios de servicio tienen una sola categoría derivada de todos sus servicios activos: Gasfitería, Carpintería, Electricidad. Tres negocios (2 alojamiento, 1 gastronomía) no tienen esa evidencia y quedan `MANUAL_REVIEW_REQUIRED`.

Detalles, origen y SQL reversible están en [phase-3-27-category-data-assessment.md](phase-3-27-category-data-assessment.md), [`scripts/preview-primary-category-backfill.sql`](../scripts/preview-primary-category-backfill.sql) y [`docs/sql/category-backfill-reviewed.sql`](sql/category-backfill-reviewed.sql). El formulario y la RPC actual requieren categoría para enviar a revisión; no se impone `NOT NULL` porque drafts incompletos son válidos. No se inventaron ratings; se confirma existencia de campos Home. En browser la Home, categorías destacadas, Explore (6 resultados), foto de card/detalle cargaron. Detalle consultó `businesses`, `reviews`, `lodging_details` e imágenes con 200; la métrica automática de vista respondió 204.

## 8. Contacto

UI y repo/repository `submit-contact` están implementados. El Edge valida método, CORS, body limitado, JSON, nombre/email/motivo/mensaje; acepta anónimo o JWT, identifica usuario solo si es Auth válido y guarda con service key. No hace INSERT directo de cliente. La tabla `contact_messages` revoca todos los grants de API, activa RLS, permite lectura admin y registra estado/auditoría por trigger en local. La función tiene límite de cuerpo pero no rate/burst limiter durable; evaluar protección anti-spam antes de abrir el canal públicamente.

En producción la UI muestra “Canal de contacto pendiente de habilitación”; `contact_messages` no existe y no hay Edge Functions desplegadas. Se clasifican como **PENDING MIGRATION** y **PENDING EDGE DEPLOY**, no como bug de frontend. No se envió ningún mensaje.

## 9. Admin de usuarios

Código: listado/paginación/búsqueda, invitación, rol, suspensión/reactivación y soft delete están implementados. `admin-user` exige Bearer JWT, vuelve a validar identidad con Auth, usa `current_user_is_admin`, valida payload y registra auditoría; las mutaciones de perfil dependen de RPC restringidas y soft delete conserva Auth. Servicio global requiere sesión SuperAdmin en modelo local 050060.

Remoto: función y migraciones requeridas no están desplegadas; helper actual acepta tenant admin. Admin CRUD está **PENDING MIGRATION / PENDING EDGE DEPLOY** y **SECURITY BLOCKED** hasta aislamiento global. No se alteraron cuentas productivas.

## 10. Notificaciones y configuración

Notificaciones existentes tienen `user_id`, `read_at`, metadata y deep link; políticas remotas observadas incluyen lectura propia y helpers admin. Las mejoras de recipients/audit/configuración están en migraciones locales pendientes. La configuración WhatsApp permanece manual; no hay integración automática ficticia. Los nuevos toggles, canales de contacto, defaults y auditoría dependen de migraciones no aplicadas. Global settings requieren SuperAdmin con sesión en el modelo local.

## 11. Provider, legales y Auth

Provider Join se abrió en producción; explica identificación, categoría, cobertura y revisión; no se inició el alta. Sin una cuenta de prueba autorizada no se probó el flujo autenticado completo. El onboarding local valida categoría/contacto/cobertura/servicios antes de enviar.

Términos, Privacidad y Contacto abrieron en browser real. La UI Contacto está visible, pero deshabilitada mientras falta backend. Login también abrió. No se cambiaron Auth ni datos, no se creó usuario real, y no se ensayaron sign-up/sign-in con cuentas reales en esta pasada.

## 12. Edge Functions, secretos y CORS

`supabase functions list` devolvió cero funciones desplegadas; inventario de código:

| Función | Uso / auth | Dependencias / estado |
|---|---|---|
| `submit-contact` | Contacto público anónimo/autenticado; `verify_jwt=false`, valida JWT opcionalmente | `contact_messages`, service role runtime-managed; pendiente tabla y deploy |
| `admin-user` | JWT obligatorio validado por código y gate global | RPCs de usuarios/auditoría, service role runtime-managed; role hardening y deploy pendientes |
| `notify-provider-review` | Webhook interno con header secreto, `verify_jwt=false` | Profiles, Auth admin, notifications y service role; pendiente wiring/deploy |

El listado de secretos custom remotos está vacío; no se leyeron valores.

| SECRET | FUNCTION | REQUIRED | PROD STATUS |
|---|---|---:|---|
| `ADMIN_NOTIFICATION_WEBHOOK_SECRET` | `notify-provider-review` | REQUIRED | MISSING |
| `SUPABASE_URL` | Las tres | REQUIRED | RUNTIME_MANAGED |
| `SUPABASE_SERVICE_ROLE_KEY` | Las tres | REQUIRED | RUNTIME_MANAGED |
| `SUPABASE_ANON_KEY` | `admin-user` | REQUIRED | RUNTIME_MANAGED |

El secreto webhook es obligatorio porque la función rechaza toda solicitud si falta. No debe crearse/reutilizarse desde producción hasta el deploy aprobado; configurar un valor nuevo en el destino cuando corresponda.

La allowlist CORS ya tenía ambos dominios de producción; se añadieron orígenes exactos `localhost`/`127.0.0.1` en puertos 3000 y 5000 para desarrollo, sin `*`. Deno CORS cubre prod, dev, rechaza origen externo y acepta requests sin Origin.

## 13. RLS y funciones SECURITY DEFINER

Las 42 tablas remotas tienen RLS; hay 102 policies. El read-only revisó policies representativas de profiles, negocios/servicios/cobertura, solicitudes, consentimientos, conversaciones y notificaciones. Helpers `is_admin`/`current_user_is_admin` todavía hacen que policies admin remotas acepten tenant admin. `contact_messages` no existe remoto.

Los 79 SECURITY DEFINER observados tienen `search_path` explícito, pero la revisión body/grants no está cerrada para las 54 funciones anon-executable. Los 12 admin directos ya no son anónimos. Tres helpers DML sin guard explícito requieren revocación local 071700. Admin business functions llaman el helper global, así que siguen permitiendo tenant admin autenticado en producción.

## 14. Drift remoto resumido

| Área | Remoto | Local esperado | Acción |
|---|---|---|---|
| Migration history | 32 applied | 57 archivos | QA y secuencia de 25 faltantes (24 funcionales + 071700) |
| GRANT hotfix | 0/0/0 en TRUNCATE anon/auth y admin RPC anon | mismo contrato | Aplicado; mantener rollback preparado |
| Rol global | helper acepta admin y super_admin; no sesión | solo super_admin + sesión activa | Bloqueo; aplicar hardening en lote probado |
| SuperAdmin | tabla ausente; 0 cuentas | sessions/bootstrap listos | Elegir identidad real fuera de banda |
| Owner FK | `auth.users ON DELETE CASCADE` | `profiles(id) ON DELETE RESTRICT` | Preflight + migración local en QA |
| Contacto | tabla ausente, Edge inventory vacío | migración/Edge listos | Pendiente migration/deploy |
| Home categories | 6/6 published sin primary category | columna nullable + requirement | Backfill 3 high-confidence, 3 manual |
| Edge | 0 funciones desplegadas | 3 funciones tipadas | secrets/CORS/migrations antes del deploy |
| RLS | 42 enabled, 102 policies | hardening local con sesiones | Validación SQL sobre snapshot requerida |

## 15. Browser / red / errores

Smoke read-only Playwright: Home, Explore, detalle, categorías visuales, fotos, Términos, Privacidad, Contacto UI, login y Provider Join. PostgREST negocio/reviews/lodging y Storage fotos: 200; métrica vista: 204; no se observaron excepciones de consola, 401/403/404/5xx ni rutas faltantes. La métrica automática de vista creó un evento de analytics (no crítico); no se hicieron otros writes ni se enviaron formularios.

## 16. Problemas corregidos y pendientes reales

Corregido/aplicado: permisos TRUNCATE y anon RPC admin en producción; allowlist CORS dev local; rollback; test del hotfix y preparación de helper revocations; evidencia/backfill seguro de categorías.

Pendiente: role separation remoto; sesión SuperAdmin y elección humana inicial; exposición de tres helpers internos; revisión de los demás anon-executable SECDEF; QA restore/rollback y reset local; 24 migraciones funcionales; owner FK; categoría de 3 negocios sin evidencia; deployment de 3 Edge Functions; tabla Contacto; secreto webhook; Admin/settings/notifications nuevos; prueba Auth/Provider/Admin con cuentas de prueba; rate limiter anti-spam; validación completa SQL/RLS/HTTP.

## 17. Runbook de producción futuro (sin ejecutar)

1. **A — recovery:** verificar backup/PITR operativo; descifrar snapshot fuera del repo y restaurar a QA identificado y separado. Comparar counts/checksums; comprobar rollback.
2. **B — emergency grants:** verificar proyecto/ref, inventario 42 tablas/12 RPC, preflight 42/42/12, revisar [`20261007160000_emergency_grants_only.sql`](../supabase/migrations/20261007160000_emergency_grants_only.sql). En producción ya está aplicado y postflight 0/0/0; no volver a ejecutar en el runbook.
3. **C — assertions:** revisar ACL efectiva incluido PUBLIC, lecturas públicas y migration history; confirmar solo 071600 está registrado fuera de la secuencia.
4. **D — roles/SuperAdmin:** aplicar secuencia de role migrations en QA; crear session table, helpers, guards, audit y admin Edge authorization. No seleccionar/promover cuenta hasta identidad humana aprobada. Nunca habilitar consola tenant global.
5. **E — ownership:** preflight huérfanos = 0, respaldo probado; aplicar `businesses.owner_id → profiles(id) ON DELETE RESTRICT`; probar soft delete/Auth/negocios/historial.
6. **F — migraciones funcionales:** reconciliar primero drift conforme a `phase-3-25-5` runbook. Revisar las 24 versiones enumeradas arriba en orden; preparar un reemplazo seguro para 041300, resolver el solapamiento 041320 y cerrar manualmente los candidatos de 041330 antes de planificar apply. Después ensayar los bloques con checkpoints en QA; incluir 071700 luego de helpers/dependencies. No marcar versiones no ejecutadas.
7. **G — category data:** correr preview; aplicar solo tres candidatos con categoría única en transacción; dejar otros tres `MANUAL_REVIEW_REQUIRED` hasta confirmación.
8. **H — Edge:** desplegar `submit-contact`, `admin-user`, `notify-provider-review` después de tablas/RPC, gate global y pruebas HTTP QA. Configure JWT behavior de código/webhook.
9. **I — secrets:** configurar `ADMIN_NOTIFICATION_WEBHOOK_SECRET` nuevo en el destino; verificar PRESENCE sin valor. Runtime secrets managed por Supabase.
10. **J — smoke:** Home/Explore/detalle/legal/Contacto/notifications/admin/settings/bootstrap/sessions con usuarios QA; revisar status/console y auditar.
11. **K — frontend:** solo después de aprobar backend; `flutter build web --release`, revisar Vercel output y hacer deploy por ventana autorizada.
12. **L — Git:** revisar grupos de cambios y reportes, excluir artifacts; crear commit(s) bajo mensaje aprobado y push a la rama objetivo solo tras revisión humana.

### Precheck futuro

- [ ] Backup restaurable y QA restore verificado
- [ ] Production ref y QA ref diferenciados
- [ ] Migration list local/remota y secuencia revisadas
- [ ] SQL/rollback exactos revisados
- [ ] Identity del primer SuperAdmin aprobada fuera de banda
- [ ] Secrets y webhook nuevos configurados
- [ ] CORS prod validado
- [ ] Grants/ACL/RLS preflight y postflight preparados
- [ ] SQL assertions y Home queries pasan
- [ ] Flutter build release verificado

## 18. Plan Git al regresar

No se hizo commit ni push. Al revisar el árbol:

- **A funcionales:** cambios existentes en `lib/`, `test/`, router, provider, settings, solicitudes y legales; varios ya estaban modificados al inicio.
- **B seguridad:** migraciones 071600/071700, Supabase config/CORS y bootstrap/backup/preflight scripts.
- **C tests:** pruebas Flutter y contratos SQL/Deno.
- **D docs:** reportes 3.25.x, 3.26, 3.26.2A y 3.27; revisar autoría y coherencia antes del commit.
- **E builds:** `vercel_output/` tiene archivos modificados y debe compararse/revisarse antes de stage; `build/web` es salida local.
- **F preexistentes/temporales:** `.playwright-cli/` ya contenía capturas/YAML anteriores y recibió capturas/YAML del smoke público de esta sesión; `flutter_04.png`, `deno.lock` y muchos docs/archivos nuevos también estaban al inicio. No atribuirlos ni eliminarlos en bloque; revisar/excluir los artefactos de navegador al preparar staging. El cluster PostgreSQL de fixtures quedó detenido fuera del repo bajo `%TEMP%`.

Recomendado al volver: revisar `git status`, decidir archivos de build/artifacts, revisar diff por tema, repetir diff-check, acordar división en commits, luego push solo tras aprobación. No se dejó ninguna acción irreversible pendiente ejecutada.

## 19. Matriz final de función

| FUNCIÓN | CÓDIGO | TESTS | LOCAL | PRODUCCIÓN | ACCIÓN |
|---|---|---|---|---|---|
| Home | READY | READY | NOT TESTED (DB local) | WORKING | reparar datos de categoría con evidencia |
| Explore / detalle / fotos | READY | READY | NOT TESTED | WORKING | sin cambios |
| Categoría principal | READY | READY | NOT TESTED | PENDING DATA FIX | actualizar 3 y revisión manual 3 en QA |
| Auth / sesión | READY | READY | WORKING (fixtures) | NOT TESTED autenticado | usar cuenta de prueba autorizada |
| Provider Join | READY | READY | WORKING (widget) | WORKING visual, no alta | sin alta real |
| Legales | READY | READY | WORKING | WORKING | sin cambios |
| Contacto UI | READY | READY | WORKING | WORKING UI deshabilitada | falta tabla + Edge deploy |
| Contacto backend | READY | READY Deno | NOT TESTED HTTP local | PENDING MIGRATION | aplicar Contact migrations en QA |
| Admin usuarios | READY | READY widget/SQL previo | NOT TESTED actual | SECURITY BLOCKED | role separation, migration y Edge deploy |
| Notificaciones / settings | READY | READY | NOT TESTED DB | PENDING MIGRATION | validar RPC/policies en QA |
| Owner FK / soft delete | READY | READY SQL previo | NOT TESTED actual | PENDING MIGRATION | owner FK restrict en secuencia probada |
| SuperAdmin global | READY | READY SQL previo | WORKING previo documentado | SECURITY BLOCKED | tabla/sesión/bootstrap; identidad humana |
| Grants hotfix | READY | READY SQL model | WORKING model | READY (applied) | preservar 0/0/0 |
| Internal SECDEF helpers | READY local migration | READY model | WORKING model | SECURITY BLOCKED | aplicar solo tras revisión/QA |
| CORS | READY | READY Deno | WORKING | WORKING policy | mantener allowlist exacta |
| Edge functions | READY | READY typecheck | WORKING typecheck | PENDING EDGE DEPLOY | secretos y deploy aprobado |

## 20. Próximos pasos para el usuario

1. Revisar la tabla de candidatos de categoría y confirmar manualmente alojamiento/gastronomía.
2. Aprobar fuera de banda qué identidad se convertirá en primer SuperAdmin; no se creó ninguna.
3. Confirmar backup/PITR y proveer/identificar un proyecto QA separado con ref verificable para restaurar y validar todas las migraciones/rollback.
4. Revisar el hardening local de helpers y la matriz de 54 RPC anon restantes antes de la secuencia funcional.
5. Proveer un `ADMIN_NOTIFICATION_WEBHOOK_SECRET` nuevo solo cuando corresponda al deploy.
6. Revisar los cambios agrupados y decidir commit/push posteriores.

**Clasificación final: READY FOR PRODUCTION APPLY: NO.** El hotfix mínimo de grants sí está aplicado; quedan bloqueos técnicos de role separation y helpers remotos, drift de esquema/owner, categorías y restore/QA. No se debe aplicar el resto de producción todavía.
