# Fase 3.33 — Informe de apply de producción

**Resultado:** `PARTIAL` — backend migrado y parcialmente verificado; apply detenido antes del deploy frontend por falta de datos elegibles para una solicitud anónima real.

**Proyecto:** RancoConecta (`exdaagbftotnnoyetcpg`)  
**Ventana de ejecución:** 2026-10-07 UTC  
**Rama:** `main`  
**Commit / push:** no realizados.

## Backup

- Backup lógico creado antes de escribir: `20261007T201448Z`.
- Ubicación cifrada fuera del repositorio: `%LOCALAPPDATA%\RancoConecta\production-backups\exdaagbftotnnoyetcpg-20261007T201448Z\snapshot.zip.dpapi`.
- SHA-256: `E12B0643F3820823A1A16F1063D1F4DA8084D87C6CB2362F36123467E96BD8E4`.
- Verificación: manifiesto y hashes de los ocho artefactos correctos; restore completo comprobado en PostgreSQL 17 aislado. No se retuvo dump en claro.

## Migraciones

- Antes: 32 migraciones remotas registradas; 32 pendientes de las 64 locales.
- Después: **64/64 aplicadas; 0 pendientes**.
- Se aplicaron individualmente y se registraron tras el postflight por bloque. La migración `20261007160000_emergency_grants_only.sql` no se repitió.
- Secuencia aplicada: 15 migraciones `20261004120000`–`20261004141000`; 9 `20261005000000`–`20261005008000`; 5 `20261007170000`–`20261007210000`; 2 `20261007220000` y `20261007221000`; 1 `20261007222000`.
- Cada uno de los cinco bloques de ensayo desde la copia del backup pasó antes de aplicar. Las assertions remotas se ejecutaron después de los bloques.

## Estado de datos y roles

| Métrica | Final |
| --- | ---: |
| Auth identities | 15 |
| Profiles | 15 |
| Admin activos | 1 |
| Providers | 1 |
| `legacy_customer` inactivos | 13 |
| Negocios | 12 |
| Owners huérfanos | 0 |
| Solicitudes | 0 |
| Reservas de mesa | 0 |
| Reservas de alojamiento | 7 |
| Notificaciones | 3 |
| Settings | 10 |
| Auditoría | 27 |
| Mensajes de contacto | 0 |

- El admin confirmado `a7affb25-ad32-4836-be38-cb2af81343c7` quedó `admin` activo; Auth identity e ID se conservaron.
- Modelo remoto: `admin / provider`; los 13 perfiles históricos de consumidor siguen inactivos como `legacy_customer`. No se creó Auth user ni profile de consumidor.
- `businesses.owner_id → profiles(id) ON DELETE RESTRICT`; 0 huérfanos.
- Providers y negocios se preservaron. La prueba contractual de `current_user_is_admin()` dio falso para el provider y verdadero para el admin activo.

## Categorías

Se aplicaron transaccionalmente las tres categorías aprobadas, después de comprobar que las categorías existían activas y que los valores previos eran `NULL`:

| Business ID | Category ID |
| --- | --- |
| `487a5eee-cb79-4cb3-8a5c-c5e3ad706677` | `9fb2a294-afcf-44fe-b54f-efe9b2e14b9e` |
| `a23c6ce8-a186-4e1a-8b09-3100cc142bc7` | `f80b79e2-95b8-40fc-9906-6825af1dba11` |
| `bec6390b-5782-422f-9654-82687553b84e` | `9fb2a294-afcf-44fe-b54f-efe9b2e14b9e` |

Quedan otros tres negocios publicados sin categoría primaria. El preflight de servicios mostró tres negocios con servicios activos pero sin categoría; el script de evidencia objetiva propone respectivamente `2b0fff8e-10fd-488f-9471-31a8ab447467`, `9a583338-a707-4d47-9985-557b7b189aa1` y `6521897c-a7c7-46ff-95f4-587cb252c0ce`, según `business_services → subcategories.category_id`. No se modificaron porque la autorización de este bloque enumeró exclusivamente las tres asignaciones aprobadas.

## Security postflight

- `TRUNCATE` efectivo: anon `0`; authenticated `0`.
- RPC administrativas `SECURITY DEFINER` ejecutables por anon: `0`.
- Helpers internos de envío/rate-limit: sin `EXECUTE` efectivo por anon ni `PUBLIC`.
- Lectura anónima de `service_requests`, `gastronomy_table_reservations`, `lodging_bookings` y `contact_messages`: denegada.
- FK de ownership validada; 0 owners huérfanos.
- Se conservaron las 15 Auth identities, los 15 perfiles, los 12 negocios y los registros históricos medidos.

## Secrets y Edge Functions

- `ADMIN_NOTIFICATION_WEBHOOK_SECRET`: `PRESENT`.
- Durante una verificación inicial, la salida de `supabase secrets list` incluyó inesperadamente el valor. Se rotó de inmediato mediante RNG criptográfico, se eliminó el archivo temporal privado y se verificó nuevamente solo por nombre. El valor actual no se incluye aquí. No se detectó un archivo de secret persistente en el repositorio.
- Edge Functions desplegadas y verificadas `ACTIVE`: `submit-contact`, `admin-user`, `notify-provider-review`, `submit-request` (4/4). `verify_jwt=false` según configuración; cada función aplica su validación propia.
- Type-check previo al deploy: 4/4.

## HTTP smoke

- Contacto anónimo: HTTP 201; CORS permitió `https://rancoconecta.cl`. El mensaje de prueba y su notificación fueron eliminados después de verificar el flujo.
- Reserva anónima de mesa: HTTP 201; creada sin sesión. La reserva de prueba y su notificación huérfana se retiraron mediante assertions. No dejó filas de reserva ni notificación.
- Solicitud de servicio anónima: **BLOQUEADA antes de enviar**. No existe una combinación actual de negocio publicado, categoría primaria y servicio activo que satisfaga la validación de `submit_public_service_request`. Los tres negocios con categorías aprobadas tienen cero servicios activos; los tres que tienen servicios activos siguen con categoría primaria nula. No se creó una solicitud de prueba ni se asignaron categorías adicionales.
- Home por REST anónimo: HTTP 200; seis negocios publicados y cinco registros multimedia; campos `is_featured`, `accepts_requests`, `rating_avg`, `review_count` y `primary_category_id` presentes, sin error 42703.
- CORS de Contacto: PASS. La lectura anónima de las tablas privadas fue denegada.
- La reserva de alojamiento no se probó contra inventario productivo.

## Deploy y Git

- Frontend deploy: **NO ejecutado** por la condición de abort: el flujo crítico de solicitud no pudo verificarse con datos actuales.
- Smoke de dominio posterior al frontend: no aplicable; no se hizo deploy.
- Admin y Provider login/panel: no probados con cuentas reales; no se proporcionaron credenciales seguras para esas sesiones.
- Commit: no creado. Push: no intentado.
- Docker estuvo disponible y se usó PostgreSQL 17 aislado para restaurar y simular los bloques antes del apply.
- El contenedor PostgreSQL aislado se detuvo y retiró. La limpieza recursiva del directorio de restore descifrado `%TEMP%\ranco-333-production-backup-restore2` fue rechazada por la política automática del entorno; requiere limpieza manual con `Remove-Item -LiteralPath "$env:TEMP\ranco-333-production-backup-restore2" -Recurse -Force`. El backup cifrado no se debe borrar.

## Validaciones de código

- Validación previa al apply reportada: Flutter 687/687.
- Repetición final: `flutter test --reporter compact` pasó **634/634**. La diferencia de 53 casos frente al conteo previo no se pudo reconciliar en esta ejecución; queda registrada y no se oculta.
- `flutter analyze`: PASS.
- `flutter build web --release`: PASS.
- Encoding y `git diff --check`: PASS.
- Deno: 11/11 con `deno@latest` (Deno 2.2 cacheado no podía leer la versión actual de `deno.lock`; no se modificó el lockfile).
- Edge type-check: 4/4.
- SQL contracts aislados: 10/10.

La suite Flutter actual está verde, pero el conteo menor que el baseline es otra diferencia de cierre pendiente de reconciliar antes de declarar `SUCCESS`.

## Intervención requerida

El checkpoint de solicitud anónima no pasó porque no hay datos de negocio/servicio elegibles. No se avanzó al deploy frontend, commit ni push. Para reanudar:

1. Confirmar y aplicar, si corresponde, las tres categorías con evidencia objetiva indicadas arriba, o habilitar servicios activos que coincidan con la categoría primaria.
2. Repetir el smoke HTTP de solicitud y verificar creación sin Auth/profile y limpieza de la fila de prueba.
3. Completar el smoke de alojamiento con fixture o una ventana segura que no afecte inventario.
4. Solo entonces continuar con la decisión de frontend deploy y los smoke de sesiones Admin/Provider.

No se ejecutó rollback general: las migraciones y cambios aprobados pasaron sus assertions; el bloqueo es de datos/flujo y el restore indiscriminado podría revertir escrituras legítimas concurrentes. El backup cifrado permanece disponible para recuperación si una revisión posterior demuestra corrupción.

## 3.33.1 APPLY RESUME

**Resultado de reanudación:** `PARTIAL`; se resolvió la discrepancia del conteo Flutter, pero no se reanudaron el smoke de solicitud, frontend deploy, commit ni push porque producción no contiene un negocio elegible sin cambiar datos productivos.

### Confirmación read-only de producción

- Proyecto: RancoConecta (`exdaagbftotnnoyetcpg`).
- Migraciones: **64 locales / 64 remotas / 0 pendientes**.
- Admin activo: **1**; owners huérfanos: **0**.
- Edge Functions: `submit-contact`, `admin-user`, `notify-provider-review` y `submit-request`: **4/4 ACTIVE**.
- Grants efectivos: `TRUNCATE anon = 0`, `TRUNCATE authenticated = 0`, `admin SECURITY DEFINER RPC ejecutables por anon = 0`.
- No se realizaron escrituras remotas en esta reanudación.

### Datos para solicitud anónima

La consulta read-only encontró tres negocios publicados con servicios activos. Los tres tienen `primary_category_id IS NULL`; no existe otro negocio publicado con categoría primaria y servicio activo que permita cumplir la validación de `submit_public_service_request`. Los nombres de servicio corresponden a la subcategoría asociada:

| Negocio | Servicio activo | Categoría candidata (ID) | Evidencia | Resultado |
| --- | --- | --- | --- | --- |
| Gasfitería Lago Ranco (`33595129-2e00-4abb-bb72-61c5f5b9f990`) | Filtraciones; Destapes | Gasfitería (`2b0fff8e-10fd-488f-9471-31a8ab447467`) | Ambos servicios activos apuntan a subcategorías cuya categoría es Gasfitería; la descripción del negocio coincide. | No asignada; requiere autorización de datos |
| Carpintería Futrono (`b163593b-ce67-458f-92c8-faeb6b4d74b5`) | Muebles; Pisos y terrazas | Carpintería (`9a583338-a707-4d47-9985-557b7b189aa1`) | Ambos servicios activos apuntan a subcategorías cuya categoría es Carpintería; la descripción coincide. | No asignada; requiere autorización de datos |
| Servicios del Ranco (`e325ad8f-7720-4517-abff-1ec0050676f6`) | Enchufes e iluminación | Electricidad (`6521897c-a7c7-46ff-95f4-587cb252c0ce`) | El servicio activo apunta a una subcategoría cuya categoría es Electricidad; la descripción del negocio coincide. | No asignada; requiere autorización de datos |

Las propuestas se basan en evidencia objetiva de servicios y descripciones, pero no se ejecutó el backfill: la autorización previa cubrió solo las tres categorías aplicadas durante Fase 3.33. No se envió una solicitud de prueba, por lo que no hay filas ni notificaciones de smoke que limpiar. Solicitud anónima queda `MANUAL_DATA_DECISION_REQUIRED`.

### Reconciliación Flutter 687 vs 634

La corrida reproducible desde la raíz con `flutter test --machine` emitió **687 eventos `testDone`**. De ellos, **53 son eventos internos ocultos** de `loading`/`tearDown`; los **634 restantes son casos de prueba reales**, con 0 fallos y 0 skips. La corrida estándar `flutter test` terminó en **634/634**. No se detectaron archivos de prueba eliminados ni directorio `integration_test`; existen 49 suites Flutter descubiertas. Por tanto, `687` fue el total de eventos del protocolo, no el total de casos, y el conteo comparable correcto es 634.

### Validación y continuación

- Flutter: **634/634 PASS**; `flutter analyze`: PASS; `flutter build web --release`: PASS.
- Encoding: PASS; `git diff --check`: PASS (solo avisos Git LF/CRLF existentes).
- Deno: **11/11 PASS**; Edge type-check: **4/4 PASS**; SQL contracts: **10/10 PASS** en la simulación aislada ya registrada.
- Contacto y reserva anónima de mesa conservan sus smoke PASS previos. Reserva de alojamiento: `MANUAL_SMOKE_REQUIRED` para evitar afectar inventario. Panel Admin y Provider: `MANUAL_SMOKE_REQUIRED`, sin sesión de prueba disponible.
- No se hizo frontend deploy ni smoke de dominio porque el checkpoint crítico de solicitud anónima sigue sin datos elegibles. No se creó commit ni se intentó push. No se hizo ninguna nueva asignación de categoría.
- No se ejecutó rollback general: las verificaciones read-only no indican corrupción o regresión de seguridad; el impedimento es la falta de categoría primaria para todos los negocios con servicios activos.

**Estado:** `INTERVENTION REQUIRED` para completar solicitud anónima de producción. La siguiente acción necesaria es autorizar las tres asignaciones candidatas anteriores (o habilitar servicios/categorías mediante un cambio de datos autorizado); después se podrá repetir el smoke y continuar con deploy, dominio, commit y push.

## 3.33.2 CIERRE FINAL

**Resultado:** `PARTIAL` — backend y solicitud anónima quedaron verificados; el deploy frontend no se completó porque Vercel rechazó el token de CLI antes de crear un deployment. Por ese checkpoint no se hicieron smoke de dominio, commit ni push.

### Categorías autorizadas

Se aplicaron únicamente las tres asignaciones autorizadas, después de verificar estado publicado, valor previo NULL, servicio activo asociado y categoría activa exacta:

| Negocio | Categoría | Resultado |
| --- | --- | --- |
| Gasfitería Lago Ranco (`33595129-2e00-4abb-bb72-61c5f5b9f990`) | Gasfitería (`2b0fff8e-10fd-488f-9471-31a8ab447467`) | Aplicada |
| Carpintería Futrono (`b163593b-ce67-458f-92c8-faeb6b4d74b5`) | Carpintería (`9a583338-a707-4d47-9985-557b7b189aa1`) | Aplicada |
| Servicios del Ranco (`e325ad8f-7720-4517-abff-1ec0050676f6`) | Electricidad (`6521897c-a7c7-46ff-95f4-587cb252c0ce`) | Aplicada |

Con las tres asignaciones previamente aprobadas, **6/6** negocios previstos tienen categoría asignada. No se cambiaron servicios ni se asignaron otras categorías.

### Solicitud anónima de producción

- `submit-request` recibió el fixture sintético `PRODUCTION SMOKE TEST` para Gasfitería Lago Ranco y el servicio activo Filtraciones: HTTP **201**.
- La fila tuvo negocio, subcategoría, categoría autorizada, estado `submitted` y consentimiento `privacy-2026-10-01` confirmado. No se creó Auth user ni profile: los conteos se mantuvieron en **15 Auth / 15 profiles**.
- Reintento idéntico con la misma idempotency key: HTTP **409 DUPLICATE**; no se duplicó la solicitud.
- Anon obtuvo **401** en SELECT, UPDATE y DELETE directos a `service_requests`.
- Mediante las RPC de aplicación: el provider activo pudo invocar su cola y contactos de ámbito propio; un negocio fuera de su ámbito fue rechazado; el RPC global del admin encontró la fila de prueba mientras existía.
- Una lectura directa de la tabla como `authenticated` devolvió error de permisos sobre el helper interno `request_is_visible_to_business`, que no está concedido a roles API. La UI provider usa las RPC acotadas anteriores; no se expusieron datos. Se registra como bloqueo solo si se pretende habilitar acceso directo a esa tabla.
- Se borraron la solicitud y su notificación sintéticas de manera exacta. Postflight: **0** solicitudes smoke, **0** notificaciones smoke, total solicitudes **0**, notificaciones **3**. No se borró auditoría.
- Rate limiting no se probó por carga en producción; quedó cubierto por los contratos Deno/SQL existentes.

### Postflight remoto

- Migraciones: **64/64**, pendientes **0**; Admin activo **1**; Auth/profiles **15/15**; negocios **12**; owners huérfanos **0**.
- `TRUNCATE anon = 0`; `TRUNCATE authenticated = 0`; RPC admin ejecutables por anon **0**.
- Edge Functions **4/4 ACTIVE**; `ADMIN_NOTIFICATION_WEBHOOK_SECRET` comprobado `PRESENT` sin leer ni registrar el valor.
- Negocios elegibles publicados con categoría y servicio activo: **3**.
- Home REST: HTTP **200**, seis negocios publicados y campos de Home consultables.
- Contacto y reserva anónima de mesa: conservan sus smoke PASS anteriores. Alojamiento, panel Admin y panel Provider quedan `MANUAL_SMOKE_REQUIRED` para sesiones/inventario seguros.

### Validación local y publicación

- `dart format .`: 207 archivos, 0 cambios; `flutter analyze`: PASS; `flutter test`: **634/634**; encoding: PASS; `git diff --check`: PASS (avisos LF/CRLF preexistentes); build web release: PASS.
- Deno: **11/11**; Edge type-check: **4/4**.
- `vercel_output/` es requerido por el pipeline actual: `vercel.json` lo declara `outputDirectory` y Vercel ejecuta la verificación del bundle ya generado. El script existente sincronizó `build/web` y verificó el fingerprint.
- `npm run deploy:production` completó checks y build, pero Vercel CLI devolvió `The specified token is not valid` al recuperar el proyecto. Falló antes de crear deployment; no se cambiaron DNS.
- Dominios `rancoconecta.cl` y `www.rancoconecta.cl`: smoke del nuevo release no ejecutado, porque no hubo deployment.
- Commit: **no creado**. Push: **no intentado**. No incluir secrets, dumps ni backup en Git.

**Siguiente intervención:** autenticar Vercel CLI con la cuenta/proyecto ya asociado, verificar que el proyecto existente siga enlazado y repetir el pipeline. Tras deployment `READY`, hacer smoke de ambos dominios; solo si pasa, revisar/stagear el árbol y crear commit/push. Las migraciones y categorías no deben repetirse. La limpieza de `%TEMP%\ranco-333-production-backup-restore2` fue rechazada por la política del entorno; requiere limpieza manual local. El backup cifrado permanece fuera del repositorio.

## Reanudación Vercel y cierre Git

- Vercel CLI quedó autenticada mediante login de dispositivo. `vercel whoami` confirmó la cuenta `brunomaldi23`.
- Se conservó el enlace al proyecto existente en `.vercel/project.json`; no se creó otro proyecto.
- `npm run deploy:production`: checks locales y build web release pasaron; la salida generada quedó sincronizada y verificada en `vercel_output/`.
- El deploy remoto **falló** y no llegó a `READY`. El builder de Vercel descargó 105 archivos e intentó ejecutar `node scripts/verify-vercel-output.mjs`, pero `scripts/` está excluido por `.vercelignore`; resultado exacto: `Cannot find module '/vercel/path0/scripts/verify-vercel-output.mjs'` y `Command "node scripts/verify-vercel-output.mjs" exited with 1`.
- El deployment no quedó listo. No se verificó el release en los dominios, ni se ejecutaron smoke de dominio, commit o push. No se repitió ninguna operación backend.
- Próximo paso: corregir el conjunto de archivos que Vercel sube (permitir el script de verificación requerido o ajustar el build command sin eliminar la verificación local), volver a ejecutar el pipeline existente, esperar `READY` y recién entonces smoke de dominios y cierre Git.
- Estado de esta reanudación: **INTERVENTION REQUIRED — deploy detenido por configuración de archivos ignorados en Vercel**.
## Fase 3.33.3 — reintento detenido

- Se inspeccionaron `.vercelignore`, `vercel.json`, `package.json` y el verificador. El build command remoto ejecuta `node scripts/verify-vercel-output.mjs`; no se encontraron secretos en los scripts revisados.
- Cambio aplicado a `.vercelignore`: `scripts/` ahora se expresa como `scripts/*` y se exceptúa únicamente `scripts/verify-vercel-output.mjs`. `vercel_output/` se mantuvo.
- Verificación local: el verificador terminó PASS. `vercel deploy --dry --json` confirmó 105 archivos y que `scripts/verify-vercel-output.mjs` está incluido.
- Validaciones: Flutter **634/634**, analyzer PASS, build web release PASS, encoding PASS y `git diff --check` PASS.
- Deployment `D5U52ScyQPRa6cHXkYiEeeEQNYqK` volvió a fallar, estado Vercel `ERROR`. Los logs confirman que el script ya se ejecuta y falla en la aserción `vercel_output is stale; rebuild with deploy-production.ps1`.
- Causa probable: el verificador calcula su fingerprint usando fuentes como `lib/`, que sigue excluido por `.vercelignore`; el entorno remoto no tiene las mismas fuentes con las que se generó el manifest. Los logs confirman el fingerprint obsoleto, pero no publican los hashes comparados.
- Se detuvo después de este fallo: dominios y smoke de release no ejecutados; no se creó commit ni se hizo push. No se tocaron servicios de backend.
- Estado: **INTERVENTION REQUIRED**. Antes de reintentar hay que ajustar el paquete para que la comprobación remota tenga las fuentes requeridas o sustituirla por una verificación del bundle compatible con un payload de solo artefactos, y volver a inspeccionar el dry-run.
## Fase 3.33.4 — payload ampliado y resultado

- El fingerprint local usa exactamente: `lib/`, `web/`, `assets/`, `pubspec.yaml`, `pubspec.lock`, `scripts/deploy-production.ps1`, `scripts/verify-vercel-output.mjs` y `vercel.json`. El `vercel_output/.ranco-build-manifest.json` contiene el fingerprint de fuentes y el SHA-256 de `main.dart.js`.
- Ajuste de `.vercelignore`: se mantuvo `scripts/*` excluido salvo `deploy-production.ps1` y `verify-vercel-output.mjs`; se quitó la exclusión de `lib/`. No se cambió el verificador ni se eliminó la validación.
- Dry-run de Vercel: **265 archivos**; incluidos `lib/` (160), `web/` (7), `assets/` (2), ambos `pubspec`, ambos scripts del fingerprint, `vercel.json` y `vercel_output/` (42). Confirmados fuera `.env` privados, `.dart_tool/production_public_defines.env` y los scripts de backup/restore. `ranco_tokens.dart` fue el único resultado del filtro de nombre “secret”, y es un archivo de tokens visuales del tema, no una credencial.
- Verificación local `node scripts/verify-vercel-output.mjs`: PASS. Flutter **634/634**, analyzer PASS, build web release PASS, encoding PASS y `git diff --check` PASS.
- Deployment `AbucPU9Wv8ovVTWUWh6uS1f6rdNR` volvió a terminar en `ERROR`. Vercel descargó los 265 archivos; logs: `Error: vercel_output is stale; rebuild with deploy-production.ps1` en la línea 70 del verificador.
- Condición exacta que falló: `manifest.sourceHash !== currentSourceHash || manifest.bundleHash !== sha256(bundlePath)`. El log combina ambas comparaciones y no revela cuál difiere en el entorno remoto. El dry-run confirma presencia de todos los caminos de entrada; no demuestra igualdad byte a byte en el builder remoto. No se debilitó ni se desactivó el fingerprint.
- Por regla de la fase, se detuvo tras el fallo: no se verificaron dominios para un deployment `READY`, no se realizó smoke web, commit ni push. No se tocó backend.
- Estado: **INTERVENTION REQUIRED** hasta aislar cuál de las dos comparaciones cambia en el builder remoto; luego repetir el pipeline y continuar solo si queda `READY`.