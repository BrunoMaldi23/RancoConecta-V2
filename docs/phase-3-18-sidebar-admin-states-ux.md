# FASE 3.18 — Sidebar, Admin Resumen, Configuración, Solicitudes, Estados + Legal UX

Fecha: 2026-10-03 · Solo UI/UX. Sin cambios en Supabase, RLS, RPC, migraciones, queries,
auth ni modelos. Sin deploy. Validaciones: encoding OK · analyze sin issues · 368 tests OK ·
`git diff --check` limpio · `flutter build web --release` OK.

## 1–4. Sidebar y branding
- Nuevo `core/widgets/ranco_brand.dart`: `RancoBrandMark` muestra el emblema circular del asset
  real `ranco_logo_login.png` (recorte en tiempo de ejecución, sin logo nuevo) a 38–44 px;
  `RancoBrandLockup` = emblema + "Ranco Conecta" con los colores del logotipo.
- Sidebar público: bloque de marca ~60 px (clic → inicio), grupos con etiquetas y espaciado
  uniforme, estado activo = fondo suave + texto verde + indicador lateral (sin borde extra),
  foco visible. "Cerrar sesión" más bajo (38 px), rojo suave y hover discreto.
- Drawer móvil: emblema legible de 44 px.
- Sidebar admin: misma familia ("Ranco Conecta / Administración").

## 5–8. Admin Resumen
- Se eliminó el título "Vista general": header → KPI directo.
- KPI: si la métrica no carga o falla muestran "—" con tooltip "No disponible temporalmente"
  (o "Cargando…"); ya no se muestra 0 falso ni un error a pantalla completa.
- Errores de paneles: variante compacta en línea con mensaje humano ("No pudimos cargar las
  revisiones.", "Intenta nuevamente en unos momentos.") + Reintentar. `AdminErrorState` ya no
  muestra "La consulta fue rechazada por el servidor"; el detalle técnico va a `debugPrint`.
- Módulos 3×2 más bajos; bloques WhatsApp/Estado con alturas igualadas.

## 9–11. Configuración
- Breadcrumb "Admin / Configuración", título "Configuración", descripción "Gestiona los avisos
  administrativos de la plataforma."; sección "WhatsApp administrativo".
- Estado en filas: Estado [● Activo/Inactivo], Número administrador, Eventos activos (N) + chips.
- Callout del envío manual; una sola fila switch "Avisos por WhatsApp"; helper "Incluye código
  de país."; listas limpias de eventos activos / no disponibles.
- Un único scroll, sin alturas fijas, padding inferior 48 px. Éxito: snackbar "✓ Cambios
  guardados".

## 12–14. Solicitudes
- Empty a 88 px del header (no centrado en el viewport) con copy actualizado.
- Fila compacta compartida para todas las verticales: ícono por tipo, negocio, tipo
  ("Reserva de alojamiento", "Solicitud de servicio", "Reserva de mesa", "Solicitud de
  turismo"), resumen · fecha, estado y "Ver detalle →".
- Estados semánticos: Pendiente ámbar, Aceptada verde, Rechazada rojo suave, Finalizada
  neutral, Cancelada gris. Carga con esqueleto (sin spinner).

## 15–17. Guardados, Explore, tarjetas
- Causa del centrado: `RancoResponsiveGrid` encogía su `Wrap` y el contenedor lo centraba.
  Ahora ocupa todo el ancho (inicio a la izquierda).
- Nuevo modo `equalHeightRows` + `BusinessCard.fillHeight`: tarjetas de una fila con igual
  altura y "Ver detalle" alineado (Explore y Guardados), sin alturas absurdas.
- Placeholders sin imagen: ícono sobre disco blanco y texto verde oscuro (más contraste).

## 18. Calendario
Alto según contenido (máx. 90 %, ancho máx. 560), grilla compacta, leyenda pegada al
calendario, CTA deshabilitado en gris legible. Lógica sin cambios.

## 19. Footer
~25 % más bajo, superficie neutra cálida, copyright bajo separador; se inserta después del
contenido (ya no rellena el viewport). Ancho configurable para alinearlo con cada página.

## 20–25. Estados y sistema visual
- Empty: `RancoPageEmptyState` (con `topSpacing`). Loading: esqueletos en listas.
  Error: mensajes humanos + Reintentar. Success: snackbar breve.
- Nuevo `core/widgets/ranco_status_badge.dart`: `RancoStatusBadge` + tonos
  (neutral/success/warning/danger/info/muted) y `rancoToneForStatusLabel`. Lo usan admin
  (`_StatusPill`, `_AdminTag`), configuración y solicitudes.

## 26–27. Responsive y accesibilidad
- Barrido automático (23 pantallas × 8 anchos) sin overflow. Revisión en navegador: Explore,
  Términos, Privacidad y Contacto en 390/768/1024/1440/1600, incluido scroll del índice legal.
- No revisados visualmente (requieren sesión/datos): Solicitudes con datos, Guardados, admin y
  calendario abierto; solo cubiertos por pruebas de layout.
- Foco visible en sidebar/índice/enlaces, semántica en badges/índice/navegación legal.

## LEGAL UX (anexo)
- Barra institucional: "← Volver" (desktop) / ícono (móvil) + marca. Rutas sin cambios.
- Header: eyebrow, título 32/27 px, descripción neutra, metadatos en dos líneas.
- Desktop (≥960 px): índice sticky real (232 px, línea vertical, activo verde, hover,
  transición) + artículo 720 px; layout centrado máx. 1120 px. Scroll spy incluido (la última
  sección se activa al llegar al final).
- Intro tomada literalmente del texto legal; secciones "01…", 16 px / 1.65, divisores suaves;
  callout con la frase existente "No publicamos tu teléfono en el catálogo.".
- Cierre: "¿Necesitas ayuda…?" + "Ir a Contacto"; bloque "Más información" con la página actual
  marcada "Actual"; footer compacto alineado.
- Móvil/tablet: índice compacto colapsable. Contacto comparte el mismo shell.
- Contenido legal sin modificaciones.

## Tests actualizados por cambio intencional
`admin_phase_3_2` (breadcrumb y etiqueta de evento), `admin_phase_3_3` ("Vista general"
eliminado), `legal_navigation` (finders únicos; mismo flujo push/back).

## 28. PENDIENTES CODEX
- Solicitudes reales que no aparecen (datasource/RPC).
- Cola de revisión admin con error de servidor (`adminBusinessReviewPageProvider`).
- `admin_list_categories` en remoto.
- Métricas que hoy devuelven null/error (KPI muestran "—").
- Reconciliación de migraciones Supabase.
- Calendario: el sheet no tiene test de widget; conviene agregar uno cuando se exponga.
