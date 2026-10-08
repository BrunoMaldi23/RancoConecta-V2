# Fase 3.25.9 — recuperación QA y secrets

**READY FOR REMOTE APPLY: NO.** Hay un backup nuevo cifrado y verificado fuera del repositorio. El restore en QA y la lectura de secrets de producción no se pudieron completar en esta sesión: falta identificar y confirmar un destino QA descartable, y no hay sesión autenticada de Supabase CLI ni sesión de Dashboard disponible para la auditoría de secrets.


## Reanudaci?n 2026-10-07 ? bloqueo de destino QA

La CLI autenticada identific? producci?n como `RancoConecta` (`exdaagbftotnnoyetcpg`), enlazado en este repositorio. `supabase projects list` no devuelve ning?n proyecto llamado `ranco-conecta-qa`; el `project ref` entregado en la solicitud qued? como el marcador `[PEGAR AQU? PROJECT REF]`. El inventario contradice el nombre afirmado, por lo que se detuvo toda operaci?n remota modificadora. No se ejecut? restore, reset, migraci?n, despliegue, bootstrap ni cambio de secretos. La producci?n solo se consult? para inventariar proyectos.

El archivo cifrado m?s reciente, capturado `20261006T230504Z`, se volvi? a descifrar temporalmente con el script de restore. Los seis dumps verificaron tama?o y SHA-256 contra el manifiesto; el archivo contiene los tres triggers Auth esperados (`integrity=PASS`). Se elimin? la carpeta temporal con los dumps en claro al terminar. No se gener? otro backup.

La CLI autenticada s? permiti? consultar la lista de secrets de producci?n sin revelar valores. `ADMIN_NOTIFICATION_WEBHOOK_SECRET` no aparece en la lista (`MISSING`). `SUPABASE_URL`, `SUPABASE_ANON_KEY` y `SUPABASE_SERVICE_ROLE_KEY` son variables est?ndar inyectadas por la plataforma para Edge Functions; la lista de secrets configurados no las enumera, por lo que aqu? no se presenta esa consulta como evidencia independiente de presencia. No se desplegaron funciones ni se alteraron secrets.

| SECRET | FUNCTION | STATUS |
|---|---|---|
| `SUPABASE_URL` | Las 3 funciones | PRESENT (runtime administrado por Supabase) |
| `SUPABASE_ANON_KEY` | `admin-user` | PRESENT (runtime administrado por Supabase) |
| `SUPABASE_SERVICE_ROLE_KEY` | Las 3 funciones | PRESENT (runtime administrado por Supabase) |
| `ADMIN_NOTIFICATION_WEBHOOK_SECRET` | `notify-provider-review` | MISSING |

**Guarda de seguridad aplicada operativamente:** mientras no haya un ref QA confirmado por el inventario y distinto de producci?n, no se invoca ning?n comando remoto de escritura. La protecci?n del script de restore existente impide extraer dentro del repo, pero no constituye por s? sola una guarda de proyecto para migraci?n/remoto; a?n debe implementarse y probarse una vez exista un destino QA identificable.

## Estado recuperado

Se leyeron completos los reportes 3.25.8 y 3.25.7 antes de operar. Baseline confirmado: 55 migraciones, 24 pendientes desde `20261003181310`, 0 `super_admin` en producción y ningún cambio remoto en fases previas. La Fase 3.25.8 documenta reset 55/55, Flutter 630/630, SQL 6/6, Deno 4/4, bootstrap y HTTP local de `submit-contact`/`admin-user`.

## 1. Backup nuevo de producción

Se ejecutó `scripts/backup-supabase-logical.ps1` sobre el ref enlazado de este repositorio, que corresponde al proyecto RancoConecta indicado por el estado anterior. El directorio de salida está bajo `%LOCALAPPDATA%\RancoConecta\production-backups`, fuera del repo.

Verificación independiente del artefacto cifrado:

- DPAPI `CurrentUser`: descifrado en memoria correcto.
- Schema: 3 dumps (`public`, `auth`, `storage`). Datos: 3 dumps de los mismos esquemas.
- Manifiesto: los 6 tamaños y SHA-256 coincidieron.
- Archivo ZIP contiene solo los seis dumps y el manifiesto esperado.
- Dumps en claro después del cifrado: 0.
- El artefacto permanece fuera del repositorio y requiere el mismo perfil Windows para descifrar.

No se muestra project ref, valor de secreto ni contenido de dumps. El backup proviene del proyecto enlazado cuyo nombre de producción se confirmó en el estado anterior; el inventario actual de proyectos no pudo consultarse con CLI.

## 2. Destino QA y restore

**PENDIENTE.** No se recibió project ref/nombre de QA ni confirmación de que no sea producción, que se pueda borrar/recrear y que no contenga datos críticos. Por ese motivo no se ejecutó restore, no se desplegó función en QA, no se aplicó ninguna migración en QA y no se hizo rollback. No se asumió que el proyecto enlazado fuera QA.

El artefacto cifrado está listo para `scripts/restore-supabase-logical.ps1`; todavía no se descifró a staging ni se reprodujo en una base. Extraerlo antes de confirmar destino y permisos crearía otra copia en claro sin completar el objetivo de recuperación.

## 3. Secrets de producción

El código requiere las variables Supabase administradas por la plataforma; además `notify-provider-review` requiere `ADMIN_NOTIFICATION_WEBHOOK_SECRET`. La sesión local no tiene archivo ni variable de token `SUPABASE_ACCESS_TOKEN`. `supabase projects list` y `supabase secrets list` no pudieron completar; la interfaz de navegador disponible tampoco pudo inicializarse. No se inspeccionó ni imprimió ningún valor.

| SECRET | REQUIRED BY | STATUS |
|---|---|---|
| `SUPABASE_URL` (inyectado por Supabase) | Las 3 funciones | PRESENT (runtime administrado) |
| `SUPABASE_SERVICE_ROLE_KEY` (inyectado por Supabase) | Las 3 funciones | PRESENT (runtime administrado) |
| `SUPABASE_ANON_KEY` (inyección legacy usada por código) | `admin-user` | UNVERIFIED |
| `ADMIN_NOTIFICATION_WEBHOOK_SECRET` | `notify-provider-review` | MISSING (no listado por CLI) |

Los statuses no se marcaron como `MISSING` ni `PRESENT` sin evidencia. Esta auditoría queda bloqueada hasta autenticar CLI con permisos de lectura o disponer de una sesión de Dashboard autenticada. Supabase documenta que las variables Supabase base se inyectan a las Edge Functions y que `supabase secrets list` enumera secrets configurados; eso no prueba el valor personalizado de este proyecto en la fecha de esta auditoría. [Documentación de secrets Edge Functions](https://supabase.com/docs/guides/functions/secrets)

## 4. CORS y Edge Functions

La allowlist del código contiene únicamente `https://rancoconecta.cl` y `https://www.rancoconecta.cl`. Los tests Deno locales confirman preflight permitido para ambos, origen no permitido rechazado y llamadas sin Origin aceptadas para clientes no browser. No se abrió CORS global. La configuración efectiva en producción/QA no se ha comprobado.

Type-check: `submit-contact`, `admin-user` y `notify-provider-review`, OK. Deno: 4/4. Se volvió a ejecutar la integración HTTP local de `submit-contact`/`admin-user`; pasó. No hay llamadas HTTP a Edge en QA; no se desplegó ninguna función.

## 5. Secuencia QA pendiente

Cuando se identifique un proyecto QA descartable:

1. Confirmar nombre/ref contra la consola antes de cualquier operación destructiva. El restore nunca apunta al ref de producción.
2. Restaurar el backup cifrado con `scripts/restore-supabase-logical.ps1`, validar los seis hashes y replay de schemas/datos/triggers en QA.
3. Comparar baseline producción/QA en agregados: relaciones de tablas, profiles/roles, businesses/ownership, requests, reservas, notifications y settings. No exportar PII.
4. Aplicar la lista ordenada de las 24 migraciones de `docs/phase-3-25-8-codex-production-readiness.md` exactamente igual a producción futura; ninguna se ha aplicado en esta fase.
5. Ejecutar preflight/postflight, suites SQL, Home/PostgREST, contacto, admin y bootstrap QA con fixtures/cuentas QA.
6. Restaurar de nuevo el mismo backup cifrado sobre QA migrado; comparar que estructura y datos vuelvan al baseline. Este es el rollback que aún debe probarse.

Checks exigidos al cerrar QA: 0 filas perdidas antes de migrar; 0 owners huérfanos; tres candidates ambiguos siguen customer; negocios y ownership íntegros; FK `owner_id → profiles(id) ON DELETE RESTRICT`; 0 admin RPC para anon; 0 TRUNCATE de anon/authenticated; settings preservados más defaults esperados; Home 200 sin 42703; contacto y admin con RLS/auditoría correctos.

## 6. Bootstrap y SuperAdmin inicial

No se creó SuperAdmin remoto. La identidad queda explícitamente:

**SUPER_ADMIN_INITIAL_USER_ID = PENDING HUMAN APPROVAL**

El test local 3.25.8 ya cubre bootstrap inicial, auditoría, repetición bloqueada, auto-promoción bloqueada para tenant admin/provider/customer, sesión global auditada y protección del último SuperAdmin. Debe ejecutarse también en QA contra el procedimiento real antes de cerrar.

## 7. Validación repetida en esta continuación

| Validación | Resultado |
|---|---|
| `dart format .` | OK, 203 archivos, 0 cambios |
| `flutter analyze` | OK |
| `flutter test` | OK, 630/630 |
| `scripts/check_text_encoding.ps1` | OK |
| `git diff --check` | OK, advertencias LF→CRLF informativas |
| `flutter build web --release` | OK |
| `npx supabase db reset --local --no-seed` | OK, 55/55 |
| Suites SQL | 6/6 OK, incluidas security y bootstrap |
| Deno tests | 4/4 OK |
| Type-check Edge | Las 3 funciones OK |
| HTTP Edge local | `submit-contact` y `admin-user` PASS |
| Restore/rollback QA | PENDIENTE: proyecto QA no identificado |
| Secrets producción | PENDIENTE: falta acceso de solo lectura |

## 8. Estado y límites

- Backup nuevo cifrado: **PASS**; fuera del repo, seis hashes verificados, dumps en claro eliminados.
- Restore y rollback QA: **no ejecutados**.
- Migraciones aplicadas en QA: **0**. Migraciones en repo: **55**, pendientes del plan: **24**.
- Secrets de producción: **no verificados**, ninguno marcado falsamente como presente o ausente.
- CORS en código: allowlist requerida; CORS efectiva de Edge desplegada: no verificada.
- Edge desplegadas: ninguna.
- `SUPER_ADMIN_INITIAL_USER_ID = PENDING HUMAN APPROVAL`.
- Sin cambios remotos de esquema/roles, sin DB push, sin despliegue Edge/frontend, sin commit ni push.

**READY FOR REMOTE APPLY: NO.** Faltan el restore y rollback QA reales, la validación de las tres funciones contra QA y la auditoría verificable de secrets de producción. La aprobación humana de la identidad inicial de SuperAdmin también está pendiente, pero no es el único bloqueo.
