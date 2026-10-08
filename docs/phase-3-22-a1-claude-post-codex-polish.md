# MICROFASE 3.22A.1 — Consistencia visual post-Codex (Claude)

Fecha: 2026-10-04 · Solo presentación y UX. Sin cambios en Supabase, lógica de auth,
callback, router, RLS, RPC ni migraciones. Sin deploy, commit ni push.

Validaciones: `dart format --output=none --set-exit-if-changed lib test` (0 cambios) ·
`flutter analyze --no-pub` sin issues · `flutter test` **506/506** (12 nuevos en
`test/phase_3_22_a1_post_codex_test.dart`) · `check_text_encoding.ps1` OK ·
`git diff --check` código 0 · `flutter build web --release` OK.

## Alcance revisado

Archivos de Codex posteriores a 3.22A: ninguno en `lib/` ni `test/`. Los cambios 3.22B
posteriores fueron SQL (`20261004134000`–`20261004141000`, `phase_3_22_admin_contracts.sql`)
y `ResetPasswordScreen` (13:41, en `sign_in_screen.dart`). Revisé además qué datos nuevos
expone esa SQL a la UI.

## 1. ResetPasswordScreen (`/reset-password`)

Antes: formulario sin subtítulo, sin mostrar/ocultar, sin estado de guardado visible en
el botón, spinner de página en carga, "enlace caducado" como texto suelto y, tras guardar,
salida inmediata al ingreso sin confirmación.

Ahora (misma pieza visual que Crear acceso y Recuperar contraseña):
- Columna de 460 px; tarjeta con sombra suave en ≥ 600 px, superficie plana en móvil;
  emblema Ranco Conecta 52 px; pie "Ranco Conecta · Lago Ranco".
- **Crear nueva contraseña** + "Elige una contraseña para volver a ingresar a tu cuenta."
- Nueva contraseña y Confirmar contraseña con íconos; **mostrar/ocultar** (un solo control
  para ambos, con tooltip).
- Requisito visible en vivo **"Al menos 8 caracteres"** (es la regla que ya validaba el
  formulario; no se agregaron reglas).
- **Guardar contraseña** de 50 px con spinner y "Guardando…".
- Error en línea con el mensaje humano que entrega el repositorio
  (p. ej. "El enlace caducó. Solicita uno nuevo."), nunca el detalle técnico.
- **Éxito**: transición corta (fade + size, 250 ms) a **"Contraseña actualizada"** —
  "Por seguridad cerramos esta sesión. Ingresa con tu nueva contraseña." Se muestra
  mientras corre el **mismo** `signOutAndGoToSignIn(destination: '/provider/sign-in')` que
  implementó Codex, llamado en el mismo momento (no se retrasó el cierre de sesión). Al
  llegar al ingreso aparece un snackbar de 5 s "Contraseña actualizada. Ingresa con tu nueva
  contraseña." (se detecta la navegación por la ubicación del router, porque la pantalla
  sigue montada durante la transición). Si el cierre de sesión fallara, el helper ya
  muestra su aviso y la vista ofrece **"Ir a iniciar sesión"** para reintentar.
- **Enlace caducado o usado**: ícono, título, explicación breve, **Solicitar otro enlace**
  y "Volver a iniciar sesión". El éxito tiene prioridad sobre este estado (al cerrar
  sesión `auth` queda vacío y antes se habría visto "caducó" un instante).
- **Carga de sesión**: esqueleto con la forma del formulario en vez de spinner.

## 2. Datos nuevos de 3.22B reflejados en la UI
- Estado de cuenta **`blocked`** (nuevo en `admin_search_users`): se mostraba crudo
  ("blocked"). Ahora "Bloqueado" con tono rojo suave (`RancoStatusBadge`) en tabla,
  tarjeta y detalle de usuarios.
- Auditoría de configuración **`admin_settings_updated` / `system_settings`**: etiqueta
  "Configuración actualizada", recurso "Configuración" (sin " · —" cuando la fila no trae
  ID) y nuevo filtro de recurso **Configuración**. El control de recurso ahora es flexible
  y se desplaza en horizontal si no cabe (corrige un desborde de 10 px a 1280 px que
  apareció con la quinta opción).

## 3. Otras vistas auditadas (sin cambios necesarios)
- Admin › Usuarios: detalle, menú y estados de suspensión/reactivación ya alineados en
  3.22A con las acciones reales de Codex (`admin_user_mutations_ready`).
- Admin › Configuración: el guardado ahora queda auditado en backend; la UI no cambia.
- Auth callback/bootstrap (`BootstrapScreen` en `app_router.dart`): fuera de alcance por
  ser router; ver pendientes.

## Archivos modificados
- `lib/features/auth/presentation/sign_in_screen.dart`: solo `_ResetPasswordScreenState`
  (+ `_ResetSkeleton`). Lógica de `updateRecoveredPassword`, validadores y helper de cierre
  de sesión intactos.
- `lib/features/admin/presentation/admin_settings_screens.dart`: etiqueta/tono `blocked`.
- `lib/core/widgets/ranco_status_badge.dart`: "bloqueado" → tono danger.
- `lib/features/admin/presentation/admin_audit_view.dart`: acción/recurso de
  configuración, filtro y texto de recurso sin ID, filtros flexibles.
- Nuevos: `test/phase_3_22_a1_post_codex_test.dart`, este documento.

## Tests
`phase_3_22_a1_post_codex_test.dart` (12): formulario en 390/768/1024/1366/1600,
mostrar/ocultar + requisito en vivo, contraseñas distintas sin llamar al backend, error
amigable sin cerrar sesión, éxito visible durante el cierre de sesión + aviso en el ingreso,
enlace caducado → solicitar otro, esqueleto de carga, etiquetas 3.22B. Barridos existentes
en verde.

## Pendientes para Codex
1. `BootstrapScreen` (router): usa spinner centrado, colores literales y muestra
   "build x · sha · fecha" al usuario final; sugerencia: esqueleto/emblema y ocultar la
   línea de build fuera de desarrollo.
2. Filtro por estado de cuenta: `admin_search_users` ya acepta `p_status`; si se expone en
   `adminUsersProvider`, la UI puede sumar un filtro Activas/Suspendidas/Bloqueadas.
3. Distinción visual suspendida vs. bloqueada: definir si "bloqueado" tiene acción de
   reactivación propia (hoy el menú solo conoce suspender/reactivar).

## Pendientes visuales posteriores
- QA en navegador con un enlace de recuperación real (estado caducado y éxito).
- Revisar el snackbar de confirmación sobre `/provider/sign-in` con su layout real.
