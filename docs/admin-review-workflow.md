# Admin review workflow

Fecha: 2026-09-21

## Roles

La autoridad administrativa proviene de `profiles.role`.

- `admin`: puede revisar negocios, solicitar cambios, rechazar, publicar, suspender y restaurar.
- `super_admin`: comparte las mismas capacidades de revision en esta fase.

Flutter no usa `service_role`. El panel admin sigue siendo cliente no confiable y todas las acciones sensibles pasan por RPC.

## Estados

Lifecycle de publicacion:

- `draft`
- `pending_review`
- `changes_requested`
- `published`
- `rejected`
- `suspended`
- `archived`

No existe estado `approved` separado. En Fase 2, aprobar y publicar ocurren juntos mediante `published`.

## RPCs

- `admin_business_review_stats`
- `admin_list_business_reviews`
- `admin_get_business_review`
- `admin_request_business_changes`
- `admin_reject_business`
- `admin_publish_business`
- `admin_suspend_business`
- `admin_restore_business`

Cada RPC valida `auth.uid()` mediante `current_user_is_admin()`.

## Seguridad

Las funciones administrativas usan `SECURITY DEFINER`, fijan `search_path` y no aceptan `actor_id` desde cliente. El actor se toma desde `auth.uid()`.

No se concede `UPDATE` general a `businesses` para administradores. Los cambios de estado pasan por RPCs especificas.

## Eventos y auditoria

`business_review_events` registra:

- `submitted`
- `resubmitted`
- `changes_requested`
- `rejected`
- `published`
- `suspended`
- `restored`

`audit_logs` conserva auditoria administrativa estructurada.

## Notificaciones

Las acciones admin crean notificaciones in-app para owners/managers del negocio. No hay push notifications ni FCM en esta fase.

## Publicacion

`admin_publish_business` vuelve a ejecutar `business_review_requirements`. Un negocio incompleto no puede publicarse.

La publicacion no exige membresia paga. Las capacidades base provienen de `business_type`.

## Siguiente fase

Despues de Fase 2, el siguiente bloque recomendado es solicitudes, matching y cotizaciones.
