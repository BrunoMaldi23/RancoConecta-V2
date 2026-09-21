# Fase 0 - Hardening Inicial

Fecha: 2026-09-21

## Objetivo

Corregir primero la base necesaria para evolucionar Ranco Conecta sin romper funciones existentes ni habilitar modulos incompletos de forma accidental.

## Cambios aplicados en esta intervencion

- Se agrego `docs/audit-current-state.md` como auditoria integral del estado real.
- Se agrego este documento como bitacora de Fase 0.
- Se agrego una configuracion inicial de feature flags en `AppConfig`.
- Se agrego test para asegurar que chat, pagos y cotizaciones permanezcan desactivados por defecto, mientras alojamiento queda activo.

## Cambios aplicados en Fase 0.2

- Se agrego la migracion `20260921103000_operations_business_members.sql`.
- Se crearon `operations` y `operation_events` sin conectar aun solicitudes o reservas existentes.
- Se creo `business_members` con backfill desde `businesses.owner_id`.
- Se agregaron modelos Dart para operaciones y membresias de negocio.
- Se agregaron APIs compatibles en `ProviderBusinessRepository`: `getMyBusinesses()`, `getBusinessMemberships()` y `getBusinessByIdForCurrentUser()`.
- `getMyBusiness()` se conserva temporalmente como compatibilidad.
- Se agrego un guard sincronico para rutas privadas de gestion de proveedor.
- Se agrego un test de dominio para estados de operacion y roles de negocio.

## Feature flags definidos

Los flags se leen con `--dart-define`:

- `CHAT_ENABLED`, default `false`.
- `PAYMENTS_ENABLED`, default `false`.
- `QUOTES_ENABLED`, default `false`.
- `LODGING_ENABLED`, default `true`.

Estos flags no implementan los modulos por si mismos. Solo preparan un mecanismo seguro para controlar despliegues graduales.

## Riesgos que siguen abiertos

- La aprobacion/publicacion de negocios aun no tiene backend administrativo.
- `avatars` y `request-attachments` requieren policies completas antes de exponer uploads fuera de su contexto.
- Cotizaciones, pagos, chat y notificaciones deben permanecer deshabilitados hasta tener RLS/backend.

## Toolchain

Estado validado:

- Dart 3.12.0.
- Flutter 3.44.0.
- `flutter analyze`: No issues found.
- `flutter test`: tests pasando.

## Fase 1 multivertical

La Fase 1 revisada agrega una base multivertical antes de terminar onboarding:

- `business_type` explicito para service, commerce, gastronomy, lodging, tourism y emergency.
- resolucion central de capabilities en Dart.
- features de membresia separadas en `plan_features`.
- reglas de comision separadas de membresias en `commission_rules`.
- contexto de negocio activo para usuarios con multiples negocios.
- autogestion rutinaria despues de publicacion, manteniendo campos sensibles como autoridad backend.

Pagos, chat y cotizaciones completas siguen deshabilitados por feature flags.

## Cierre funcional de Fase 1

- `BusinessType.parse` ya no convierte valores desconocidos a `service`; `tryParse` y `parseOrDefault` hacen explicitos los fallbacks.
- `create_business_draft` crea negocio y owner membership de forma atomica.
- `update_business_draft` persiste progreso de onboarding.
- `submit_business_for_review` valida requisitos minimos y mueve el negocio a `pending_review`.
- `business_offers` queda reservado para promociones del negocio; `featured_placements` prepara destacados publicitarios futuros.
- El onboarding persiste en Supabase y puede retomarse.
- Service tiene servicios, cobertura y clasificacion persistente.
- Lodging mantiene compatibilidad con `lodging_details` y dashboard existente.
- La siguiente fase es `ADMIN + REVIEW + PUBLICATION`.
