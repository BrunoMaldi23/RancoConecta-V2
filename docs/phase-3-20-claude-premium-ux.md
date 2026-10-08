# FASE 3.20 — Premium UX/UI polish + consistencia de flujos (Claude)

Fecha: 2026-10-03 · Solo UI/UX. Sin cambios en Supabase, RLS, RPC, migraciones, políticas,
modelos, auth ni queries. Sin deploy ni commit.

Validaciones: `check_text_encoding.ps1` OK · `flutter analyze --no-pub` sin issues ·
`flutter test` 412/412 OK · `git diff --check` limpio · `flutter build web --release` OK.
`dart format --set-exit-if-changed lib test` marca **solo** `lib/router/session_actions.dart`,
archivo que Codex está editando en paralelo (no lo toqué).

> Trabajo en paralelo: durante la fase Codex modificó `auth_controller`, `app_router`,
> `session_actions`, providers de admin/favoritos/mensajes/notificaciones/solicitudes,
> `admin_settings_screens.dart`, `explore_screen.dart` y creó `reservation_detail_screen.dart`.
> Para no pisar su trabajo, **no edité esos archivos** (ver §14).

## Auditoría visual previa
Build local servido en 1440 y 375/390. Hallazgos principales:
- Publicar negocio: columna de 580 px perdida en 1440, jerarquía plana.
- Crear acceso: logo diminuto (asset con texto a 56 px), consentimientos con enlaces
  desacoplados de cada casilla ("Lee los … y la …").
- Legal: encabezado sin integración con el cuerpo, metadatos planos, índice 232 px.
- Footer móvil: lista plana sin grupos.
- Botones secundarios con borde verde fuerte (todo verde), sin anillo de foco de teclado.

## 1. Cambios visuales
- Jerarquía de botones global: primario verde lleno; secundario outline **neutro** con texto
  verde (hover → borde verde); terciario texto. Destructivo solo en rojo suave y donde aplica.
- Anillo de foco de teclado (2 px, tinta) en Filled/Outlined/Text buttons; halo verde en
  InkWell/ListTile vía `focusColor`.
- Roles tipográficos en `RancoTheme` (displaySmall, headlineSmall, titleLarge 20, titleMedium,
  bodyLarge/Medium/Small, labelLarge/Medium) para reducir tamaños locales.
- Temas de checkbox, tabs, diálogo, popup menu, tooltip y progress unificados.
- Transición de ruta discreta (fade + 1 % de desplazamiento, entra en ~210 ms); iOS conserva
  la transición nativa con gesto de volver.

## 2. Componentes compartidos
- `RancoHoverSurface` (nuevo, `core/widgets/ranco_hover_surface.dart`): superficie clicable con
  borde/sombra leve al hover y borde de foco visible. Usada por tarjetas de negocio y
  categorías de Home (desktop).
- `RancoDurations.quick` (180 ms) y `RancoWidths` (auth 500, flow 760, reading 720,
  sideIndex 212) en `ranco_tokens.dart`.
- `RancoContainerWidth.legal` → 1000 (alineado con el nuevo layout legal; no tenía usos).
- `ConsentFields` rediseñado (ver §4/§9).
- `RancoSiteFooter`: títulos de grupo discretos (gris, versalitas), hover en enlaces, layout
  móvil en dos columnas agrupadas.

## 3. Responsive
- Barrido automático ampliado a 390, 430, 600, 768, 1024, 1200, 1280, 1366, 1440 y 1600
  (`phase_3_14_responsive_test.dart`), 12 pantallas públicas/cuenta + 7 admin: sin overflow
  ni excepciones.
- Revisión en navegador (build release local): Publicar negocio y Privacidad en 1440;
  Crear acceso, Términos y footer en 375.
- Footer móvil: dos columnas con métricas compactas (filas de 28 px) para que la vista de
  cuenta de visitante siga cabiendo sin scroll a 390×850 (garantía de test existente).

## 4. Legal
- Banda de encabezado integrada (blanco → menta muy suave, borde inferior) con contenido de
  máx. 900 px: eyebrow, título 36/28, resumen, chips de "Última actualización" y "Versión".
- Debajo: índice sticky de 212 px + artículo de 720 px (layout 1060 con padding), gap 56.
- Párrafo de entrada (frase literal del documento) con acento lateral.
- Secciones numeradas con chip "01", título 22, cuerpo 16/1.7 y divisores; sin tarjetas.
- Callout único con la frase existente "No publicamos tu teléfono en el catálogo.".
- Ayuda: superficie menta sin borde + "Ir a Contacto" con ícono.
- Términos usa el mismo sistema. **Contenido legal sin modificaciones.**
- Contacto: misma banda; si no hay canal configurado, mensaje neutro con alternativa
  (revisar Términos/Privacidad). No se inventan email, teléfono ni WhatsApp.

## 5. Public / Discovery
- Tarjeta de negocio: hover con borde + sombra leve (sin cambios de contenido; "Verificado"
  sigue ausente, "Destacado" sin cambios).
- Favorito: corazón **optimista** (cambia al instante), toques repetidos bloqueados mientras
  confirma, **rollback** si falla o si el visitante debe iniciar sesión; animación
  scale+fade de 180 ms; carga inicial con contorno atenuado en vez de spinner (sin salto).
- Categorías de Home (desktop): hover con borde en el tono de la categoría.
- Explore/Home: sin cambios de estructura (Codex trabaja en `explore_screen.dart`).

## 6. Account
- Seguridad: ancho de lectura (640), tarjetas con ícono en contenedor suave, estado de sesión
  como badge semántico ("Activa"), "Sesión actual" (no "Sesiones activas"), y bloque propio
  "Cerrar sesión" con explicación y botón outline rojo suave (diferenciado, no alarmista).

## 7. Requests / Notificaciones
- Notificaciones agrupadas en **Hoy / Ayer / Anteriores** en frontend
  (`groupNotificationsByDay`, orden original intacto), encabezados semánticos, no leídas con
  fondo menta + punto, hora para hoy y fecha para el resto, cuerpo a 3 líneas.
- Carga con esqueletos de la misma altura que las filas (antes spinner centrado).
- Solicitudes: se mantiene la estructura de 3.18 (filtro Activas/Cotizaciones/En curso/
  Finalizadas ya existente). No se tocó por el trabajo en curso de Codex en ese módulo.

## 8. Booking
- Pluralización corregida: "1 noche", "1 huésped" en ficha de alojamiento, perfil público,
  resumen de fechas y reservas del proveedor. Sin cambios de layout ni lógica.

## 9. Provider
- **Publicar mi negocio** (mismo flujo y callbacks): columna de 760 px; barra con volver
  (44 px) + título + emblema; hero menta sin borde (ícono 52, título 34/27, texto 16.5);
  sección "Cómo funciona" con timeline de 4 pasos a mayor escala (badges circulares 40 px,
  título 17, texto 15, ícono por paso en desktop); CTAs: primario "Comenzar publicación" +
  secundario outline "Ya tengo una cuenta"; nota "Puedes guardar el progreso…" integrada.
- **Crear acceso**: emblema de marca real a 52 px (antes logo ilegible), tarjeta 500 px con
  sombra leve, CTA 50 px, retorno con área táctil de 44 px.
- **Consentimientos**: bloque "Antes de continuar" con tres filas separadas por divisores;
  cada casilla alinea su texto y, debajo, su enlace "Ver términos ↗" / "Ver política de
  privacidad ↗". El enlace no marca la casilla. Ninguna casilla marcada por defecto.
  Textos de aceptación **sin cambios** (no se cambió "Acepto…" por "He leído…" ni se amplió el
  alcance del tratamiento de datos, para no alterar el significado legal).

## 10. Admin
- Revisión de negocio:
  - Encabezado claro (antes bloque verde lleno): ícono del tipo de negocio, nombre, meta
    (tipo · categoría · propietario) y badge semántico de estado.
  - Información general / Propietario y contacto: dos tarjetas de igual ancho (antes 420 px
    fijos que dejaban huecos), filas etiqueta/valor, "—" para vacíos, valores seleccionables.
  - Secciones (Requisitos, Servicios, Cobertura, Alojamiento, Historial) con separación
    consistente y bordes suaves.
  - **Riel de decisión** con jerarquía: Publicar/Restaurar llenos (primarios), Solicitar
    cambios outline, Rechazar/Suspender separados por divisor en rojo suave. Solo se muestran
    las acciones permitidas por `AdminReviewPolicy` (mismas reglas); si no hay ninguna, texto
    explicativo. Sin scroll interno.
- `_StatusPill` usa siempre el badge compartido (`RancoStatusBadge`).
- Configuración (WhatsApp), Usuarios, Categorías, Analítica y Auditoría: **no modificados**
  en esta fase (ver §14).

## 11. Accessibility
- Foco visible en botones, enlaces del footer, superficies clicables e índice legal.
- Semántica: encabezados de grupo en notificaciones, "No leída", "Paso N de 4" en el
  timeline, botones en superficies hover.
- Áreas táctiles: volver 44 px, CTAs 50–52 px, enlaces de consentimiento 32 px dentro de
  filas de checkbox de 48 px.
- Contraste: textos secundarios en `textSecondary` sobre blanco/menta; títulos de footer
  en gris oscuro en vez de verde.

## 12. Microinteractions
- Favorito (180 ms scale+fade, optimista con rollback).
- Hover de tarjetas/categorías (180 ms).
- Transición de ruta discreta.
- Índice legal: transición del activo existente (180 ms).
- Loading → contenido en notificaciones con esqueletos de igual altura.

## 13. Tests
- Nuevo `test/phase_3_20_premium_ux_test.dart`: agrupación Hoy/Ayer/Anteriores, grupos vacíos
  omitidos, consentimientos sin marcar y enlace que no marca la casilla, Publicar negocio en
  390/1440 (CTAs presentes, columna ≥ 700 px en desktop), metadatos y callout legal.
- `phase_3_14_responsive_test.dart`: anchos 430 y 1280 añadidos.
- `access_flow_test.dart`: el helper marca la casilla (`Checkbox`) en lugar del centro de la
  fila, porque la fila ahora incluye el enlace "Ver …" (cambio visual legítimo).

## 14. Pendientes técnicos para Codex
- `lib/router/session_actions.dart` no pasa `dart format --set-exit-if-changed`.
- **Admin Configuración** (`admin_settings_screens.dart`, en edición por Codex): reorganizar
  en Estado actual → Canal de avisos → Número administrador → Eventos activos → Eventos no
  disponibles → Guardar, separando lo editable de lo descriptivo. Pendiente para cuando el
  archivo esté libre.
- **Admin Usuarios / Categorías**: CRUD a cargo de Codex; al exponerlo, aplicar el mismo
  sistema (badge de estado/rol, menú de acciones, buscador, paginador, diálogo limpio,
  estado "eliminación bloqueada").
- **Detalle de solicitud** (`reservation_detail_screen.dart`, nuevo de Codex): alinear con
  header + estado + resumen + detalles + timeline + acciones, usando `RancoStatusBadge`.
- **Explore** (`explore_screen.dart`, modificado por Codex): pendiente refinar filtros en
  bottom sheet móvil y sidebar compacta.
- Riel de decisión sticky en revisión admin: requiere sacar el detalle de `ListView` a un
  `CustomScrollView`/layout con scroll propio; no se hizo para no introducir scroll anidado.
- No revisados visualmente en navegador (requieren sesión/datos reales): cuenta,
  solicitudes, guardados, admin y calendario abierto. Cubiertos por los barridos de layout.
