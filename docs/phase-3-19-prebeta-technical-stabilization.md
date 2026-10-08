# Fase 3.19 — Estabilización técnica pre-beta

Fecha: 2026-10-03/04. Trabajo local. Sin deploy ni escritura remota de base de datos.

## A. Bugs encontrados

- El artefacto de producción podía quedar obsoleto: Vercel sirve `vercel_output`, que está versionado, mientras Flutter compila en `build/web`. No había verificación posterior del JavaScript ni vínculo verificable entre fuentes y bundle.
- El logout invalidaba perfil y contexto proveedor, pero dejaba cachés de favoritos, solicitudes, notificaciones, mensajes y administración. Además el router no conocía la operación de cierre hasta recibir el evento Auth.
- Las tarjetas de alojamiento y mesa mostraban «Ver detalle» pero abrían la ficha del negocio.
- Las tarjetas de negocios consultaban el favorito por negocio: N consultas para N tarjetas.
- Abrir repetidamente el selector de fechas descargaba de nuevo un año de disponibilidad. La consulta del resumen ya estaba memoizada por rango antes de esta fase; cambiar huéspedes no la repetía.
- La búsqueda de Explorar y Usuarios emitía consultas en cada tecla.

## B. Bugs corregidos

- El router ahora envía el logout a `/sign-in` desde el inicio de la operación y deniega `/admin` a perfiles sin rol administrativo. El cierre limpia las cachés privadas enumeradas en `session_actions.dart` y maneja error de sign-out.
- Favoritos, notificaciones, mensajería, solicitudes y resultados administrativos se invalidan o dependen del Auth actual. Las suscripciones Realtime privadas se cierran al cambiar la sesión.
- Las reservas de alojamiento y mesa abren detalle propio con negocio, fecha, personas, mensaje y estado. Turismo continúa usando el detalle real de solicitud de servicio.
- La disponibilidad anual del selector se reutiliza mientras negocio y día de inicio sean iguales; se descarta tras crear una reserva o ante error. El resumen sigue usando su caché por rango.
- Búsqueda de Explorar y Usuarios: debounce de 350 ms, con cancelación al salir; cambiar filtros de Usuarios vuelve a la primera página.

## C. Rendimiento

Línea base aproximada por inspección de los repositorios, sin afirmar latencias de red: Home hace una consulta de negocios con relaciones embebidas y una de categorías; Explorar añade una consulta batch de detalles de alojamiento. Antes, N tarjetas visibles generaban hasta N consultas de favorito; ahora comparten una consulta de IDs por sesión. Administración de usuarios y resumen usan RPCs paginadas/agregadas, sin consulta por fila. El calendario hace una consulta anual al abrirlo por primera vez y la reutiliza; el resumen consulta solo el rango seleccionado. La medición de tiempos con sesión y datos reales queda pendiente.

## D. Auth

`signingOutProvider` bloquea rutas anteriores durante sign-out. El test de router comprueba que `/admin` desaparece antes de terminar el stream Auth y que `/sign-in` permanece tras NO SESSION. Perfil y contexto de negocio ya dependían del UID; se añadieron invalidaciones para el resto del estado privado conocido. Falta una prueba E2E con cuentas reales admin→prestador→admin y dos clientes distintos.

## E. Requests

La fuente unificada existente consulta `service_requests`, `lodging_bookings` y `gastronomy_table_reservations` por UID, y clasifica turismo por `business_type`. Las tres creaciones ya invalidaban `myCustomerActivityProvider`; se confirmó en el código. Las nuevas rutas de detalle de alojamiento y mesa emplean las mismas filas protegidas por RLS y muestran sus columnas existentes. No se cambió ownership ni esquema. Las solicitudes de UID anónimo siguen perteneciendo a ese UID; una futura vinculación requiere prueba explícita de posesión de sesión y confirmación de la cuenta destino, nunca coincidencia por correo/teléfono.

## F. Admin

`/admin` ahora tiene guarda de rol en el router. Categorías CRUD, listado de usuarios, negocio paginado y métricas conservan los contratos existentes. **Pendiente importante:** Usuarios sigue siendo directorio, sin edición de rol ni suspensión real. Cambiar solo `profiles.account_status` no revocaría por sí mismo tokens ni todas las políticas RLS; no se añadió una acción de suspensión que prometiera una restricción inexistente. El CRUD seguro requiere RPC, validación de último admin, negocios del prestador, auditoría y revisión del efecto de suspensión sobre Auth/RLS.

## G. RPC

El frontend usa `admin_search_business_reviews` y `admin_list_categories`, ambas definidas en `20261003000000`. El historial remoto ya incluye esa migración. No se ocultó un error RPC como lista vacía. No se probó una llamada administrativa autenticada contra producción en esta fase.

## H. RLS

No se editó RLS. Las reservas se leen con el UID de sesión y mantienen las políticas de propietario documentadas en 3.17.3. Las pruebas SQL existentes terminan en `ROLLBACK`; no se repitieron porque Docker local no estaba activo y esta fase no creó SQL. No se infiere seguridad de suspensión a partir de un cambio visual o de `account_status`.

## I. Migraciones

`supabase migration list`: 31 versiones locales y remotas coincidentes, incluidas `20260923185000`, `20261003000000` y `20261003181310`, que los reportes anteriores marcaban pendientes. `supabase db push --dry-run`: remoto al día, cero migraciones/semillas/roles por aplicar. No se ejecutó `migration repair`, `db push` real ni `--include-all`.

## J. Producción

`deploy-production.ps1` valida antes del build `APP_ENVIRONMENT=production`, URL HTTPS no local, key Supabase no vacía y URL pública canónica (la completa si falta en el archivo local). Después exige que `main.dart.js` contenga la URL configurada y carezca del aviso de Supabase sin configurar y de URL localhost. El fallback de desarrollo quedó fuera del build de producción; ante configuración faltante en producción, bootstrap falla explícitamente.

Estrategia del repositorio: `lib`, `web`, `assets` y `pubspec*` son fuentes; `build/web` es salida ignorada; `vercel_output` es salida generada y versionada; Vercel despliega `vercel_output`. El script recompila, vacía y copia esa salida. Un manifiesto SHA-256 enlaza las fuentes y `main.dart.js`; `vercel.json` ejecuta el verificador para rechazar un commit con salida obsoleta. La ejecución local con `-SkipVercel -SkipGit` generó y verificó el artefacto actual. Un commit o edición posterior de fuentes requiere repetir el script antes de cualquier deploy.

Configuración local de producción, comprobada sin imprimir valores: APP_ENVIRONMENT, SUPABASE_URL y SUPABASE_PUBLISHABLE_KEY están definidos; `PUBLIC_SITE_URL` se completa con el valor canónico. CONTACT_EMAIL, CONTACT_WHATSAPP, SENTRY_DSN y PostHog no están configurados. Sentry usa `sendDefaultPii=false` y PostHog solo envía nombre de evento y un identificador aleatorio de sesión cuando se habilitan. Falta definir un canal real de contacto de producción.

## K. Queries optimizadas

- Favoritos: N consultas por tarjeta → una consulta batch de IDs por UID; la mutación invalida Saved, el set de IDs y la tarjeta afectada, sin recargar Explorar.
- Disponibilidad: una consulta anual reutilizada al reabrir calendario el mismo día; resumen reutiliza la consulta por rango al cambiar huéspedes o mensaje.
- Búsqueda: 350 ms de debounce en Explorar y Usuarios. Negocios admin consulta al enviar la búsqueda; categorías filtra el catálogo ya cargado.

## L. Tests

Pruebas focalizadas de detalle de reservas, cambio de UID, guardas y transición de logout pasan. Corridas completas: 413 tests aprobados, `flutter analyze --no-pub` sin problemas, `dart format --output=none --set-exit-if-changed lib test` correcto, UTF-8 correcto, `git diff --check` código 0 y `flutter build web --release` correcto con parámetros de producción. La salida Vercel verifica huellas de fuentes y bundle. No hubo E2E autenticado con cuentas reales ni medición de red en navegador.

## M. Pendientes para Claude

Continuar la pasada visual de la fase 3.20 sin cambiar los contratos de rutas de detalle ni el estado funcional de logout. Las ediciones visuales concurrentes se conservaron y quedaron incluidas en el build local verificado. Verificar visualmente detalle de reserva con datos reales, estados cargando/error y footer en móviles.

## N. Pendientes técnicos posteriores

- Administración de usuarios: RPC segura de detalle, edición, roles, suspensión/reactivación y auditoría; confirmar cómo impedir acceso de sesiones ya emitidas y cubrir todas las políticas RLS.
- Pruebas E2E con cuentas reales de cambio de cuenta, admin, solicitudes en cuatro verticales y actualización entre dispositivos.
- Medición real de tiempos/request count para Home, Explorar, calendario y panel admin, más tamaño/uso de imágenes. Supabase Storage puede requerir configuración de transformación antes de servir variantes pequeñas.
- Revisión funcional de RPC administrativas en producción con sesión autorizada, sin escritura; validación de políticas RLS y pruebas SQL transaccionales en local cuando Docker esté disponible.
- La navegación legal, borrador de onboarding y los estados de métricas conservan pruebas existentes, pero requieren QA manual en navegador con sesión real.
- Tras cambios estructurales de clases `const` en Flutter, usar **hot restart**; el mensaje «Const class cannot remove fields» es una limitación normal de hot reload.

**Resumen de validación:** 413 tests; analyze: limpio; UTF-8: OK; build web production: OK; migraciones locales pendientes: 0; migraciones remotas pendientes: 0; deploy realizado: **NO**; DB push realizado: **NO**.
