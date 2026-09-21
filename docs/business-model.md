# Modelo multivertical

Fecha: 2026-09-21

Ranco Conecta 2.0 se modela como una plataforma comun con capacidades modulares por negocio. El concepto central ya no es solo "negocio", sino:

`business + business_type + capabilities + monetization rules`

## Business type

`business_type` representa comportamiento de producto, no texto visible ni categoria comercial. Los tipos soportados son:

- `service`
- `commerce`
- `gastronomy`
- `lodging`
- `tourism`
- `emergency`

La base de datos ya tenia un enum PostgreSQL para `business_type`. Se mantiene por compatibilidad y se agregan `tourism` y `emergency` en una migracion nueva. La decision no es perfecta para extensibilidad futura, pero evita una migracion destructiva ahora. Si aparecen muchas verticales nuevas, el siguiente paso recomendado es migrar a catalogo o columna `text` con constraint controlada.

## Type vs category

`business_type` decide capacidades y experiencia de producto.

`category` y `subcategory` describen rubros visibles y filtros.

Ejemplos:

- `business_type = service`, `category = Hogar y mantencion`, `subcategory = Gasfiteria`.
- `business_type = lodging`, `category = Alojamientos`, `subcategory = Cabanas`.

## Capabilities

Las capacidades se resuelven desde `BusinessCapabilityResolver` en Flutter. La regla local combina:

- capacidades base por `business_type`;
- features habilitadas por plan;
- feature flags locales;
- restricciones backend futuras.

Los flags `PAYMENTS_ENABLED=false`, `CHAT_ENABLED=false` y `QUOTES_ENABLED=false` siguen apagando esas capacidades aunque existan conceptualmente.

## Publicacion gratuita

La publicacion no depende de pago. El flujo objetivo es:

`cuenta -> negocio draft -> perfil completo -> revision -> publicacion gratis`

La membresia controla herramientas premium, no la existencia publica del negocio. La aprobacion y publicacion siguen siendo cambios sensibles que no deben ejecutarse desde Flutter.

## Membresias

`membership_plans` se conserva por compatibilidad y se amplia con `billing_period`, `display_order` y `metadata`.

`plan_features` separa cada feature del plan: `plan_id`, `feature_key`, `enabled`, `limit_value` y `metadata`.

## Comisiones

Las comisiones viven en `commission_rules`, separadas de membresias. Flutter no calcula ni hardcodea precios o porcentajes; `MonetizationPolicyService` solo resuelve la politica aplicable desde datos recibidos.

## Modelo por vertical

Servicios: perfil gratuito, suscripcion profesional/premium futura.

Alojamiento: publicacion gratuita, comision futura sobre reservas procesadas por Ranco y plan profesional opcional.

Turismo: publicacion gratuita, comision futura sobre reservas y herramientas premium opcionales.

Gastronomia: gratuito inicialmente, plan profesional futuro y comision solo si Ranco procesa reservas, pedidos o pagos.

Comercio: gratuito inicialmente, plan comercio/profesional futuro y comision solo si existe e-commerce procesado por Ranco.

Emergencias: perfil gratuito, herramientas premium de disponibilidad; sin comision inicial.

Los porcentajes y precios definitivos no estan definidos.

## Cambios sensibles

`business_sensitive_change_requests` prepara una cola futura para cambios que requieren revision: propietario, identidad/documentacion, nombre legal, tipo de negocio, estados de publicacion/verificacion y direccion o categoria sensible.

## Destacados y promociones

`business_offers` queda reservado para ofertas o promociones publicadas por el negocio, por ejemplo descuentos o paquetes.

`featured_placements` prepara productos publicitarios separados, como posiciones destacadas o patrocinadas gestionadas por Ranco. No hay cobro implementado en esta fase.

## Cierre funcional de Fase 1

El onboarding real usa Supabase como fuente de verdad:

- `create_business_draft` crea negocio y owner membership atomicamente.
- `update_business_draft` guarda progreso.
- `submit_business_for_review` valida requisitos y cambia a `pending_review`.

La siguiente fase es construir el panel administrativo para revisar, solicitar cambios y publicar.

## Fase 2 admin

La revision administrativa permite:

- solicitar cambios;
- rechazar;
- publicar;
- suspender;
- restaurar.

Publicar no exige membresia paga ni verificacion documental. `published` significa aprobado y visible; `verification_status` queda separado.
