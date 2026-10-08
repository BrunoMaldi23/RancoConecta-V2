# Fase 3.20 — estabilización técnica pre-beta (Codex)

Fecha: 2026-10-03. Trabajo sobre el árbol local compartido con la pasada visual de Claude. Sin deploy, DB push ni commit.

## Auditoría y causas

- Revisé `git status`, los últimos cinco commits, el reporte 3.19, el router, Auth, perfil, onboarding, solicitudes, reservas, repositorios administrativos y migraciones antes de editar. El árbol ya contenía trabajo sin commit de 3.19 y de Claude; se conservó.
- El registro enviaba la confirmación de correo a `/`. Eso perdía el destino `/provider/register` del nuevo prestador. El destino ahora se pasa a Supabase Auth mediante `emailRedirectTo`; la URL base sigue la configuración de producción/desarrollo existente.
- El acceso proveedor navegaba inmediatamente tras `signIn`, mientras el stream Auth podía conservar momentáneamente el UID previo. El router también trataba `/provider/sign-in` como ruta que necesitaba perfil. Ahora el login escucha el UID nuevo en el provider canónico y espera la carga del perfil sin reiniciar el stream Auth; la guarda de perfil se limita a rutas de gestión proveedor. La carrera se identificó por inspección y se cubrió con pruebas de perfil demorado y de permanencia en `/provider/sign-in`. No se reprodujo el error de producción con una cuenta real.
- La consulta de perfil usaba el usuario mutable de Supabase dentro del repositorio. Ahora recibe el UID resuelto por Riverpod y rechaza una sesión que no coincida, evitando consultar el perfil de otra cuenta.
- El CTA secundario «Ya tengo una cuenta» de `/provider/join` ya había sido retirado por Claude antes de esta intervención. Se conservó y se verificó con su prueba.
- Un cambio concurrente en la tabla admin produjo un overflow de 2,3 px en la columna de acciones. Se amplió esa columna y volvió a pasar la prueba responsive. `vercel_output/assets/NOTICES`, generado por Flutter, contiene espacios finales propios de licencias de terceros; `.gitattributes` excluye solo ese artefacto de la comprobación de whitespace.

## Archivos tocados por esta pasada técnica

`lib/features/auth/data/supabase_auth_repository.dart`, `lib/features/auth/presentation/sign_in_screen.dart`, `lib/features/profile/application/profile_providers.dart`, `lib/features/profile/data/profile_repository.dart`, `lib/router/app_router.dart`, `lib/features/admin/presentation/admin_settings_screens.dart`, `test/access_flow_test.dart`, `test/auth_provider_separation_test.dart`, `test/ranco_navigation_drawer_test.dart`, `test/admin_phase_3_2_test.dart` y `.gitattributes`. La regeneración local actualizó `vercel_output`. Los demás cambios preexistentes del árbol pertenecen a las fases 3.19 y 3.20 visual.

## Rutas y flujo proveedor

`/sign-in` ofrece exploración pública y entrada de prestador. `/provider/sign-in` ofrece correo, contraseña y recuperación, además de «Publicar mi negocio» para quien aún no tiene acceso. Este CTA abre `/provider/join`; «Comenzar publicación» abre `/sign-up?next=/provider/register`. El registro pide nombre, correo, contraseña, confirmación y los tres consentimientos. Con confirmación requerida muestra «Revisa tu correo para continuar» y el enlace de confirmación vuelve a `/provider/register`. El registro Auth mantiene el rol inicial `customer`; publicar un negocio continúa sujeto al flujo de revisión existente.

La base de redirección de producción proviene de `PUBLIC_SITE_URL` (`https://www.rancoconecta.cl`); desarrollo usa el origen local. Debe confirmarse en el panel de Supabase que Site URL y Redirect URLs admiten el dominio y `/provider/register`. No hay acceso administrativo de Auth para verificar esa allowlist remotamente desde esta sesión. Tampoco se completó una confirmación real de correo en producción.

## Sesión y datos privados

El logout existente de 3.19 usa `signingOutProvider`, termina Auth, invalida perfil, favoritos, solicitudes, notificaciones, contexto proveedor y estado admin, y lleva a `/sign-in`. El test de router cubre la ocultación de `/admin` antes de que termine el stream Auth. El perfil ahora queda ligado al UID resuelto. La prueba nueva retiene artificialmente el perfil tras login y confirma que el panel proveedor no se abre antes de cargarlo. Siguen pendientes pruebas E2E con cuentas reales admin → prestador → admin y cliente → otro cliente.

## Solicitudes, rendimiento, legal y footer

Se confirmó la fuente unificada existente para servicio, alojamiento y gastronomía, con turismo clasificado por tipo de negocio; las creaciones invalidan `myCustomerActivityProvider`. No se modificó ownership: una solicitud de UID anónimo permanece en ese UID. El calendario conserva la caché por rango y el listado mantiene favoritos en batch y debounce, según la fase 3.19. No se midieron latencias ni recuentos de red con sesión real.

Los enlaces legales entre páginas usan `context.push` y conservan el stack. Las pantallas públicas principales usan footer en el scroll normal; las pruebas responsive cubren 390, 768, 1024, 1366 y 1600 px, entre otros anchos. No se rediseñó el footer ni las pantallas.

## Administración, RPC y RLS

Usuarios mantiene búsqueda, filtros por rol y anonimato real (`auth.users.is_anonymous`) y paginación en servidor mediante `admin_search_users`. La lista permite abrir detalle solo con los campos ya devueltos por esa RPC: nombre, correo, rol, estado y fecha. Las opciones de cambiar rol y suspender/reactivar quedan deshabilitadas hasta disponer de backend seguro; no se escribió `auth.users` desde Flutter ni se implementó hard delete.

Una suspensión que solo cambie `profiles.account_status` no revoca tokens existentes ni cubre necesariamente todas las políticas RLS. Antes de activarla se necesitan revocación/bloqueo de Auth, aplicación consistente del estado en políticas privadas, validaciones de último admin y negocios proveedor, y auditoría transaccional. El disparador actual `protect_profile_privileged_fields` también impide cambios de rol/estado directos de cliente. No se añadió una RPC insegura ni una migración parcial.

El frontend usa `admin_search_business_reviews`, `admin_list_categories` y `admin_search_users`, presentes en las migraciones locales incluidas en el historial remoto. Los errores RPC siguen siendo errores visibles, no listas vacías. Falta una llamada autenticada de administrador a producción para confirmar la definición y caché PostgREST efectivas. Categorías CRUD y sus guardas permanecen como en 3.19.

## Migraciones y producción

`npx supabase migration list`: 31 versiones locales y remotas coincidentes. `npx supabase db push --dry-run`: remoto al día, cero migraciones, seeds y roles pendientes. No se hizo push, reparación ni mutación SQL remota.

El script de producción valida defines, compila Flutter, comprueba el bundle y copia `build/web` a `vercel_output`; Vercel sirve `vercel_output`. El build release genérico y las comprobaciones de formato/análisis/UTF-8 pasaron. Las primeras regeneraciones locales de producción se detuvieron por ediciones concurrentes de UI o pruebas cambiando durante la ejecución; el verificador de huellas impidió marcar un bundle obsoleto como vigente. La ejecución final con `-SkipVercel -SkipGit` terminó correctamente y `node scripts/verify-vercel-output.mjs` confirmó la huella de fuentes y bundle.

## Pruebas y pendientes

Se añadieron/actualizaron pruebas de destino de correo proveedor, espera del perfil tras login, permanencia del router en `/provider/sign-in`, destino del panel proveedor y detalle de usuario admin. Las pruebas existentes cubren rutas de visitante, logout, requests, categorías, navegación legal y tamaños responsive. No hubo pruebas SQL nuevas ni datos reales modificados.

Pendientes: cierre real del CRUD de usuarios con Auth/RLS/auditoría, verificación remota autenticada de RPC y redirect allowlist, E2E de confirmación de correo y cambio de cuentas, medición de red/latencia real, y QA visual de Claude sobre los estados de carga/error. Una modificación estructural de clases `const` puede requerir hot restart durante desarrollo.

## Validación final

- Tests: 425 aprobados en `flutter test` durante la generación local final.
- Analyze: sin issues.
- UTF-8: OK.
- Formato: OK.
- `git diff --check`: OK tras excluir únicamente el archivo de licencias generado.
- Build: `flutter build web --release` OK; build de producción local y `vercel_output` verificado OK.
- Migraciones locales pendientes: 0. Migraciones remotas pendientes: 0.
- DB push: NO.
- Deploy: NO.
- Commit: NO.
