# Fase 3.32 — Flujo anónimo de solicitudes, reservas y consentimiento

## Resultado

El modelo permanece **ADMIN / PROVIDER / ANON**. Visitantes pueden enviar una solicitud sin iniciar sesión; el servidor no crea Auth users ni perfiles. No se realizaron cambios remotos, despliegues, commits ni pushes.

**ANONYMOUS REQUEST FLOW: READY**  
**ANONYMOUS RESERVATION FLOW: READY** (mesa y alojamiento se crean como pendientes para revisión del proveedor; el modelo de mesa no tiene inventario/slots para confirmar capacidad en la creación).  
**FINAL ROLE MODEL: ADMIN / PROVIDER / ANON**  
**ROLE MODEL MIGRATION: READY**  
**READY FOR PRODUCTION APPLY: CONDITIONAL**

## Auditoría y cambios

- Los tres flujos públicos de solicitud/reserva que heredaban identidad/Auth eran la solicitud de servicio, reserva de mesa y reserva de alojamiento. Ya no requieren sesión, `profile`, `customer` ni `auth.uid()` del visitante. `/visitor/profile` redirige a Explore.
- La pantalla de solicitud pide nombre, teléfono, detalle, consentimiento y datos del servicio; muestra loading, éxito y error sin navegar a un detalle privado. No invita a login/registro. No se envía una solicitud si falta consentimiento.
- Las reservas de mesa y alojamiento recogen nombre, teléfono y consentimiento y envían datos al proveedor. Provider conserva vistas de solicitudes/reservas en el ámbito de sus negocios, con teléfono accionable. Admin usa el ámbito global ya definido.
- Se retiró del formulario público de solicitudes el upload de adjuntos que dependía de Auth. No se sustituyó por una función nueva; si los adjuntos son requisito de producto, decidirlo antes de apply.
- Mensajes de éxito no prometen tiempos: indican que el proveedor puede contactar al número ingresado.

## Migración y servidor

Nueva última migración: `20261007222000_anonymous_customer_submissions.sql`.

- `service_requests.customer_id` y las relaciones de usuario de reservas se vuelven nullable; datos históricos no se eliminan. Se agregan datos de contacto/consentimiento/fingerprint donde aplica.
- Añade tablas de control e idempotencia durables con RLS y sin permisos de acceso directo desde API. Limpieza acotada de registros expirados durante las reclamaciones.
- RPCs públicas de inserción quedan ejecutables solo por `service_role`, que usa la Edge Function. Anon/authenticated no obtienen INSERT/SELECT/UPDATE/DELETE directo sobre las tablas protegidas.
- La función del servidor valida payload, formato telefónico chileno, consentimiento y relaciones de negocio/servicio; fija status, timestamp y actor anónimo. Negocio/servicio no publicado o no asociado falla como no encontrado. No guarda IP en claro ni registra nombre/teléfono/payload en logs.
- Límite durable: hasta 3 envíos por hash de teléfono y hora y 10 por hash de IP y hora; IP solo si el proxy la proporciona. Exceso devuelve 429. HMAC usa la clave runtime de Supabase; solo se guardan hashes.
- Idempotency UUID y fingerprint bloquean reintentos y contenido idéntico por 10 minutos; respuestas de duplicado son 409. Fechas/slots de alojamiento se validan bajo advisory transaction lock y la aceptación de reservas también serializa la disponibilidad.
- Tabla inicia en `pending`; no existe modelo de inventario/slot de mesas en el esquema actual, por tanto creación no equivale a confirmación de capacidad. Alojamiento valida capacidad, tarifas, mínimo de noches, calendario y solapamientos antes de crear; aceptación vuelve a comprobar conflictos con lock.

Edge Function nueva `submit-request`, `verify_jwt=false` para aceptar visitantes; internamente usa RPC autenticada con service role. CORS usa orígenes explícitos de producción y desarrollo configurados, sin wildcard. Los otros endpoints no cambiaron de destino ni se desplegaron.

## Pruebas ejecutadas

- Snapshot de producción previamente validado restaurado en PostgreSQL 16 aislado fuera del repo. Métricas iniciales observadas: 42 tablas públicas, 15 perfiles, 12 negocios; la suite confirmó que `auth.users` y `profiles` no cambian durante envíos anónimos.
- Reproducción secuencial de 32 migraciones pendientes sobre dos restauraciones limpias (`ranco_332_snapshot_exact`, `ranco_332_snapshot_repeat`), incluyendo migración 3.32. La nueva migración se reejecutó idempotentemente en ambas.
- Contrato 3.32 pasó en ambas restauraciones: solicitud válida sin Auth, sin perfil, idempotencia, límite durable/429, reserva mesa y alojamiento, contacto/consentimiento, y denegación de lectura/escritura directa anon/authenticated.
- 10 suites SQL de seguridad, grants, roles, Home, contacto y flujo anónimo pasaron en snapshot migrado.
- Deno: 11/11 tests. Edge type-check: 4 funciones (submit-contact, admin-user, notify-provider-review, submit-request).
- Flutter analyzer: sin issues. Build web release: PASS. `dart format .`: 207 archivos, 1 archivo formateado. Encoding: PASS. `git diff --check`: PASS (avisos de conversión CRLF de Git solamente).
- Flutter: **687/687 tests PASS**. Migraciones locales: **64**; remoto conocido: **32 registradas / 32 pendientes**.

## Límites y pendientes

- No se inició Supabase local/Edge HTTP: no se requiere Docker, y esta sesión verificó snapshot SQL + Deno + type-check, no una invocación HTTP contra Supabase Functions runtime. Antes del deploy, ejecutar health/HTTP smoke en QA.
- No se hicieron consultas ni escrituras remotas durante esta fase; no se afirma un estado remoto nuevo.
- Requiere decisiones/aprobación antes de producción: las tres categorías marcadas `MANUAL_REVIEW_REQUIRED`; configuración de `ADMIN_NOTIFICATION_WEBHOOK_SECRET` si el inventario de deploy la requiere; aprobación del apply y backup inmediatamente anterior.
- Primer administrador ya definido por Fase 3.31: `admin@lagoranco.cl`, profile `a7affb25-ad32-4836-be38-cb2af81343c7`.
- La validación final encontró y corrigió una referencia TypeScript no definida en el mapper de solicitudes y un `if` Flutter sin bloque; los checks finales quedaron verdes. El formulario no ofrece adjuntos (limitación heredada del flujo autenticado); reservar mesas crea solicitudes pendientes, no garantiza cupo.

## Archivos principales

- Migración: `supabase/migrations/20261007222000_anonymous_customer_submissions.sql`
- Edge: `supabase/functions/submit-request/index.ts` y `_shared/public_submission*.ts`
- Flutter: formularios/repositorios de solicitud, mesa y alojamiento; utilidad de teléfono/idempotencia.
- Contratos: `supabase/tests/phase_3_32_anonymous_flows.sql`, `test/phase_3_32_anonymous_flow_test.dart` y tests de continuidad visitante.
- Runbook: `docs/phase-3-28-production-apply-runbook.md`.

