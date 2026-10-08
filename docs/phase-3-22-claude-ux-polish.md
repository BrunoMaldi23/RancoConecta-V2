# FASE 3.22A — Refinamiento UX/UI de pantallas restantes (Claude)

Fecha: 2026-10-04 · Solo UX/UI, responsive, estados y microinteracciones. Sin cambios en
Supabase, RLS, RPC, migraciones, permisos, contratos de datos ni lógica sensible. Sin
deploy, sin commit, sin push.

Validaciones: `dart format --output=none --set-exit-if-changed lib test` (0 cambios) ·
`flutter analyze --no-pub` sin issues · `flutter test` **494/494** (30 nuevos en
`test/phase_3_22_ux_polish_test.dart`) · `check_text_encoding.ps1` OK ·
`git diff --check` código 0 · `flutter build web --release` OK.

> **Trabajo en paralelo con Codex.** Antes de editar revisé cada archivo compartido.
> Codex había dejado (13:04) mutaciones reales de usuarios (`admin_user_mutations_ready`,
> cambio de rol, suspensión) y lectura real de auditoría (`adminAuditEventsProvider`, 50
> filas). Durante esta fase agregó la ruta `/reset-password` y `ResetPasswordScreen` en
> `sign_in_screen.dart`; mi rediseño de `ForgotPasswordScreen` en el mismo archivo se
> conservó (verificado tras su escritura). No toqué sus callbacks, RPC ni el router.

## Cambios implementados

### 1. Recuperar contraseña (`/forgot-password`)
- Mismo lenguaje que Crear acceso: botón volver de 44 px, columna de 460 px, tarjeta con
  sombra suave en ≥ 600 px y superficie plana en móvil, emblema Ranco Conecta (52 px).
- Jerarquía: **Recuperar contraseña** → "Ingresa el correo asociado a tu cuenta." → campo
  Correo con label → **Enviar instrucciones** (50 px, spinner en el botón) → "Volver a
  iniciar sesión".
- **Estado de éxito en la misma vista** (fade + size, 250 ms): ícono de correo,
  **Revisa tu correo**, texto neutro que no confirma si la cuenta existe ("Si hay una
  cuenta asociada a *correo*…", incluye spam), **Volver a iniciar sesión**, **Reenviar
  correo** (repite la llamada existente `sendPasswordResetEmail`; confirma con snackbar
  compacto) y **Usar otro correo**. No existía lógica de enmascarar el correo; se muestra
  el que el usuario escribió para detectar errores de tipeo.
- Errores del backend aparecen junto al formulario, sin perder lo escrito.

### 2. Admin › Usuarios (`/admin/users`)
- **Sin saltos al filtrar o buscar**: buscador y segmentos quedan fuera del estado de
  carga (antes toda la vista se reemplazaba por el esqueleto y el buscador perdía el
  foco). Mientras llega la nueva página se mantiene la anterior atenuada (opacidad 55 %)
  con un indicador lineal de 72 px; el esqueleto solo aparece en la primera carga.
- **Contador por filtro**: "2 cuentas", "1 administrador", "3 prestadores",
  "5 visitantes", "4 usuarios", más el término buscado.
- **Tabla**: columna Usuario con avatar de inicial, nombre (700) y correo secundario;
  Rol y Estado con el badge compartido; Registro con cifras tabulares; columna Acciones
  compacta (solo "⋯" centrado, la fila abre el detalle). Hover real: la tabla ahora es un
  `Material` (antes el `InkWell` pintaba bajo el fondo blanco y no se veía).
- **Responsive**: ≥ 980 px tabla completa; 720–980 px tabla compacta sin Registro;
  < 720 px tarjetas (avatar, nombre, correo, rol, estado y menú).
- **Menú ⋯**: Ver detalle · Cambiar rol · Suspender/Reactivar cuenta, con íconos. Las
  acciones bloqueadas se ven deshabilitadas **con su motivo debajo**: backend no
  habilitado (`AdminUserActions.unavailableHint`), cuenta de visitante, superadministrador,
  o tu propia cuenta ("No puedes suspender tu propia cuenta."). Son las mismas guardas que
  ya aplicaban la pantalla/RPC; solo se hacen visibles. El detalle muestra los mismos
  motivos y cierra el diálogo antes de abrir "Cambiar rol".
- Vacío específico: "Ninguna cuenta coincide con “…”" / "No hay cuentas en este filtro."
  + sugerencia. Error: `AdminErrorState` ("No pudimos cargar las cuentas." + Reintentar,
  sin detalle técnico).

### 3. Admin › Configuración (`/admin/settings`)
- Pestañas reales **General · WhatsApp · Notificaciones · Integraciones** con ícono,
  indicador verde de 2,5 px y badge **"Pronto"** separado del título. Cambio de sección
  con fade de 180 ms. No se hizo sticky: el contenido es corto y no hay scroll largo que
  lo justifique.
- **WhatsApp** separado en:
  - A. Estado: Activo/Inactivo · número · **Modo: Envío manual** (franja con borde suave).
  - B. Configuración: switch, número administrador, eventos, guardar (spinner en el
    botón; éxito por snackbar existente; error en línea con `AnimatedSize`).
  - C. Info box: "Ranco Conecta prepara el mensaje y el envío se confirma manualmente en
    WhatsApp."
  - D. Eventos: opciones con casilla + descripción breve, 2 columnas en ≥ 560 px.
  - E. "Eventos no disponibles (2)" en `ExpansionTile` compacto (180 ms), cerrado por
    defecto.
- **General / Notificaciones / Integraciones**: estado "Próximamente" con resumen y lista
  "Incluirá" (sin switches, campos ni casillas simuladas).
- Carga: las pestañas permanecen y debajo aparece un esqueleto con la forma real. Error:
  `AdminErrorState` específico.

### 4. Admin › Auditoría (`/admin/audit`)
Nueva vista `AdminAuditView` (archivo propio) sobre las filas reales de `audit_logs`:
- **Resumen en una línea**: badge "Registro activo", "Últimas N acciones" y chips de
  cobertura (Aprobaciones, Rechazos, Cambios de configuración, Gestión de usuarios). Sin
  tarjeta grande.
- **Filtros funcionales en el cliente** (sobre las ≤ 50 filas cargadas): Buscar (acción,
  recurso o ID), Recurso (Todo / Negocios / Cuentas / Categorías) y Fecha (Todo / Hoy /
  7 días / 30 días). **Actor no se filtra**: el backend solo entrega `actor_id` (UUID),
  sin nombre; no se inventó un filtro engañoso.
- **Tabla** Fecha · Actor · Acción · Recurso · Resultado (≥ 760 px) y **línea de tiempo**
  en móvil. Códigos traducidos (`business_published` → "Negocio publicado",
  `user_suspended` → "Cuenta suspendida", `category_*`, `user_role_changed`…; códigos
  nuevos se muestran legibles). Actor: "Usuario 1a2b3c4d" con UUID completo en tooltip, o
  "Sistema". Resultado derivado de la acción (Activo / Pendiente / Restringido /
  Registrado), porque el registro solo existe si la acción se completó.
- Paginación con el `AdminPaginator` compartido (10/20/50) sobre las filas filtradas.
- Estados: esqueleto con forma de tabla; vacío "No hay acciones registradas todavía.";
  sin coincidencias + "Limpiar filtros"; error compacto con Reintentar.

## 5. Estados y transiciones
| Vista | Loading | Error | Vacío | Éxito |
|---|---|---|---|---|
| Recuperar contraseña | spinner en el botón | mensaje en línea | — | estado "Revisa tu correo" + snackbar al reenviar |
| Usuarios | esqueleto (1ª carga) / página previa atenuada | `AdminErrorState` | específico por búsqueda/filtro | snackbars existentes (rol, suspensión) |
| Configuración | esqueleto bajo pestañas | `AdminErrorState` | "Próximamente" | snackbar existente |
| Auditoría | esqueleto de tabla | `AdminErrorState` | vacío / sin coincidencias | — |

Transiciones (150–250 ms, `RancoDurations`): formulario → éxito (fade + size), pestañas de
configuración (fade), resultados de usuarios y auditoría (`AnimatedSwitcher` 180 ms),
opacidad de recarga, error de guardado (`AnimatedSize`), acordeón (180 ms). Se corrigió
un indicador indeterminado que seguía animando oculto.

## Archivos modificados
- Nuevo: `lib/features/admin/presentation/admin_audit_view.dart`,
  `test/phase_3_22_ux_polish_test.dart`, este documento.
- `lib/features/auth/presentation/sign_in_screen.dart`: solo `_ForgotPasswordScreenState`
  (se eliminó `_ForgotPasswordHeader`, ya sin uso).
- `lib/features/admin/presentation/admin_settings_screens.dart`: `build` de Usuarios y de
  WhatsApp, tabla/tarjeta/menú/esqueleto/vacío de usuarios, guardas visibles
  (`adminRoleChangeBlockedReason`, `adminSuspensionBlockedReason`), pestañas y secciones
  de Configuración. `_changeRole`, `_toggleSuspension`, `_save` y `AdminUserActions` sin
  cambios de lógica.
- `lib/features/admin/presentation/admin_screens.dart`: `AdminAuditScreen` delega en
  `AdminAuditView`; se retiraron `_AuditStatusTag`, `_AuditEventChip` y
  `_AuditTableHeader`.
- Tests ajustados por cambio intencional: `admin_phase_3_2_test.dart` (eventos ya no son
  `CheckboxListTile`; nuevo texto de vacío) y `phase_3_20_premium_ux_test.dart` (el
  detalle se abre desde la fila, no desde "Ver").

## Vistas revisadas
- Por pruebas de widget con datos simulados: Recuperar contraseña (390, 768, 1024, 1366,
  1440, 1600; éxito, reenvío, volver a formulario, validación, error), Usuarios (1440,
  1100, 390; filtros, contador, menú, motivos, carga, error), Configuración (1440, 768,
  390, 360; pestañas, próximamente, acordeón, carga), Auditoría (1440, 1024, 768, 390;
  filtros, vacío, sin coincidencias, error, carga).
- Barrido existente `phase_3_14_responsive_test.dart` (12 pantallas + 7 admin × 10
  anchos) en verde.
- Coherencia revisada en código con `/account`, `/provider/business`, `/requests`,
  `/saved`, `/admin`, `/admin/businesses`: mismos badges (`RancoStatusBadge`), radios
  12–16, bordes `#DCE8E0`, esqueletos `RancoSkeletonBox`, control segmentado compartido.
- **No revisado en navegador con sesión real** (requiere credenciales de admin).

## Tests
`test/phase_3_22_ux_polish_test.dart` — 30 pruebas: recuperar contraseña (6 anchos +
reenvío + error), usuarios (tabla, contadores, menú deshabilitado con motivo, propia
cuenta, tablet sin Registro, móvil, carga sin perder buscador, error), configuración
(secciones, próximamente sin controles, acordeón, 3 anchos, carga), auditoría
(etiquetas, filtros por recurso y fecha, sin coincidencias, vacío, error, carga, 3
anchos). Suite total: 494/494.

## Pendientes para Codex
1. **Auditoría**: devolver nombre/correo del actor (o un join a `profiles`) y el
   `new_data`/estado resultante para filtrar por actor y mostrar un resultado exacto;
   paginación en servidor (hoy 50 filas fijas, la paginación es local).
2. **Reenvío de recuperación**: si se quiere limitar reintentos, exponer el cooldown del
   backend; hoy la UI reutiliza la misma llamada y muestra el error que llegue.
3. **Usuarios**: confirmar si la RPC de suspensión bloquea a `super_admin`; la UI solo
   explica los casos ya conocidos (visitante, superadministrador para rol, propia cuenta).
4. **Configuración General / Notificaciones / Integraciones**: modelo y RPC para
   habilitarlas; la UI ya tiene el lugar y la descripción.
5. **`ResetPasswordScreen`** (nueva, de Codex): revisar visualmente en una pasada
   posterior para alinearla con Recuperar contraseña (marca, tarjeta 460 px, éxito en
   línea).

## Pendientes visuales posteriores
- QA en navegador con sesión admin real (hover de filas, menús y acordeón con fuentes
  reales; las pruebas usan una fuente de ancho fijo).
- Pestañas de Configuración sticky si la sección crece.
- Detalle de usuario como panel lateral en desktop (hoy diálogo).
- Exportar auditoría (CSV) cuando exista paginación en servidor.
