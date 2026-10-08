# FASE 3.20 — Refinamiento UX/UI pre-beta global (Claude)

Fecha: 2026-10-04 · Solo diseño, UX/UI, jerarquía, responsive y estados. Sin cambios en
Supabase, RLS, RPC, migraciones, repositorios, queries, auth ni arquitectura de roles. Sin
deploy, sin db push, sin commit. Complementa `phase-3-20-claude-premium-ux.md` (primera
pasada de esta fase) y respeta los contratos de 3.19 (Codex): rutas de detalle y flujo de
logout sin cambios.

## A. Cambios implementados

| Área | Cambio |
|---|---|
| Provider join | Sin "Ya tengo una cuenta". Columna de 680 px, encabezado compacto con emblema, hero, "Cómo funciona" 01–04 y un único CTA "Comenzar publicación". |
| Provider sign-in | Jerarquía: logo → PORTAL PARA NEGOCIOS LOCALES → Acceso proveedor → correo → contraseña → Olvidé mi contraseña → Ingresar → divisor → "¿Aún no tienes acceso proveedor? Publicar mi negocio" (→ onboarding). Tarjeta sin sombra pesada. |
| Sign-in público | Corregido texto corrupto "Ranco Conecta ? Lago Ranco" → "Ranco Conecta · Lago Ranco". |
| Footer | Ver §E. |
| Cuenta | Header con más presencia (título 28, subtítulo 14.5); tarjeta de perfil limpia (avatar 60, nombre 18, rol en badge neutro discreto, "Editar" outline secundario); Panel administrativo como módulo destacado (superficie menta, botón "Abrir panel →", apilado en < 460 px); filas de ajustes más legibles; "Cerrar sesión" fuera del contenido principal (divisor + botón de texto rojo suave). |
| Solicitudes | Control segmentado moderno (`RancoSegmentedControl`) en vez de `SegmentedButton`. Tipo turismo → "Experiencia turística". Filas en desktop / tarjetas en móvil y chips de estado (3.18) se mantienen. Carga con esqueletos. |
| Guardados | Barra contador + "Explorar más" (outline) + divisor antes de la grilla; grilla 1/2/3–4 columnas alineada a la izquierda (3.18); carga con tarjetas esqueleto con forma real. |
| Legal | Índice 232 px, artículo 760 px, footer al final de la ventana (ver §H). |
| Admin | Ver §F. |
| Estados | `RancoLoadingState`, `RancoCardSkeleton`, `RancoSuccessState`, `showRancoSuccess` (ver §D). |

Componentes nuevos:
- `core/widgets/ranco_segmented_control.dart` — `RancoSegmentedControl<T>` + `RancoSegment`
  (pista suave, opción activa blanca, contador opcional, 180 ms, desplazable en angosto).
- `core/widgets/ranco_states.dart` — estados compartidos.
- `RancoFooterSliver` (rehecho) y `RancoFooterScrollView` en `ranco_site_footer.dart`.
- `categoryIconFor` público en `categories_screen.dart` (reutilizado por admin).

## B. Pantallas revisadas

Con build release local en navegador (sin sesión; las vistas autenticadas no se pueden
abrir sin credenciales reales): `/sign-in`, `/provider/sign-in`, `/provider/join`,
`/sign-up?next=/provider/register`, Home, Términos, Privacidad, Contacto — en 1440 y 375.

Con pruebas de widget (datos simulados, sin sesión real): Cuenta (admin/visitante),
Seguridad, Guardados, Notificaciones, Solicitudes, `/admin`, `/admin/businesses`,
revisión de negocio, `/admin/users`, `/admin/categories`, `/admin/settings`,
`/admin/analytics`, `/admin/audit`.

No revisadas visualmente con datos reales: Business detail, Booking/calendario, Explore con
resultados, todas las vistas autenticadas y admin.

## C. Responsive

- Barrido `phase_3_14_responsive_test.dart`: 390, 430, 600, 768, 1024, 1200, 1280, 1366,
  1440, 1600 × 12 pantallas públicas/cuenta + 7 admin → sin overflow ni excepciones.
- Nuevo barrido de revisión de negocio en 390, 600, 768, 1024, 1366, 1440, 1600.
- Correcciones detectadas por el barrido: columna "Acciones" de usuarios (120 px), franja de
  estado de WhatsApp a 360 px, tarjeta de Panel administrativo a 360 px, esqueleto de tarjeta
  a 430 px, borde no uniforme en la cabecera fija de negocios.
- Tablas → tarjetas en angosto (negocios < 860 px, usuarios < 720 px). Los filtros
  segmentados se desplazan en horizontal si no caben (sin overflow).

## D. Estados

| Estado | Componente | Dónde |
|---|---|---|
| Loading | `RancoLoadingState` (filas esqueleto arriba, sin spinner) | Cuenta, Solicitudes, Mensajes, estado de proveedor, crear solicitud, solicitudes del proveedor, gastronomía del proveedor, gestión de servicios |
| Loading (grilla) | `RancoCardSkeleton` | Guardados |
| Loading (tabla) | esqueleto de filas | Admin negocios, usuarios, categorías, configuración, estadísticas, revisión |
| Empty | `RancoPageEmptyState` / `RancoEmptyState` (existentes) | sin cambios |
| Error | `RancoErrorState` / `AdminErrorState` (existentes); categorías ya no muestran el error técnico crudo | categorías (snackbar y diálogo) |
| Success | `RancoSuccessState` (en página) y `showRancoSuccess` (snackbar con check) | disponibles para nuevas vistas |
| Disabled / pending | acciones admin no disponibles se muestran deshabilitadas con motivo | usuarios |

Se mantuvieron los spinners de botones (enviar/guardar) y de imágenes en carga.

## E. Footer

- Desktop: superficie neutra cálida con borde superior, ancho de contenido 1120–1150
  (`RancoContainerWidth.detail`), tres columnas Ranco Conecta / Para negocios / Ayuda,
  divisor y "© 2026 Ranco Conecta · Lago Ranco, Chile". Sin "Redes / Próximamente".
  Espaciado más compacto (32 px de separación, 20/16 de padding).
- Páginas cortas: `RancoFooterSliver` usa `SliverFillRemaining`: el footer se apoya al final
  de la ventana en lugar de quedar pegado al contenido; en páginas largas va tras el
  contenido. Cuenta (3 variantes) y Legal/Contacto se migraron a slivers para obtener el
  mismo comportamiento.
- Móvil: una sola columna compacta (título de grupo + enlaces en línea), sin acordeones.
- La vista de cuenta visitante sigue cabiendo sin scroll a 390×850.

## F. Admin

- **Dashboard**: header existente (Panel administrativo + descripción + Revisar pendientes /
  Configuración / Cuenta). Fila KPI de 4 (Pendientes, Publicados, Rechazados, Usuarios; 2 por
  fila en angosto, "—" si no hay dato). Debajo, Revisiones pendientes | Actividad reciente.
  Al final, "Accesos rápidos" como botones compactos. Se eliminaron la grilla de módulos
  repetida, el bloque WhatsApp y "Estado de la plataforma"; en su lugar aparece un aviso
  ámbar **solo** si los avisos WhatsApp no están configurados o están desactivados.
  En móvil, Revisiones pendientes va primero (lo que requiere atención).
- **Negocios**: cabecera de tabla fija (`SliverMainAxisGroup` + header pinned) mientras la
  tabla está visible; filtros de estado con el control segmentado; paginador
  "1–20 de 54 · Filas [20] · ‹ 1 / 3 ›" (primera/última solo con más de 3 páginas);
  esqueleto de carga.
- **Usuarios**: segmentos Todos / Usuarios / Visitantes / Prestadores / Administradores;
  tabla Usuario · Correo · Rol · Estado · Registro · Acciones ("Ver" + menú "⋯").
  `AdminUserActions` (callbacks `onToggleSuspension`, `onChangeRole`) deja la UI lista para
  Codex: sin callback las acciones se ven deshabilitadas con el motivo "Disponible cuando se
  habilite la gestión segura de cuentas."; con callback, siempre pasan por confirmación
  (suspender en rojo). Detalle de usuario con avatar, rol/estado, campos y acciones.
- **Categorías**: ícono real por categoría, badge "Inactiva" solo cuando aplica (fila
  atenuada), contador con plural, diálogo "Crear categoría" / "Editar categoría",
  confirmación para desactivar/eliminar y mensajes humanos (categoría en uso, slug duplicado).
- **Configuración**: título "Avisos administrativos por WhatsApp"; franja de estado
  (Activo/Inactivo + número configurado); bloque único: Activar avisos → Número
  administrador → Eventos (3 casillas) → aviso "Ranco Conecta prepara el mensaje. El envío
  se confirma manualmente en WhatsApp." → Guardar; "Eventos no disponibles (2)" plegado.
- **Estadísticas**: "Actividad últimos 30 días" con 4 KPI reales; vacío compacto "Aún no hay
  suficiente actividad para mostrar tendencias." (sin gráfico falso); lista "Interacciones y
  plataforma" (clics en teléfono, negocios publicados, usuarios registrados, solicitudes y
  reservas = "—" con explicación).
- **Revisión de negocio**: header (nombre, tipo, categoría, propietario, estado). Desktop:
  navegación por secciones Resumen / Requisitos (n pendientes) / Servicios / Cobertura /
  Archivos / Historial — una sección visible a la vez — y riel "Decisión" fijo a la derecha
  (cada columna con su propio scroll, sin scroll anidado). Móvil: decisión arriba y
  secciones en acordeones (solo Resumen abierto). Nueva sección Archivos con los medios
  existentes (tipo + nombre de archivo).
- **Sidebar admin**: misma lógica de grupos que el público (Operación / Catálogo /
  Plataforma).

## G. Provider

- `/provider/join`: ver §A. El acceso de quien ya tiene cuenta sigue en `/provider/sign-in`
  (no se duplica la navegación).
- `/provider/sign-in`: ver §A. No se agregó "Explorar como visitante".
- Gastronomía del proveedor, estado de publicación y gestión de servicios: carga con
  `RancoLoadingState`.

## H. Legal

- Header de página en banda integrada: INFORMACIÓN LEGAL, título, descripción y badges de
  "Última actualización" y "Versión".
- Desktop: índice sticky 232 px + contenido 760 px; secciones 01–05 con divisores sutiles;
  callout de superficie solo para "No publicamos tu teléfono en el catálogo."; cierre
  "¿Necesitas ayuda…?" + "Ir a Contacto" y bloque "Más información".
- Móvil: índice compacto plegable arriba.
- Footer al final de la ventana en páginas cortas (Contacto). Contenido legal intacto.

## I. Pendientes para Codex

1. **Acciones de usuarios**: conectar `AdminUsersScreen(actions: AdminUserActions(...))`
   cuando exista la RPC segura (suspensión que revoque sesiones/RLS, cambio de rol,
   validación de último admin, auditoría). La UI ya confirma antes de ejecutar.
2. **Estado "En curso" en Solicitudes**: `CustomerActivityStage` no tiene etapa en curso;
   el chip "En curso" pedido requiere que la fuente exponga ese estado (hoy cae en
   Aceptada/otro).
3. **Métrica de solicitudes/reservas** en Estadísticas: no existe agregado; se muestra "—".
4. **Serie temporal** para tendencias de analítica (no se dibuja gráfico sin datos).
5. **Archivos en revisión**: la RPC entrega `business_media`; si se desea vista previa de
   imágenes en la revisión, confirmar que la URL pública/firmada sea apropiada para admin.
6. **QA con sesión real**: Cuenta, Solicitudes con datos, Guardados, admin completo,
   detalle de reserva (3.19) y transiciones login→cuenta / logout→login en navegador.
7. Canal de contacto de producción (`CONTACT_EMAIL`/`CONTACT_WHATSAPP`) sigue sin
   configurar; Contacto muestra la alternativa neutral.

## Tests actualizados por cambios visuales legítimos

- `phase_3_20_premium_ux_test.dart`: "Ya tengo una cuenta" ya no existe; ancho 620–700;
  nuevas pruebas de revisión de negocio (secciones, acordeones, 7 anchos), acciones de
  usuario deshabilitadas y acceso proveedor → onboarding.
- `legal_navigation_test.dart`: el footer ahora es un sliver perezoso → se usan finders
  `hitTestable()` para desplazar hasta el enlace visible.
- `admin_phase_3_3_test.dart`: "Estado de la plataforma" (eliminado) → "Accesos rápidos".
- `admin_phase_3_2_test.dart`: el filtro de rol ya no es `ChoiceChip`; se asegura su
  visibilidad antes de tocar (control desplazable).
- `auth_provider_separation_test.dart`: la espera de auth muestra `RancoLoadingState` en
  vez de un spinner.
