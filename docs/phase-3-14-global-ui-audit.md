# FASE 3.14 COMPLETADA — Auditoría visual y refinamiento UX/UI global

Fecha: 2026-10-03 · Alcance: solo frontend (Flutter). Sin cambios en Supabase, RLS, RPC,
migraciones, auth, roles, reservas, solicitudes ni queries. Sin deploy.

Principio aplicado: refinar, compactar, ordenar y unificar el sistema existente (verdes,
Material 3, superficies claras). No se creó identidad nueva.

---

## 1. Archivos modificados

Nuevos:
- `lib/core/widgets/ranco_site_footer.dart` — footer público en el flujo del scroll.
- `test/phase_3_14_responsive_test.dart` — barrido responsive (82 casos).

Modificados (código):
- `lib/core/layout/ranco_responsive.dart` — sistema de anchos.
- `lib/theme/ranco_tokens.dart` — breakpoint `twoPane` (1200).
- `lib/router/app_shell.dart` — sin footer fijo, topbar y sidebar.
- `lib/features/locations/presentation/location_selector.dart`
- `lib/features/home/presentation/home_screen.dart`
- `lib/features/discovery/presentation/explore_screen.dart`
- `lib/features/categories/presentation/categories_screen.dart`
- `lib/features/categories/presentation/category_editorial_order.dart`
- `lib/features/businesses/presentation/business_card.dart`
- `lib/features/businesses/presentation/business_detail_screen.dart`
- `lib/features/businesses/presentation/lodging_availability_screen.dart`
- `lib/features/businesses/presentation/lodging_public_profile.dart` (solo retiro de "Verificado"; la clase no se usa en rutas)
- `lib/features/reviews/presentation/reviews_section.dart`
- `lib/features/favorites/presentation/saved_screen.dart`
- `lib/features/service_requests/presentation/requests_screen.dart`
- `lib/features/profile/presentation/account_screen.dart`
- `lib/shared/models/profile.dart` (etiqueta visible `customer` → "Usuario"; enum intacto)
- `lib/features/auth/presentation/access_screen.dart`
- `lib/features/auth/presentation/sign_in_screen.dart`
- `lib/features/legal/presentation/consent_fields.dart`
- `lib/features/legal/presentation/legal_screen.dart`
- `lib/features/admin/presentation/admin_screens.dart`
- `lib/features/admin/presentation/admin_settings_screens.dart`

Tests actualizados por cambio de contrato UX (no por regresión):
`business_public_profile_test`, `tourism_adventure_category_test`, `admin_phase_3_2_test`,
`admin_phase_3_3_test`, `admin_phase_3_6_test`, `auth_provider_separation_test`, `access_flow_test`.

## 2. Componentes compartidos creados/modificados

- `RancoSiteFooter` / `RancoFooterSliver` (nuevo): footer único reutilizado por Home, Explorar,
  Categorías, Solicitudes, Guardados y Cuenta.
- `RancoContainerWidth`: nuevos anchos `booking` (1080), `auth` (480), `legal` (960), `admin`
  (1400); `standard` 1240/1280 y `detail` 1120/1150.
- `showLocationPicker(context, ref)`: selector de localidad único (top bar, Home y Explorar).
  Se eliminó el selector duplicado interno de Explorar.
- `BusinessCard`: tarjeta compacta por vertical (ver §9).
- `ConsentFields`: grupo "Consentimientos" compartido por registro, acceso visitante y diálogos.
- Admin: `_AdminSidebar`, `_StatusPill` con color semántico, `_AdminUsersTable`,
  `adminRoleLabel` / `adminAccountStatusLabel`, `_InfoCallout`, `_AdminRow`.

## 3. Correcciones P0

| # | Problema | Estado |
|---|----------|--------|
| 1 | Footer superpuesto | Corregido: el footer salió del `Column` del shell (ocupaba alto fijo bajo `Expanded`) y ahora es el último sliver de cada página. |
| 2 | Scroll anidado | Corregido en las vistas del shell: un único scroll por vista; el footer móvil ya no tiene `ListView` interno de 190 px. |
| 3 | Guardados desproporcionado | Corregido: grilla responsive (1–4 columnas) con `BusinessCard`; antes cada tarjeta 16:9 ocupaba todo el ancho. |
| 4 | "Verificado" público | Retirado de badges, íconos de hero y filtros (desktop y hoja móvil). Campo y semántica admin intactos; Explorar envía `verifiedOnly: false`. |
| 5 | Cuenta admin duplicada | Corregido: una tarjeta "Panel administrativo" + "Abrir panel". |
| 6 | Auth/proveedor en desktop | Publicar negocio a 600 px; Crear acceso como tarjeta de marca de 480 px. |
| 7 | Tablas admin altas | Negocios: tabla con filas de ~60 px; Usuarios: tabla compacta en desktop. |
| 8 | Escala desktop | Tokens de ancho por tipo de vista (§26). |
| 9 | Valores técnicos en inglés | Roles y estados mapeados (Administrador, Prestador, Usuario, Activo, etc.). |
| 10 | Navegación duplicada | Top bar sin "Explorar"/"Ingresar"/"Mi negocio" (ya están en el sidebar). |

## 4. Mejoras P1

Explorar, BusinessCard, ficha de alojamiento, reserva, calendario, dashboard admin,
configuración, estadísticas, auditoría, legal y footer: ver secciones 6–25.

## 5. Refinamientos P2

- Tooltips: "Cambiar localidad", "Mi cuenta", favorito en tarjeta, aprobar/rechazar, nombres y
  propietarios truncados en tablas, detalle de cada KPI admin.
- Targets: filtros de Explorar 44 px, botón limpiar filtro 32 px, favorito 40 px.
- Truncado con ellipsis en tablas, chips, sidebar y top bar (nombre de usuario ≤ 140 px).
- Hover en tarjetas de categoría, módulos admin, filas de tabla y sidebar admin.
- Tipografía mínima elevada (filtros de 9 → 11 px, metadata de 10.5 → 12–13 px).
- Ortografía: "¡Únete" (texto corrupto `?nete`), "Huéspedes", "Baños", "opinión",
  "quiénes".

## 6. Home

- Ancho `standard` (1240/1280) en hero, categorías, destacados y promos.
- Tarjetas de categoría desktop de 126 → 84 px, en fila (ícono, título, chevron). Se eliminó la
  doble señal "Ver servicios" + flecha.
- Emergencias conserva tratamiento semántico (fondo y borde cálidos), sin colorear el resto.
- Hero desktop: título flexible con máximo 3 líneas (antes podía desbordar).

## 7. Explore

- Accesos rápidos reducidos a: Todas, Alojamiento, Gastronomía, Turismo, Emergencias,
  Servicios y "Más" (antes 8 categorías + Todas + Más). Etiquetas cortas por slug.
- Panel de filtros: 248 px, padding 16, labels 11 px, toggles de 44 px; sin "Verificados".
- Grilla: `minItemWidth` 250 → 3 columnas en desktop típico; 4 solo con ancho real suficiente.
- Selector de localidad unificado con el resto de la app.
- Breakpoint de 2 paneles nombrado como token (`RancoBreakpoints.twoPane`).

## 8. Categories

- Tarjetas de 108 → 72 px, una sola affordance (toda la tarjeta + chevron que se desplaza al
  hover). Se eliminó flecha superior + "Ver servicios →".
- Columnas recalculadas (4/3/2/1 desde 1000/720/480 px). Footer en flujo.

## 9. BusinessCard

- Sin avatar circular superpuesto; si no hay portada se usa el logo del negocio dentro del
  fallback gráfico estándar; si tampoco hay logo, ícono de categoría. No se inventan fotos.
- Favorito sobre la imagen (40 px, con tooltip). CTA "Ver detalle" tonal y liviano.
- Sin descripción. Máximo 3 datos (2 en Home) por vertical + rating:
  - Alojamiento: localidad, precio/noche, huéspedes/camas.
  - Servicios/Emergencias: localidad, cobertura, horario, precio desde.
  - Gastronomía/Turismo: localidad, horario, precio si existe.

## 10. Saved

Grilla responsive con la tarjeta compartida, contador y "Explorar más" alineados al mismo
ancho; estados vacío/invitado con footer en flujo.

## 11. Business detail

- Hero: avatar solo cuando existe logo real (80/64 px). Sin "Verificado". "Destacado" se mantiene.
- Panel: primario "Consultar disponibilidad"; secundario WhatsApp (tonal, ancho completo);
  terciarias en grilla de 2 columnas (Llamar, Correo, Sitio web, Cómo llegar, Guardar).
  Antes "Cómo llegar" tenía el mismo peso que la acción primaria.
- "Acerca" sin tarjeta: título + texto.
- Opiniones: el contenido va primero; "Escribir una reseña" pasa al final como acción secundaria
  compacta. Estado vacío en una sola línea.

## 12. Booking

- Ancho 1080. Encabezado de la propiedad 108 → 88 px (móvil: imagen 132 → 104 px).
- Secciones separadas por divisores en vez de tarjetas dentro de la tarjeta.
- El resumen sigue visible en desktop mediante una columna con scroll propio paralela al
  formulario (no anidada), patrón ya existente.
- Lógica de reserva sin cambios.

## 13. Calendar

- Celdas de máximo 44 px de alto (antes cuadradas, semanas muy altas en desktop).
- Por rango: tramo continuo (extremos redondeados hacia afuera). Días específicos: pastillas
  independientes.
- No disponible: color + tachado (no depende solo del color). Semántica por día.
- CTA dinámico: "Selecciona la fecha de llegada" → "Selecciona la fecha de salida" →
  "Confirmar N noches"; días específicos: "Selecciona los días" → "Confirmar N días".

## 14. Provider onboarding

Columna de 600 px en desktop, hero textual de 26 px, pasos 01–04 con texto de 15/13 px,
CTA de 50 px.

## 15. Auth

- Bienvenida: 1120 px, título de 28 px en desktop, CTA con verbos distintos al título
  ("Empezar a explorar", "Continuar como prestador"). Imagen y links legales intactos; sin hero
  en móvil.
- Crear acceso: tarjeta de 480 px con logo, título, explicación, campos, consentimientos,
  CTA de 48 px y "Ya tengo una cuenta · Ingresar".

## 16. Legal

Lectura de máx. 760 px dentro de 960/1040; índice fijo a la izquierda en desktop (no se desplaza
con el texto); secciones con título + divisores en vez de tarjetas; acordeones livianos en
móvil; fecha, versión y footer legal consistentes.

## 17. Account

- Admin: una tarjeta de administración (sin repetir módulos de `/admin`), Seguridad intacta.
- Ancho `form` (760) en vez de 1120. Footer dentro del mismo scroll.
- "Ayuda y soporte" ahora abre `/contacto` (antes `onTap` vacío).
- Roles: lógica intacta; admin no ve "Mi negocio"; proveedor sí.

## 18. Admin dashboard

- Sidebar propio de 216 px con etiqueta, estado activo, hover y "Ir al sitio"; reemplaza el
  `NavigationRail` de 112 px con "ADMIN".
- Contenido limitado a 1400 px. Header: "Gestiona la operación de Ranco Conecta.", título 26 px,
  "Revisar pendientes" (primario), "Configuración" (secundario), "Cuenta" discreta.
- KPI de 142 → 72 px; 5 en fila (≥1000 px), 3 en tablet, 2 en móvil; detalle en tooltip.
- Actividad: "Últimos 30 días", valores alineados con cifras tabulares.
- Módulos: orden Negocios, Usuarios, Categorías, Configuración, Estadísticas, Auditoría; tarjetas
  bajas en grilla 3×2.
- "Volver al panel" eliminado en desktop; se mantiene en móvil (sin sidebar).
- Sin footer público en `/admin/*`.

## 19. Admin businesses

Tabla desktop (≥ 860 px de contenido): Imagen, Negocio, Categoría/Tipo, Propietario, Estado
(color semántico), Fecha, Acciones. Filas de ~60 px, nombre/propietario con ellipsis + tooltip,
aprobar/rechazar con ícono, color y tooltip. Tarjetas en anchos menores. Filtros intactos.

## 20. Admin users

Tabla compacta en desktop (Usuario, Correo, Rol, Estado, Registro — `created_at` real del RPC);
tarjetas en móvil. Chips de filtro: Todos, Administradores, Prestadores, Usuarios.

## 21. Admin categories

Sin badge "Activa" repetido (el encabezado ya dice "N categorías activas"). Tarjetas livianas,
slug visible.

## 22. Admin settings

Máx. 860 px. Orden: estado, callout "El mensaje se envía solo al confirmar en WhatsApp. Ranco
Conecta prepara el aviso; no hay envío automático.", número con ayuda, toggle, eventos activos,
eventos no disponibles.

## 23. Admin analytics

KPI reales compactos (visitas, contactos, WhatsApp, guardados) + clics en teléfono. Se eliminó la
caja vacía de gráfico: estado compacto "Aún no hay suficiente actividad para mostrar una
evolución temporal." Sin gráficos inventados.

## 24. Admin audit

Un bloque de 860 px: estado "Preparada", eventos contemplados (Aprobaciones, Rechazos, Cambios
de configuración, Gestión de usuarios) e historial vacío. Sin registros inventados.

## 25. Footer

Columnas: Ranco Conecta (Sobre nosotros, Explorar), Para negocios (Registrar negocio, Acceso
proveedor), Ayuda (Términos, Privacidad, Contacto). Columna "Redes / Próximamente" eliminada.
Línea inferior "© 2026 Ranco Conecta · Lago Ranco, Chile". Móvil: lista compacta de enlaces.

## 26. Scroll

Un scroll principal por vista en el shell. `RancoFooterSliver` deja el footer al final del
contenido o al fondo de la ventana si el contenido es corto. Se corrigió además un defecto
detectado en la revisión visual: el fondo del footer se estiraba hasta el borde inferior en móvil.

## 27. Responsive

Anchos máximos: Home/Explorar/Guardados 1240–1280; detalle 1120–1150; reserva 1080; auth 480;
onboarding 600; legal 960; admin 1400; configuración/auditoría 860.

`test/phase_3_14_responsive_test.dart` renderiza Home, Explorar, Legal, Publicar negocio, Crear
acceso, Footer, Admin resumen/negocios/usuarios/auditoría en 390, 600, 768, 1024, 1200, 1366,
1440 y 1600 px con un nombre de negocio largo real ("Nuevo negoaaa…ocio") y falla ante cualquier
overflow. Detectó dos overflows reales (encabezado de panel admin y chips de auditoría a
390 px), ya corregidos.

## 28. Accessibility

Tooltips en acciones solo-ícono, `Semantics` en días del calendario y en el sidebar admin,
estado "no disponible" sin depender solo del color, targets mínimos ampliados, foco inicial en
la búsqueda del selector de localidad (desktop), Escape cierra diálogos y hojas (comportamiento
de Flutter), la selección actual del selector queda visible al abrir. Los enlaces legales se
sacaron de las filas de consentimiento para que tocar una fila nunca navegue por accidente.

## 29. Tests

`flutter test`: **285 pruebas, todas aprobadas** (203 existentes + 82 nuevas).

## 30. Analyze

`flutter analyze --no-pub`: **No issues found**. `dart format` aplicado a los archivos
modificados. `scripts/check_text_encoding.ps1`: **UTF-8 estructural: OK**. `git diff --check`:
sin errores de espacios.

## 31. Build

`flutter build web --release`: **OK** (`build/web`). No se tocó `vercel_output` ni se desplegó.

## 32. Pendientes reales

Validación visual en navegador (Edge/Playwright sobre `build/web`, sin backend):
- **Revisadas** en 390/1024/1440: Bienvenida, Explorar (vacío), Todas las categorías (vacío),
  Términos, Publicar negocio, Crear acceso.
- **No revisadas visualmente** (requieren sesión o datos reales): Home con destacados reales,
  Guardados con favoritos, ficha de negocio/alojamiento, reserva y calendario, Cuenta, Solicitudes
  con datos y todo `/admin`. Para estas solo existe la validación de layout del barrido
  automático (sin overflow); falta revisión visual humana con datos.

No abordado en esta fase:
- Drawer móvil (`ranco_navigation_drawer.dart`) y su breakpoint de 900 px.
- Detalle de revisión admin (`/admin/businesses/:id`) y pantallas del panel de proveedor.
- Unificación global de estados vacíos/carga/error (solo se ajustaron los tocados).
- Tokens tipográficos centralizados en el tema (se ajustaron tamaños por pantalla).
- KPI "Negocios activos" usa el mismo dato que "Publicados" (sin cambiar consultas).
- "Sesiones activas" y "Cambiar contraseña" abren la misma ruta (preexistente).
- Observación funcional no modificada: en reserva, el `FutureBuilder` del resumen crea la
  consulta en cada rebuild (p. ej. al cambiar huéspedes).
- `LodgingPublicProfile` no se usa en ninguna ruta (código muerto preexistente).
