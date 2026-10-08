# Categorías de negocios — diagnóstico de datos

Auditoría read-only al proyecto RancoConecta, 2026-10-07. No se actualizó producción. Se conservaron únicamente IDs de negocios/categorías necesarios para el backfill; no se incluyeron nombres de negocio ni datos de usuario.

## Hallazgo

Hay 6 negocios publicados y los 6 tienen `primary_category_id IS NULL`. Cinco aparecen destacados. El schema remoto sí contiene `categories`, `subcategories` y `business_services`; no existen las tablas `business_categories` ni `tags`. Ningún `onboarding_metadata` de estos seis registros contiene claves de categoría.

La ruta actual de onboarding guarda categoría en el borrador, el formulario bloquea envío sin categoría y `business_review_requirements` la exige antes de enviar/publicar. `replace_manageable_business_services` también rechaza servicios de otra categoría y, si el campo principal está vacío, lo establece a partir de la categoría del servicio. No se encontró una ruta actual del formulario que publique sin categoría. La evidencia apunta a filas históricas o creadas fuera de ese flujo; no permite atribuir la causa histórica con certeza.

## Candidatos de backfill

La única evidencia admitida es que todos los servicios activos del negocio resuelvan a exactamente una categoría. No se infirió categoría por nombre, tipo de negocio, imagen o suposición.

| BUSINESS_ID | CURRENT | PROPOSED | SOURCE | CONFIDENCE |
|---|---|---|---|---|
| `33595129-2e00-4abb-bb72-61c5f5b9f990` | NULL | `2b0fff8e-10fd-488f-9471-31a8ab447467` (Gasfitería) | `business_services → subcategories.category_id` | HIGH |
| `487a5eee-cb79-4cb3-8a5c-c5e3ad706677` | NULL | — | Sin servicios de categoría | MANUAL_REVIEW_REQUIRED |
| `a23c6ce8-a186-4e1a-8b09-3100cc142bc7` | NULL | — | Sin servicios de categoría | MANUAL_REVIEW_REQUIRED |
| `b163593b-ce67-458f-92c8-faeb6b4d74b5` | NULL | `9a583338-a707-4d47-9985-557b7b189aa1` (Carpintería) | `business_services → subcategories.category_id` | HIGH |
| `bec6390b-5782-422f-9654-82687553b84e` | NULL | — | Sin servicios de categoría | MANUAL_REVIEW_REQUIRED |
| `e325ad8f-7720-4517-abff-1ec0050676f6` | NULL | `6521897c-a7c7-46ff-95f4-587cb252c0ce` (Electricidad) | `business_services → subcategories.category_id` | HIGH |

El preview read-only está en [`scripts/preview-primary-category-backfill.sql`](../scripts/preview-primary-category-backfill.sql). El SQL preparado incluye guardas por estado publicado, valor todavía NULL, categoría activa y categoría única; termina con `ROLLBACK` intencional en [`docs/sql/category-backfill-reviewed.sql`](sql/category-backfill-reviewed.sql). No se ejecutó.

## Acción recomendada

En QA, ejecutar el preview y el SQL transaccional; verificar que solo cambien los tres IDs con evidencia. Confirmar manualmente la categoría de los otros tres con sus titulares antes de completar el backfill. Mantener `primary_category_id` nullable porque los borradores válidos pueden estar incompletos; bloquear publicación sin categoría mediante los requisitos existentes.
