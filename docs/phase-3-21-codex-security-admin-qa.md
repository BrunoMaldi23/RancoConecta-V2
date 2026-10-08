# Fase 3.21 — seguridad, administración y QA técnica (Codex)

Fecha: 2026-10-04. Trabajo local en árbol compartido con Claude. Sin commit, push, DB push ni deploy.

## 1. Bugs corregidos

- El acceso prestador terminaba en `/provider/dashboard` o en un `next` del wizard. Ahora termina en `/account` tras resolver Auth y perfil.
- La confirmación de correo del registro prestador apuntaba a `/provider/register`. Ahora `emailRedirectTo` apunta a `/account` en el origen configurado.
- Cuenta podía presentar temporalmente una cuenta cliente o un estado de error mientras se resolvía el negocio. Espera el resultado de `activeProviderBusinessProvider` antes de construir el contenido; Bootstrap no considera el contexto proveedor cuando aún no hay usuario.
- `create_business_draft` insertaba otro negocio por cada llamada. La nueva definición usa bloqueo transaccional por UID y devuelve el borrador existente.
- Las notificaciones de revisión solo consultaban `business_members`; ahora incluyen `businesses.owner_id` y eliminan duplicados. Nuevos triggers crean eventos desde inserciones/cambios reales de solicitudes y reservas. El trigger de solicitudes complementa el RPC existente solo para propietarios sin membresía, evitando el doble aviso.
- El historial de auditoría estaba vacío aunque `audit_logs` recibía filas y RLS no permitía leerlas. Ahora el administrador activo puede leer y la pantalla muestra las 50 acciones recientes.

## 2. Flujo prestador

- `/provider/sign-in` ofrece el CTA «Ser parte de Ranco Conecta»; el login válido aterriza en Cuenta.
- El registro nuevo marca `provider_registration` en el alta Auth. El trigger crea un perfil `provider` antes del negocio. Una cuenta cliente existente puede elegir explícitamente el alta prestador mediante `register_provider_identity`.
- La migración convierte a `provider` las cuentas históricas `customer` que ya son propietarias o administradoras activas de negocios. `current_user_is_provider` exige el rol almacenado; el cliente común no puede crear un borrador.
- Ruta canónica: `/provider/business`. `/provider/status` y `/provider/dashboard` son alias que redirigen allí. `/provider/register` permanece como subflujo explícito del asistente. El hub muestra estado o panel publicado según el contexto del negocio.
- El asistente no abre automáticamente después del login. La migración garantiza reutilización de borrador incluso con llamadas paralelas.

## 3. Auth

- Se conserva la secuencia sesión → perfil → negocio y el estado de carga durante esa resolución. El logout de 3.19 sigue invalidando las cachés privadas y llevando a `/sign-in`.
- El registro y el retorno de confirmación usan `/account`; la recuperación de contraseña mantiene el retorno a Seguridad y acceso.
- Configuración local: `supabase/config.toml` incluye `https://www.rancoconecta.cl` y redirects para ese dominio y `127.0.0.1:3000`. `enable_confirmations = false` en desarrollo. **No se verificó la allowlist ni una confirmación real en el panel remoto.**

## 4. Cuenta y hub

- Cuenta espera el negocio antes de decidir el rol visible y muestra nombre, tipo y estado en la tarjeta del prestador. «Gestionar negocio» abre `/provider/business`.
- El hub y el asistente visual de Claude se conservaron. Las secciones por vertical se basan en capacidades reales; las que carecen de pantalla quedan identificadas como próximas.
- El footer usa un sliver al final del scroll con espacio flexible hasta el fondo en páginas cortas. Claude lo verificó en pruebas de página corta y larga; no se cambió su diseño desde esta pasada técnica.

## 5. CRUD admin users

- Ya existían listado, búsqueda paginada, filtros Todos/Usuarios/Visitantes/Prestadores/Administradores y detalle. Se añadió cambio de rol por RPC con confirmación, mensajes de error humanos e invalidación de lista/perfil.
- Se añadió suspensión/reactivación por RPC con confirmación y auditoría. No hay borrado duro de `auth.users`.
- Los controles de mutación consultan `admin_user_mutations_ready`. Si el backend aún no tiene la migración, quedan deshabilitados en vez de llamar RPC inexistentes. En remoto están deshabilitados hasta aplicar las migraciones.
- La RPC de rol exige administrador activo, impide autoescalado, cuentas anónimas, cambio de `super_admin`, promoción de cuentas no activas y pérdida del último admin activo. Una cuenta con negocio propio o membresía de gestión no puede cambiar a `customer` ni a `admin`.

## 6. Suspensión y RLS

- `account_status` se comprueba contra la fila actual de `profiles` en cada petición Data API mediante `pgrst.db_pre_request`; cubre también RPC `SECURITY DEFINER` con JWT emitido anteriormente.
- Políticas RLS restrictivas sobre las tablas públicas protegidas y `storage.objects` deniegan filas privadas a una sesión suspendida. Las RPC de alta de proveedor y negocio exigen cuenta activa. La suspensión protege al último admin y rechaza la autosuspensión.
- Prueba local de API: **el mismo JWT** lee `profiles` activo; tras suspender la cuenta, la lectura y `notification_list` devuelven `ACCOUNT_SUSPENDED`. La prueba SQL confirma que no puede leer su negocio ni crear otro y que el admin puede reactivar y auditar.
- Este bloqueo aún **no está vigente en remoto** porque las migraciones 3.21 no se han aplicado. Falta comprobar Auth, Storage y Realtime con cuentas reales en remoto tras la migración.

## 7. Categorías

- Se preservan CRUD, desactivación/reactivación y `CATEGORY_IN_USE` del backend previo. Un trigger nuevo registra creación, edición, desactivación, reactivación y borrado permitido en `audit_logs`.
- El selector editorial con búsqueda de Claude evita un dropdown de 27 elementos sin cambiar el contrato de categorías activas.

## 8. Solicitudes

- Cliente: se conservó el agregado de `service_requests`, `lodging_bookings` y `gastronomy_table_reservations`, con rutas de detalle específicas. Turismo sigue el contrato real de solicitud de servicio.
- Prestador: la cola `/provider/requests` continúa siendo de servicios y se limita al negocio activo mediante RPC; alojamiento y gastronomía tienen pantallas propias de reservas con RLS de gestor. **Falta una fuente multivertical única para el prestador** y una prueba real de cada vertical.
- Se revisaron los filtros existentes y las rutas de detalle; no se añadieron pestañas para semánticas no implementadas.

## 9. Notificaciones

- La lectura filtra por `notifications.user_id = auth.uid()`, Realtime invalida lista y contador, y el canal se cierra al cambiar sesión.
- Nuevos eventos se basan en filas reales: solicitud dirigida, reserva de alojamiento, reserva de mesa y cambios de estado aceptado/rechazado o confirmado/rechazado. Propietario y gestores activos se deduplican. Se retiró el permiso de invocación directa al helper privilegiado `notify_business_managers`.
- Falta QA con dos dispositivos para latencia Realtime, permisos y enlaces profundos. No se insertaron notificaciones ficticias.

## 10. Optimización

- Se conservaron consulta batch de favoritos, caché de calendario y debounce de 350 ms en Explorar/Usuarios. El hub reutiliza providers del negocio; Cuenta espera una sola resolución de negocio.
- Auditoría consulta un máximo de 50 filas ordenadas; necesita paginación para crecer. No hubo mediciones de latencia ni tamaño de imágenes con datos reales.

## 11. Tests y validaciones

- `dart format lib test`: correcto.
- `flutter analyze --no-pub`: sin issues.
- `flutter test`: **462/462** aprobadas en la corrida completa final.
- `scripts/check_text_encoding.ps1`: OK. `git diff --check`: código 0.
- `flutter build web --release`: OK. `deploy-production.ps1 -SkipVercel -SkipGit`: checks, build y sincronización local correctos. `node scripts/verify-vercel-output.mjs`: OK tras sincronización.
- Base local: 13 migraciones nuevas aplicadas con `supabase migration up --local`. `phase_3_17_admin.sql`, `phase_3_17_3_requests.sql` y `phase_3_21_security_flow.sql` pasan con `ROLLBACK`; `phase_3_21_api_gate.py` pasa contra la Data API local.
- Remoto, solo lectura: las firmas `admin_search_business_reviews`, `admin_list_business_reviews`, `admin_search_users` y `admin_list_categories` responden con autorización denegada, no `PGRST202`. Las 13 migraciones nuevas siguen solo locales.
- Producción: `.env.production.local` contiene APP_ENVIRONMENT, SUPABASE_URL y SUPABASE_PUBLISHABLE_KEY; el script validó URL HTTPS y `PUBLIC_SITE_URL` canónica. CONTACT_EMAIL, Sentry y PostHog no están definidos.

## 12. Matriz de QA funcional

| Rol | Escenario | Evidencia actual | Pendiente real |
| --- | --- | --- | --- |
| Visitante | Explorar, buscar, guardar | Widgets y rutas existentes; 462 tests completos | Navegador con datos y cuenta real |
| Visitante | Solicitud, alojamiento, mesa, detalle, logout/login | Contratos y tests de reservas/solicitudes; RLS previa | Ciclo real en dos cuentas |
| Prestador | Registro, correo, login, Cuenta | Login→Cuenta y redirect probados en widget; identidad SQL probada | Confirmación de correo real y allowlist remota |
| Prestador | Borrador, continuar, enviar revisión | Reutilización SQL probada; hub y asistente en tests de widget | Envío real y cambio de estado remoto |
| Prestador | Gestionar publicado y recibir actividad | Rutas por vertical; pruebas de layout | Solicitud/reserva real en cada vertical, fuente multivertical |
| Admin | Dashboard, usuarios, roles, suspensión | RPC y RLS transaccionales locales, API con JWT anterior | Aplicar migraciones y QA autenticada remota |
| Admin | Categorías, negocios, revisión, auditoría | CRUD y transiciones existentes; firmas RPC remotas; auditoría local | Acciones reales con cuenta admin remota |
| Admin | Analítica | UI y consulta existente | Medición/consistencia con datos reales |

## 13. Pendientes reales y bloqueadores pre-beta

1. Aplicar y verificar las **13 migraciones 3.21** en remoto mediante una operación posterior autorizada; esta fase prohibió DB push. Hasta entonces CRUD de usuarios, RLS de suspensión, rol prestador y nuevos eventos no están activos allí.
2. Probar con cuentas reales la confirmación de correo, Site URL/redirect allowlist, cambio de sesión, suspensión con sesión emitida, Storage, Realtime y enlaces de notificaciones.
3. Consolidar actividad multivertical del prestador y completar QA de reservas/solicitudes entre cliente y negocio.
4. Verificar rendimiento de red e imágenes con datos reales; definir CONTACT_EMAIL y decidir Sentry/PostHog antes de publicar.
5. Paginar la pantalla de auditoría y verificar historial con múltiples administradores. Medir y revisar las funciones administrativas en sesión autenticada tras desplegar migraciones.

**Estado:** base local y bundle verificados; remoto sin cambios. La pre-beta todavía no está lista para declarar cierre funcional o de seguridad.
