# Auditoria Integral - Estado Actual

Fecha: 2026-09-21

Este documento registra la primera intervencion sobre el plan maestro de evolucion de Ranco Conecta 2.0. Su objetivo es fijar el estado real del repositorio antes de ejecutar cambios mayores.

## Estado real del proyecto

Ranco Conecta 2.0 es una aplicacion Flutter/Dart con Supabase como backend. El producto ya supera una base de directorio simple: tiene autenticacion, exploracion, favoritos, solicitudes, resenas, perfiles de negocio y un modulo de alojamientos con calendario y reservas.

El README todavia describe principalmente Sprint 0 y Sprint 1, pero el codigo incluye una segunda migracion productiva para alojamientos y pantallas de proveedor que no estan completamente reflejadas en la documentacion principal.

## Arquitectura detectada

La estructura principal sigue un enfoque feature-first:

- `lib/app`: widget raiz.
- `lib/bootstrap`: inicializacion.
- `lib/config`: configuracion tipada.
- `lib/router`: rutas y shell responsive.
- `lib/theme`: sistema visual.
- `lib/core`: errores, result, logging y widgets base.
- `lib/features`: modulos funcionales.
- `lib/shared`: modelos compartidos.
- `supabase`: migraciones, seed y workspace de funciones.
- `docs`: documentacion tecnica.

El flujo esperado es:

`UI -> Riverpod provider/controller -> repository -> Supabase`

En general, los widgets no acceden directamente a `Supabase.instance.client`; usan repositorios y providers. Esa regla esta bien encaminada.

## Features existentes

- `auth`: login, registro, recuperacion y estado de sesion.
- `profile`: cuenta y edicion basica del perfil.
- `home`: portada, rubros, prestadores y acceso a proveedor.
- `discovery`: busqueda y filtros.
- `categories`: catalogo de rubros.
- `locations`: localidades y selector.
- `businesses`: listado, cards, detalle y perfil publico de alojamiento.
- `favorites`: guardados.
- `service_requests`: creacion directa, historial y detalle.
- `reviews`: resenas asociadas a negocios.
- `provider_registration`: onboarding visual de prestador.
- `provider_dashboard`: gestion de alojamiento.
- `lodging_bookings`: reservas de alojamientos.

## Features incompletas

- `quotes`: existe tabla, pero no hay flujo completo proveedor/cliente.
- `operations`: existe estructura inicial desde Fase 0.2, pero aun no esta conectada a solicitudes, reservas o pagos.
- `messaging`: existen tablas base, falta UI, realtime y permisos extendidos.
- `notifications`: existe tabla base, falta experiencia in-app/push/preferencias.
- `payments`: existe tabla base, falta arquitectura de pasarela, Edge Functions y webhook.
- `memberships`: existen planes/membresias, falta activacion, vencimiento y pagos reales.
- `admin/moderation/support`: no hay panel ni flujos operativos.
- `analytics`: no existe modulo de eventos o metricas de proveedor.
- `non-lodging provider management`: la gestion avanzada esta concentrada en alojamientos.

## Rutas actuales

Shell principal:

- `/`
- `/explore`
- `/requests`
- `/saved`
- `/account`

Rutas fuera del shell:

- `/sign-in`
- `/sign-up`
- `/forgot-password`
- `/provider/join`
- `/provider/register`
- `/provider/dashboard`
- `/provider/lodging`
- `/provider/bookings`
- `/provider/calendar`
- `/provider/photos`
- `/provider/rates`
- `/account/edit`
- `/business/:id`
- `/business/:id/request`
- `/business/:id/availability`
- `/requests/:id`

## Tablas Supabase existentes

Migracion foundation:

- `profiles`
- `regions`, `communes`, `locations`
- `categories`, `subcategories`
- `businesses`
- `business_services`
- `business_coverage`
- `business_hours`
- `business_media`
- `service_requests`
- `quotes`
- `favorites`
- `reviews`
- `membership_plans`
- `memberships`
- `payments`
- `notifications`
- `audit_logs`
- `conversations`
- `messages`

Migracion de alojamientos:

- `lodging_details`
- `lodging_calendar`
- `lodging_bookings`

Migracion Fase 0.2:

- `operations`
- `operation_events`
- `business_members`

## Migraciones existentes

- `20260907000000_sprint_0_foundation.sql`: base de catalogo, marketplace, solicitudes, cotizaciones, membresias, pagos, notificaciones, auditoria y chat preparatorio.
- `20260908181500_lodging_production.sql`: detalles de alojamiento, calendario, reservas, RPCs y policies para media de alojamientos.
- `20260921103000_operations_business_members.sql`: nucleo transaccional, eventos de operacion y membresias de negocio con backfill desde `businesses.owner_id`.

## RLS existente

RLS esta habilitado para las tablas principales. Las policies cubren lectura publica de catalogos activos, negocios publicados, datos propios de usuario, favoritos propios, solicitudes del cliente y solicitudes dirigidas a proveedores propietarios.

Limitaciones detectadas:

- Admin/super admin diferidos.
- Mutacion de pagos y membresias desde Flutter no permitida, correcto.
- Visibilidad de solicitudes abiertas para proveedores diferida.
- Respuestas de proveedor a resenas diferidas.
- Storage para `avatars` y `request-attachments` requiere policies mas especificas.

## Edge Functions existentes

Solo existe `supabase/functions/README.md`. No hay funciones implementadas para pagos, notificaciones, administracion ni integraciones externas.

## Storage buckets

Preparados:

- `business-media`
- `avatars`
- `request-attachments`

La segunda migracion agrega policies operativas para `business-media` en contexto de alojamiento. `avatars` y `request-attachments` siguen pendientes de flujo/policies completas.

## Estado del onboarding

Existe pantalla de registro de prestador con pasos:

- cuenta;
- publicacion;
- cobertura;
- membresia;
- confirmacion.

Limitacion clave: el flujo crea la cuenta, pero no completa todavia todo el ciclo negocio -> revision -> aprobacion -> publicacion. El propio texto de la UI indica que pago y activacion de membresia quedan para el siguiente modulo.

## Estado solicitudes

Hay creacion directa de solicitudes a un negocio, listado de solicitudes propias y detalle. Existe una maquina de estados inicial en `ServiceRequestStatus`, con tests. Falta convertirlo en operacion completa con cotizaciones, adjuntos, matching, conversacion y transiciones backend-side.

## Estado cotizaciones

La tabla `quotes` existe con policies basicas. No hay UI completa ni `quote_items`. Tampoco existe flujo de aceptar/rechazar cotizacion que avance una operacion.

## Estado alojamientos

Es el modulo mas avanzado despues del directorio. Incluye:

- perfil publico especializado;
- disponibilidad;
- creacion de reservas mediante RPC;
- detalles de alojamiento;
- tarifas;
- fotos;
- calendario;
- gestion de reservas por proveedor.

Pendientes:

- amenities;
- cancelaciones;
- historial de reservas del cliente;
- pagos;
- estados extendidos de calendario;
- politicas avanzadas;
- estadia maxima, limpieza, garantia e instant booking.

## Estado pagos

Documentado como pendiente. Existe tabla `payments`, pero no hay Edge Functions, gateway, webhook, ledger, idempotencia financiera ni UI final.

## Estado membresias

Existen planes seed y tablas `membership_plans`/`memberships`. Falta sistema de periodos, facturas, eventos, activacion, vencimiento y renovacion.

## Estado chat

Existen `conversations` y `messages`, pero no hay UI de chat, realtime, miembros, lecturas, adjuntos ni notificaciones.

## Estado notificaciones

Existe `notifications`, pero no hay centro de notificaciones, preferencias, device tokens ni push.

## Estado admin

No existe panel admin. Las policies administrativas estan diferidas hasta disenar rol server-side seguro.

## Problemas tecnicos detectados

- Documentacion principal desactualizada respecto del modulo de alojamientos.
- Textos visibles aun hardcodeados en widgets; falta estrategia progresiva de localizacion.
- Varias pantallas tienen estilos locales repetidos que deberian migrar gradualmente al design system.
- No hay feature flags centralizados para habilitar modulos incompletos de forma segura.
- No hay paginacion visible en listados de negocios.
- `ProviderBusinessRepository.getMyBusiness()` se conserva por compatibilidad, pero ya existe base para `getMyBusinesses()`.
- Las rutas privadas de proveedor requieren sesion; el acceso por negocio/rol sigue dependiendo de datos/RLS.

## Riesgos de seguridad

- Mantener pagos y membresias sin mutacion desde cliente es correcto; no debe cambiarse.
- La aprobacion/publicacion de negocios debe hacerse via backend/admin, nunca desde Flutter.
- `business-media` ya tiene policies de alojamiento; falta cerrar criterios equivalentes para avatar y adjuntos privados.
- Las transiciones sensibles de solicitudes, reservas, pagos y membresias deben pasar a RPC/Edge Functions.
- Chat y notificaciones deben disenar RLS antes de UI.

## Codigo muerto o duplicado

- `home_demo_provider.dart` parece remanente de estados demo y debe revisarse antes de eliminar.
- Hay cards, secciones, badges y botones con estilos locales repetidos en varias pantallas.
- Algunos docs describen solo Sprint 0/Sprint 1 y ya no reflejan todo el alcance.

## Deuda tecnica

- Falta conectar `operations` progresivamente a solicitudes/reservas mediante flujos backend.
- Falta flujo controlado para crear/administrar `business_members` mas alla del backfill de owners.
- Falta admin seguro.
- Falta abstraccion de pagos.
- Falta estrategia de SEO/deep links publica.
- Falta test suite RLS automatizable.
- Falta observabilidad de errores.
- Falta cache/offline basico.

## Arquitectura objetivo propuesta

Mantener el enfoque feature-first, agregando progresivamente:

- `features/operations`
- `features/quotes`
- `features/messaging`
- `features/notifications`
- `features/payments`
- `features/memberships`
- `features/provider`
- `features/admin` o app/panel separado
- `features/analytics`
- `features/support`
- `features/moderation`

No mover masivamente archivos existentes sin necesidad. Las nuevas features deben nacer con `data`, `domain` y `presentation` solo si aportan claridad.

## Migraciones necesarias

Prioridad alta:

- `quote_items`
- estados extendidos para onboarding/publicacion o tabla de revisiones
- `request_attachments`
- `notification_preferences`
- `device_tokens`
- `message_reads`
- `message_attachments`
- `payment_events` e idempotency keys
- `audit_logs` extendido

Prioridad media:

- `business_verifications`
- `favorite_lists`
- `business_offers`
- `support_tickets`
- `reports`
- `business_metrics_daily`

## Roadmap tecnico recomendado

1. Fase 0: hardening, docs, flags, tests, RLS review, errores y consistencia.
2. Fase 1: onboarding real de negocio y envio a revision.
3. Fase 2: admin minimo para revisar/aprobar negocios.
4. Fase 3: solicitudes, matching y cotizaciones.
5. Fase 4: chat contextual.
6. Fase 5: notificaciones in-app y luego push.
7. Fase 6: arquitectura de pagos con Edge Functions.
8. Fase 7: membresias reales.
9. Fase 8: fortalecer alojamientos.
10. Fase 9: confianza, verificaciones y metricas.
11. Fase 10+: geolocalizacion, comercio, gastronomia, analytics y crecimiento.
