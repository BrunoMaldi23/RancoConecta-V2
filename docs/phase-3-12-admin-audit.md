# Fase 3.12: auditoría de roles y cola de negocios

Fecha: 1 de octubre de 2026.

## Diagnóstico

- El contador del panel consultaba `admin_business_review_stats()` directamente y podía mostrar dos revisiones pendientes y seis publicados. El panel de pendientes y `/admin/businesses` usaban `admin_business_review_queue()`, que delega en `admin_list_business_reviews()`.
- La función interna declaraba `owner_email text`, pero seleccionaba `auth.users.email`, de tipo `varchar(255)`. Una reproducción aislada en PostgreSQL confirmó el fallo de `RETURN QUERY` por incompatibilidad de tipos y que `u.email::text` lo resuelve. No se obtuvo el código de error de la sesión real del administrador, así que esta es la causa técnica más sólida identificada, no una traza remota capturada.
- La consulta conserva `LEFT JOIN` para categoría, perfil y usuario: la falta de uno de esos datos opcionales no elimina negocios. El filtro «Todos» envía `p_status = null`; la consulta no impone tipo de negocio cuando `p_business_type = null`.
- `RancoErrorState` clasificaba cualquier texto con «cargar» como fallo de conexión. Eso explicaba el aviso engañoso en Cuenta. La pantalla también descartaba el fallo recibido y mostraba un texto genérico.

## Cambios

- Migración aditiva `20261001210000_admin_review_queue_email_type.sql`: conversión explícita `u.email::text`, chequeo de sesión y rol administrativo, permisos de ejecución para `authenticated`. No modifica filas de usuarios ni negocios.
- Errores de Cuenta y de administración ahora reflejan el fallo real de forma apta para la interfaz. El repositorio de revisiones emite diagnósticos técnicos solo en debug, con datos sensibles redactados. `AdminGate` comprueba explícitamente `canAccessAdmin` además del filtrado del proveedor de rol.
- Un administrador con negocio gestionable ve «Mi negocio» además de sus accesos administrativos; sin negocio no recibe una invitación a publicarlo. Cuenta incluye Auditoría junto con el resto de módulos administrativos.

## Datos y permisos observados

- Supabase informa 27 migraciones locales y remotas coincidentes; `db push --linked --dry-run` indicó que no hay pendientes.
- Una consulta pública limitada a nombres, tipo y estado confirmó seis negocios publicados: tres servicios, un gastronómico y dos alojamientos. El gastronómico existe en la base; el filtro del catálogo o sus categorías requieren comprobación aparte antes de atribuirle el cero observado en la fase anterior.
- Los permisos de acceso administrativo siguen comprobándose en la ruta y en las funciones SQL. La visibilidad de «Mi negocio» se deriva de negocios propios o membresías activas, no del rol global de proveedor.
- Una consulta que incluía prefijos de IDs de propietario fue rechazada por la revisión automática como dato privado innecesario. No se repitió por otra vía. Sin sesión administrativa disponible, no se inspeccionaron propietarios ni los dos negocios pendientes.

## QA

- Reproducción SQL local del error de tipos: falló sin cast y pasó con cast.
- `flutter analyze --no-pub`: sin problemas.
- `flutter test`: 191 pruebas aprobadas, incluidas las cuatro pruebas del guard admin y las nuevas regresiones de SQL, menú y errores.
- `supabase migration list --linked` y `db push --linked --dry-run`: 27 versiones sincronizadas, ninguna pendiente.
- `scripts/deploy-production.ps1 -SkipGit -SkipVercel` pasó: codificación, formato, análisis, pruebas, `git diff --check` y compilación web de producción local. Sin publicación en Vercel.

## Validación real aún necesaria

1. Recargar la sesión existente de `admin@lagoranco.cl` y abrir «Revisiones pendientes» y `/admin/businesses`; confirmar que aparecen las dos pendientes y los seis publicados, además de búsqueda, filtros y detalle.
2. Revisar con las cuentas proveedor y visitante existentes que cada una solo vea sus rutas y negocios propios. No se dispone de credenciales de esas cuentas en este entorno.
3. Probar una acción de revisión real únicamente con un negocio y resultado autorizados por el equipo; aquí no se alteraron publicaciones reales.
4. Revisar el filtro público Gastronomía y la asociación de categorías del negocio gastronómico publicado. El dato público demuestra que existe, pero no que cumpla los filtros del catálogo.

La automatización de navegador no pudo acceder a la sesión local del usuario porque el proceso CUA terminó inesperadamente. Esta fase no se declara cerrada ni se despliega a Vercel hasta completar la validación real.
