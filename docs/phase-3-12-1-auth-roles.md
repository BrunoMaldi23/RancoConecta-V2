# Fase 3.12.1: sesión y separación de admin/proveedor

Fecha: 1 de octubre de 2026. No se desplegó a Vercel ni se modificaron filas de usuarios, negocios, propietarios, membresías o estados.

## Causas encontradas

1. `SupabaseAuthRepository.observeAuthState()` emitía de inmediato una instantánea de `currentSession` que podía ser `null` antes del evento `INITIAL_SESSION`. `currentProfileProvider` no dependía del estado auth y podía cachear el error «Debes ingresar para ver tu perfil» durante esa ventana. El router registraba `NO_SESSION` al leer ese valor temporal.
2. `ProviderContext` consultaba `myProviderBusinessesProvider` para cualquier usuario autenticado. El repositorio llamaba `my_manageable_businesses()`: esa función sí filtraba por `auth.uid()` mediante `businesses.owner_id` o membresía `owner`/`manager`, pero no excluía el rol admin. Por tanto, `MANAGEABLE_BUSINESSES_COUNT count=6` **no era un SELECT global por RLS**: indica seis filas asociadas al UID por alguna de esas dos relaciones. Sin una sesión admin o consulta SQL autorizada no se puede precisar cuál relación vincula cada fila.
3. `activeProviderBusinessProvider` elegía el primer negocio retornado o reutilizaba `activeProviderBusinessIdProvider`. Así llegó a seleccionar Gasfitería Lago Ranco. El ID informado por el usuario es `33595129-2e00-4abb-bb72-61c5f5b9f990`; su propietario real aún no se verificó de forma independiente.

## Corrección

- El stream de auth espera el evento de Supabase, que se emite después de restaurar la sesión local. `AuthPhase` distingue inicializando, autenticado, anónimo, sin sesión y error. El perfil espera el primer estado auth resuelto y se invalida al cambiar la identidad. La comparación del stream conserva también cambios de anonimato, correo y confirmación aun si el ID no cambia.
- Admin y superadmin salen del contexto proveedor antes de consultar negocios. Para ellos la lista propia es vacía, el negocio activo es nulo y la selección previa se limpia. Cuenta, drawer, sidebar, topbar y navegación móvil no muestran «Mi negocio». `/provider/*` redirige a `/admin` para un admin autenticado. El guard de `/admin` mantiene la comprobación explícita de rol.
- El rol `provider` puede gestionar negocios asociados por `owner_id` o membresía activa `owner`/`manager`. Un perfil `customer` que ya tiene esa asociación conserva una capacidad operativa de proveedor; esto mantiene el onboarding existente sin convertir al admin en proveedor. Un cliente autenticado puede iniciar un borrador mediante la acción explícita de registro. La lista global admin sigue consultándose por las RPC administrativas, separada de `my_manageable_businesses()`.
- La migración `20261001220000_separate_admin_provider_context.sql` añade la comprobación de rol/capacidad en `my_manageable_businesses()` y `user_can_manage_business()`, además de proteger el RPC de creación de borrador, políticas antiguas basadas solo en owner, alojamiento, solicitudes, objetos de media y aceptación/rechazo de reservas. No desactiva RLS ni cambia el contrato de la cola administrativa.
- El cierre de sesión existente invalida perfil, listas y contexto proveedor y limpia el ID de negocio activo. La dependencia de auth invalida esos providers también al cambiar el usuario sin reutilizar el negocio anterior.
- Los logs debug muestran eventos de arranque, sesión, rol, contexto omitido y cantidad propia sin tokens, contraseñas ni IDs de negocio.

## Verificación

- La migración se aplicó en Supabase; las 28 versiones locales y remotas coinciden y `db push --linked --dry-run` informó base al día.
- Pruebas de widget y provider: Cuenta en inicialización, sesión restaurada y ausencia real de sesión; cambio de usuario; admin con ownership histórico; negocio propio de proveedor; selección ajena invalidada; customer con ownership; rutas admin/proveedor y preservación de `next` en bootstrap con router real; logout proveedor que limpia la selección. La suite completa pasó: 203 pruebas.
- `scripts/deploy-production.ps1 -SkipGit -SkipVercel` pasó codificación, formato, `flutter analyze --no-pub`, suite de pruebas, `git diff --check` y `flutter build web --release`. El bundle quedó en `vercel_output` local, sin publicación.
- El panel admin y el listado global conservaron sus pruebas existentes. El usuario confirmó en su sesión local actualizada que Cuenta admin ya no muestra «Mi negocio» y que `/admin/businesses` carga. No se comprobó visualmente el detalle de los dos pendientes ni una cuenta proveedor real.

## Pendientes reales

1. En la sesión local de `admin@lagoranco.cl`, confirmar los logs `AUTH_INITIAL_SESSION_RESOLVED`, `AUTH_ROLE_RESOLVED role=admin` y `PROVIDER_CONTEXT_SKIPPED role=admin`, y revisar que los dos pendientes aparecen. Cuenta sin «Mi negocio» y el listado que carga ya fueron confirmados por el usuario. La herramienta de acceso a esa ventana había fallado en la fase anterior y no hay credenciales admin en este entorno.
2. Con una cuenta proveedor existente, confirmar que solo aparecen sus negocios y que solicitud, servicios y reservas siguen operativos. Probar logout de proveedor y login admin en el navegador real.
3. Auditar con una consulta administrativa autorizada las asociaciones históricas de la cuenta admin y el propietario real de Gasfitería Lago Ranco. No se reasignó ni borró ningún registro. Una consulta previa con prefijos de IDs de propietario fue rechazada por la revisión automática; no se intentó eludir esa decisión.
4. La validación visual local debe preceder cualquier despliegue a Vercel.
