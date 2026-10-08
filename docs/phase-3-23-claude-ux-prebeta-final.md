# FASE 3.23 — UX/UI final pre-beta (Claude)

Fecha: 2026-10-04 · Solo UX/UI y presentación. Sin cambios en Supabase, RLS, RPC,
migraciones, políticas, permisos, auth, contratos de datos, consultas ni repositorios.
Sin deploy, commit ni push.

## Auditoría inicial
- Reportes leídos: 3.21 (Claude), 3.22A, 3.22A.1 y 3.21 (Codex).
- Cambios de Codex desde 3.22A.1: **ninguno** en `lib/` ni `test/` (mtime revisado). Sus
  archivos sin seguimiento en `supabase/` no se tocaron.
- Baseline: `flutter analyze` sin issues · `flutter test` **506/506**.

## Validación final
`dart format --output=none --set-exit-if-changed lib test` (0 cambios) ·
`flutter analyze --no-pub` sin issues · `flutter test` **539/539** (33 nuevos en
`test/phase_3_23_prebeta_final_test.dart`) · `check_text_encoding.ps1` OK ·
`git diff --check` código 0 · `flutter build web --release` OK.

## Cambios implementados

### 1. Legales — Términos, Privacidad, Contacto
- **Encabezado compacto**: padding 44/36 → 28/24 (desktop) y 20/18 (móvil); título
  36 → 30 px (25 en móvil); descripción 16 px. El primer bloque de contenido queda visible
  sin bajar (verificado en test: < 520 px desde arriba a 1440×900).
- **Metadatos en línea** ("Última actualización · 1 oct 2026 · Versión 2026-10-01") en vez
  de badges altos: ya no interfieren con el índice.
- **Layout 1200 px**: índice 224 px + separación 48 + artículo 780 px.
- **Secciones editoriales más densas**: número y título en la misma línea (antes chip
  "01" encima), padding vertical 32 → 22 px, título 22 → 20 px, cuerpo 16/1.65 alineado
  bajo el título. Sin tarjetas por sección.
- **Móvil**: el `ExpansionTile` "En esta página" se reemplazó por **chips horizontales**
  desplazables con la sección activa marcada; un toque lleva a la sección.
- **Cierre compacto**: ayuda con botón secundario ("Ir a Contacto", outline en vez de
  relleno) y "Más información" con filas más bajas.
- Contacto: menos aire sobre el formulario (32 → 24 px).
- Navegación sin cambios: los enlaces siguen usando `context.push`, "Volver" usa
  `pop()` o `/` (historial real verificado en test).

### 2. Footer global
- Ya era un único componente (`RancoSiteFooter` + `RancoFooterSliver` /
  `RancoFooterScrollView`) en Home, Explorar, Categorías, Guardados, Solicitudes, Cuenta y
  legales; no se crearon variantes. En móvil la barra inferior la pone el `Scaffold`, así
  que no compite con el footer. Test: el footer queda tras "Más información" y mide
  < 260 px.

### 3. Bootstrap (`BootstrapScreen`)
- Solo presentación (mismas condiciones `hasError`): emblema Ranco Conecta 56 px,
  "Preparando tu cuenta…" / "Esto toma solo un momento.", **indicador lineal de 120 px**
  que aparece con fundido tras ~300 ms (sin destello si el arranque es rápido; sin
  timers). Error: "No pudimos preparar tu sesión." sin indicador.
- La línea **build / sha** solo se muestra con `kDebugMode`; nunca al usuario final.

### 4. Estados de carga / error
- `_ProviderBusinessHub` (`/provider/business`, pendiente de 3.21): spinner blanco →
  AppBar "Mi negocio" + esqueleto; error suelto → `RancoErrorState` con el mismo
  `invalidate(providerContextProvider)`.
- `AdminGate`: spinner de página → esqueleto sobre la superficie del panel.
- Hub de alojamiento (Reservas, Calendario, Información, Fotos, Tarifas) y Editar
  perfil: 12 spinners de página → `RancoLoadingState`.
- Ya alineados en fases previas: Cuenta, Guardados, Solicitudes, Notificaciones, Admin
  (usuarios, configuración, auditoría), hub de servicios.

### 5. Admin
- **Estadísticas**: contenido limitado a 980 px (en 1600 px las filas se estiraban
  hasta ~1300 px) y margen inferior.
- **Sidebar admin**: emblema 42 px / texto 18, misma escala que el sidebar público.
- Resumen, Negocios, Usuarios, Configuración y Auditoría: sin cambios (ya cumplen tras
  3.20–3.22A.1: KPI + dos columnas, cabecera de tabla fija, buscador persistente, menú ⋯
  con motivos, pestañas con "Pronto", filtros compactos, línea de tiempo móvil).

### 6. Cuenta, hub y wizard (auditados, sin cambios)
- Cuenta: un único CTA "Gestionar negocio"; "Ver perfil público" como ícono solo si
  está publicado; Reservas/Calendario solo en alojamiento publicado (funciones
  distintas, no duplicadas); seguridad y cierre de sesión debajo.
- Hub: las pestañas viven en el `AppBar` (siempre visibles al hacer scroll), con
  desplazamiento horizontal en móvil; encabezado compacto.
- Wizard: stepper compacto, acciones junto al formulario, selector de categoría con
  búsqueda y grupos, revisión en 4 bloques con "Editar" y requisitos "n de m listos".

## Bugs UX corregidos
1. **Índice legal "sticky" nunca seguía al contenido**: el listener de scroll medía las
   posiciones antes del layout del nuevo frame y siempre leía la posición inicial; el
   índice quedaba fijo a ~224 px del borde y no se detenía al final del artículo. Ahora
   mide una vez por frame tras el layout.
2. **Índice superpuesto en el primer frame**: se dibujaba en `top: 280` antes de
   medirse, encima de los badges de versión. Ahora está oculto (opacidad 0, sin puntero)
   hasta conocer su posición.
3. Spinners de página en hub prestador, puerta admin y alojamiento (ver §4).
4. Información técnica de build visible al usuario final en el arranque.

## Responsive validado
Tests de widget: legales (Términos, Privacidad, Contacto) en **390, 430, 768, 1024, 1280,
1366, 1440, 1600** sin overflow; barrido existente (12 pantallas + 7 admin × 10 anchos)
en verde. Revisión visual del build release en el navegador: Privacidad 1440×900 y
Términos 390×844.

## Tests agregados (`phase_3_23_prebeta_final_test.dart`, 33)
Legal desktop (encabezado compacto, el índice no se superpone, primer bloque visible),
índice sticky tras scroll, chips móviles que saltan a la sección, historial real de
"Más información" + Volver, footer tras el contenido y compacto, 24 casos responsive
(3 páginas × 8 anchos), bootstrap (marca, sin spinner, indicador con fundido, error
calmo), puerta admin con esqueleto, Estadísticas con ancho acotado a 1600 px.
Ajustado: `provider_route_guard_test.dart` (nuevo texto del bootstrap).

## Archivos principales
- `lib/features/legal/presentation/legal_screen.dart` (presentación + medición del índice)
- `lib/router/app_router.dart` (solo `BootstrapScreen` y la carga/error de
  `_ProviderBusinessHub`; redirecciones intactas)
- `lib/features/admin/presentation/admin_screens.dart` (carga de `AdminGate`, marca)
- `lib/features/admin/presentation/admin_settings_screens.dart` (ancho de Estadísticas)
- `provider_bookings_screen.dart`, `lodging_calendar_screen.dart`,
  `lodging_information_screen.dart`, `lodging_photos_screen.dart`,
  `lodging_rates_screen.dart`, `edit_profile_screen.dart` (esqueletos)
- `test/phase_3_23_prebeta_final_test.dart`, `test/provider_route_guard_test.dart`

## Pendientes para Codex
1. Admin Usuarios: exponer `p_status` (ya aceptado por `admin_search_users`) para un
   filtro por estado de cuenta.
2. Auditoría: nombre del actor y paginación en servidor (hoy 50 filas).
3. Métricas por negocio para el prestador (vistas/contactos) si se quieren en el hub.
4. Definir acción propia para cuentas "Bloqueadas" vs. "Suspendidas".

## Pendientes para QA manual
- Legales en navegador real con ventana activa: scroll largo (índice sigue y se detiene
  al final), salto desde el índice, Volver tras saltar entre Términos/Privacidad/Contacto.
- Arranque real con sesión: confirmar que el indicador no destella en conexiones rápidas.
- `/provider/business` con red lenta (esqueleto → resumen sin salto).
- Detalle público de negocio y reservas: aún usan spinners internos (fuera de alcance de
  esta fase).

## Qué NO se tocó
Supabase, RLS, RPC, migraciones, políticas, permisos, auth (repositorio, callback,
recuperación, cierre de sesión), redirecciones del router, repositorios, consultas y
contratos de datos. Detalle público de negocio, disponibilidad de alojamiento y reseñas
(spinners internos documentados arriba).
