# FASE 3.16 — Refinamiento UX/UI Admin + Cuenta + Paginación + Legal

Fecha: 2026-10-03 · Solo frontend. Sin cambios en Supabase, RLS, RPC, migraciones,
permisos, auth, queries ni contratos de datos. Sin deploy.

---

## A. Cambios UX/UI implementados

### Archivos

Nuevos:
- `lib/features/admin/presentation/admin_ui.dart` — `AdminPaginator`, `AdminSegmentFilter`,
  `AdminSearchField`, `AdminPreviewNotice`.
- `lib/core/widgets/ranco_page_empty_state.dart` — estado vacío de página compartido.

Modificados:
- `lib/features/profile/presentation/account_screen.dart`
- `lib/features/profile/presentation/account_security_screen.dart`
- `lib/features/admin/presentation/admin_screens.dart`
- `lib/features/admin/presentation/admin_settings_screens.dart`
- `lib/features/notifications/presentation/notifications_screen.dart`
- `lib/features/service_requests/presentation/requests_screen.dart`
- `lib/features/favorites/presentation/saved_screen.dart`
- `lib/features/businesses/presentation/business_card.dart` (variante `saved`)
- `lib/features/auth/presentation/sign_in_screen.dart` (Publicar negocio)
- `lib/features/legal/presentation/legal_screen.dart`
- `test/phase_3_14_responsive_test.dart` (barrido ampliado)

### 1. Cuenta
- Secciones: **Perfil** (nombre, correo, rol, botón "Editar"), **Administración** (solo admin,
  una tarjeta), **Negocio** (solo proveedor, acceso a Mi negocio) y **Seguridad y acceso**
  (una entrada: "Contraseña y sesión actual").
- Se retiraron "Accesos" (Favoritos, Solicitudes) y "Cuenta y soporte" (Mensajes,
  Notificaciones, Ayuda): ya están en sidebar, drawer móvil, campana y footer.
- El estado de la cuenta solo aparece como aviso si no está activa.

### 2. Seguridad y acceso
- Título "Seguridad y acceso", ancho de formulario (760).
- "Cambiar contraseña" con ayudas por campo; el error ya no muestra el texto técnico de la
  excepción.
- "Sesión actual": Cuenta, Estado y Expira (si existe), "Cerrar esta sesión". Se eliminó la
  etiqueta "Sesiones activas": no hay gestión multisesión en el backend.

### 3. Títulos admin
- El título del header es el módulo (Usuarios, Negocios, Categorías, Configuración,
  Estadísticas, Auditoría); la descripción nunca lo repite (p. ej. Usuarios: "Consulta y
  segmenta las cuentas registradas.").
- Se eliminaron títulos internos redundantes ("Usuarios registrados", "Directorio de
  cuentas", "Auditoría administrativa" → "Estado del módulo").

### 4–5. Usuarios
- Segmentos: Todos, Usuarios, Prestadores, Administradores (`AdminSegmentFilter`). El
  componente admite agregar "Visitantes" cuando el backend lo distinga; no se infiere por
  "sin correo".
- Barra: búsqueda + segmentos en una fila (desktop) o apilados (móvil).
- Contador: "N cuentas registradas" o "N resultados en esta página" al filtrar.
- Tabla desktop (Usuario, Correo, Rol, Estado, Registro) con truncado y tooltips en nombre y
  correo; tarjetas en móvil; rol y estado en español.

### 6. Paginación compartida
`AdminPaginator`: "Mostrando 1–20 de 54", "Filas por página [20 ▼]", "‹ 1 / 3 ›".
- Negocios: filas por página 10/20/50 conectadas al parámetro `limit` que el RPC **ya**
  recibe (sin cambiar la consulta).
- Usuarios: el RPC pagina en bloques fijos de 50 → selector visible pero deshabilitado con
  tooltip "Tamaño de página fijo por ahora".

### 7. Negocios
Estados (Todos, En revisión, Publicado, Rechazado, Suspendido, Cambios solicitados) con el
filtro segmentado; búsqueda + tipo + "Buscar" en una barra; tabla y acciones de 3.14 se
mantienen; paginador compartido. Consultas sin cambios.

### 8–10. Categorías (solo UI)
- "Nueva categoría", búsqueda, filtros Todas / Activas / Inactivas, ítem compacto con menú ⋯
  (Editar, Desactivar, Eliminar).
- Modal Nueva/Editar: Nombre, Slug (autogenerado desde el nombre hasta que se edita), Estado.
- Confirmaciones de Desactivar/Eliminar diseñadas.
- **Guardar/Crear/Confirmar quedan deshabilitados** y cada diálogo muestra el aviso "La gestión
  de categorías estará disponible próximamente." No hay escritura a Supabase. El interruptor
  está centralizado en `_categoryCrudAvailable` (`admin_settings_screens.dart`).
- "Inactivas" muestra un estado vacío explicativo: el catálogo actual solo entrega activas.
- No existe selector de ícono en el proyecto, así que no se agregó.

### 11. Configuración
Un solo scroll, máx. 860 px. Orden: WhatsApp administrativo → ESTADO ACTUAL → aviso
"Ranco Conecta prepara el aviso; el envío se confirma manualmente en WhatsApp." →
CONFIGURACIÓN (toggle, número, eventos activos, eventos no disponibles).

### 12–14. Notificaciones, Solicitudes, Guardados
- `RancoPageEmptyState` unifica ícono, título, microcopy y CTA en las tres vistas.
- Notificaciones: "No tienes notificaciones" + "Cuando haya novedades sobre tus solicitudes o
  tu cuenta aparecerán aquí."; la acción ("Marcar todo como leído") solo aparece si hay no
  leídas.
- Guardados: variante de tarjeta `saved` sin alturas reservadas (menos espacio vacío interno);
  la grilla queda alineada al inicio (una sola tarjeta no se centra).

### 15. Publicar negocio
Columna de 580 px; los cuatro pasos quedan agrupados en una superficie y el CTA va
inmediatamente debajo.

### 16–20. Legal y Contacto
- Términos/Privacidad: título, fecha/versión, secciones numeradas con anclas y separadores,
  lectura de 720 px con texto de 16/1.7. Desktop: índice lateral fijo que **marca la sección
  activa** al desplazarse. Móvil: índice compacto con enlaces + una columna (antes
  acordeones colapsados).
- Contenido legal sin cambios.
- Contacto: encabezado institucional, formulario compacto en una superficie y "Otros canales"
  solo si están configurados (`CONTACT_*`); si no hay correo se mantiene el aviso de canal
  pendiente.
- Navegación (`go_router`, back, push) sin cambios.

### 21–22. Dashboard y sidebar admin
- "Estado de la plataforma" ya no repite Negocios activos/Usuarios (están en los KPI).
- Sidebar: foco de teclado visible; hover/selección/"Ir al sitio" sin cambios.

### 23–24. Responsive y accesibilidad
- `test/phase_3_14_responsive_test.dart` ahora cubre: Home, Explorar, Términos, Privacidad,
  Contacto, Publicar negocio, Crear acceso, Footer, **Cuenta, Seguridad, Guardados,
  Notificaciones** y admin **Resumen, Negocios, Usuarios, Categorías, Configuración,
  Estadísticas, Auditoría**, en 390/600/768/1024/1200/1366/1440/1600 px. Detectó un overflow
  real en Seguridad a 390 px (corregido).
- Tooltips en paginador, menú ⋯ de categorías, celdas truncadas; botones deshabilitados con
  explicación visible.

### Validaciones
- `scripts/check_text_encoding.ps1`: UTF-8 estructural OK.
- `dart format`: aplicado a los archivos modificados.
- `flutter analyze --no-pub`: No issues found.
- `flutter test`: **357 pruebas aprobadas**.
- `git diff --check`: sin errores.
- `flutter build web --release`: OK (`build/web`). Sin deploy.

### Revisión visual
- En navegador (build local sin backend, 390 y 1440 px): Términos, Privacidad, Contacto y
  Publicar negocio.
- **Sin revisión visual en navegador** (requieren sesión/datos): Cuenta, Seguridad, Guardados,
  Notificaciones, Solicitudes y todo `/admin`. Para estas solo existe la verificación de layout
  del barrido automático (sin overflow en los 8 anchos).

---

## B. Pendientes para Codex

1. **PENDIENTE CODEX — CRUD backend categorías.** Crear, editar, desactivar y eliminar
   categorías de forma segura (RPC/RLS solo admin, auditoría). La UI está lista; al existir,
   activar `_categoryCrudAvailable` y conectar los botones de `_CategoryFormDialog` y
   `_confirm`.
2. **Categorías inactivas.** `Category` no tiene `is_active` y `categoriesProvider` solo
   entrega activas. Para el filtro "Inactivas" hace falta exponer el estado (modelo + consulta
   admin).
3. **Paginación de usuarios.** `admin_list_users` usa bloques fijos de 50 y la búsqueda/filtro
   por rol es client-side sobre la página actual. Falta: parámetro de tamaño de página,
   búsqueda y filtro por rol server-side.
4. **Segmentación visitante/anónimo.** No hay un rol o marca de visitante en el listado admin.
   Si se requiere el segmento "Visitantes", el backend debe exponerlo (no inferirlo por correo).
5. **Sesiones.** No existe gestión multisesión (listar/cerrar otras sesiones). Solo se muestra
   y cierra la sesión actual.
6. **PENDIENTE CODEX — navegación legal.** No se tocó `go_router` ni el stack. Revisar si
   Términos/Privacidad/Contacto deben abrirse con `go` o `push` de forma uniforme y su
   comportamiento con el back del navegador.
7. **Contacto.** El formulario depende de `CONTACT_EMAIL` (dart-define). Sin él, el envío
   queda deshabilitado; definir el canal real en el entorno de producción.
8. **KPI "Negocios activos".** Usa el mismo dato que "Publicados"; si debe significar otra cosa
   (p. ej. publicados con actividad), requiere una métrica en backend.
