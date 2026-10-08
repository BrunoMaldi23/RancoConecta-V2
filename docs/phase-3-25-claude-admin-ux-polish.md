# FASE 3.25 — Pulido UX/UI: legales, contacto, notificaciones, usuarios y configuración (Claude)

Fecha: 2026-10-04 · Diseño, UX y presentación. Sin migraciones, RLS, funciones Supabase,
Auth ni operaciones administrativas reales (no se crean administradores ni se eliminan
usuarios). Sin deploy, commit, push ni DB push.

## Estado inicial
- Reportes leídos: 3.24, 3.24.1 (Claude) y **3.24.1 (Codex)**: Codex había cambiado el
  footer de las páginas legales a `SliverToBoxAdapter`; se respetó.
- Baseline: `flutter analyze` sin issues · `flutter test` **580/580**.
- **Trabajo en paralelo con Codex (fase 3.25.1) durante esta fase**, en archivos
  compartidos: creó `lib/features/legal/application/legal_navigation.dart`
  (`openLegalPage`/`leaveLegalPage` con `returnTo`), `data/contact_repository.dart`,
  `data/consent_repository.dart`, `presentation/action_consent_dialog.dart`,
  `test/phase_3_25_1_legal_navigation_test.dart`, y editó `legal_screen.dart` (21:11–21:19),
  `consent_fields.dart`, `access_screen.dart`, `ranco_site_footer.dart` y
  `supabase/config.toml`. No toqué esa lógica; mis cambios visuales se verificaron intactos
  tras sus escrituras y mis ediciones posteriores fueron mínimas y atómicas.

## Archivos modificados (Claude)
- `lib/features/legal/presentation/legal_screen.dart` — sin resumen, navegación legal en
  píldoras, Contacto rediseñado, encabezado alineado con el contenido.
- `lib/features/notifications/presentation/notifications_screen.dart` — rediseño completo
  (misma lógica de lectura, marcado y navegación).
- `lib/features/admin/presentation/admin_settings_screens.dart` — Usuarios (barra, crear
  administrador, eliminar, detalle, filtro de estado) y Configuración (cuatro secciones).
- Tests: nuevo `test/phase_3_25_admin_ux_polish_test.dart` (37); ajustes por cambio
  intencional en `phase_3_20_premium_ux_test.dart`, `phase_3_21_ux_refactor_test.dart`,
  `phase_3_22_ux_polish_test.dart`, `phase_3_24_provider_legal_test.dart`,
  `phase_3_24_1_legal_cards_test.dart`, `admin_phase_3_2_test.dart` (vía texto).

## Cambios visuales
### 1–2. Legales
- **Eliminado "En pocas palabras"** de Términos y Privacidad (sin reemplazo). Estructura:
  barra → título/descripción/fecha y versión → cards expandibles (sin cambios: textos,
  cantidad, animación, contenido expandido) → "¿Necesitas ayuda?" → navegación legal →
  footer.
- Navegación legal: franja con separador superior, etiqueta "Información legal" y
  **píldoras** (página actual con fondo suave y sin enlace; las demás con hover/foco);
  sin "·" ni aspecto de migas de pan. La lógica de navegación es la de Codex
  (`openLegalPage`).
- El encabezado usa el mismo ancho que el contenido (1060 en legales, 1000 en Contacto):
  bordes izquierdos alineados (detectado en revisión en navegador).

### 3. Contacto
- "Hablemos" / "Consultas, ayuda y solicitudes sobre Ranco Conecta."
- Desktop (≤ 1000 px): tarjeta de formulario + columna "Para responderte mejor" (consejos
  genéricos, sin datos inventados). Móvil: apilado.
- Campos con label visible: Nombre y Correo (en fila desde 520 px), **Motivo de contacto**
  como chips (Consulta general, Problema con mi cuenta, Negocio o publicación, Privacidad
  y datos, Otro), Mensaje (5–8 líneas), texto "Responderemos utilizando los datos que nos
  proporciones en este formulario.", banners de **éxito/error** preparados
  (`_ContactBanner`, `AnimatedSize` 180 ms) y botón principal con spinner.
- El aviso "Canal de contacto pendiente…" ya no es protagonista. Los canales solo se
  muestran como tarjetas si están configurados.
- **Nota**: durante la fase Codex conectó el envío real (`contact_repository.dart`); el
  botón ahora queda habilitado según su lógica. El diseño se conservó.

### 4. Notificaciones
- Encabezado: "Revisa novedades sobre tu cuenta y actividad." + "n sin leer · m en total".
- Filtros: **[Todas] [Sin leer (n)]** (control segmentado compartido) + chips de tipo
  **Todos · Negocios · Solicitudes · Cuenta · Sistema**, derivados del `type` real
  (`notificationCategoryOf`: solicitudes/reservas/cotizaciones/mensajes, negocio/prestador/
  revisión, cuenta/rol/suspensión, resto). En < 680 px los chips van en una fila con
  desplazamiento horizontal.
- Tarjeta: ícono por tipo, punto de no leída + fondo verde suave, título, descripción
  (2 líneas), hora/fecha, categoría y chevron "Ver" solo si hay enlace.
- Grupos Hoy · Ayer · Esta semana · Anteriores. Vacío: "No tienes notificaciones
  pendientes."; filtro sin resultados: mensaje específico + "Ver todas".

### 5–8. Admin / Usuarios
- Barra: buscador · segmentos (sin cambios de lógica) · **filtro de estado** de Codex con
  estilo de menú del panel (mismo valor y efecto que su `DropdownButton`) · botón
  **"Crear administrador"**.
- Modal **Crear administrador**: Nombre, Correo, Rol (Administrador), aviso
  "Disponible cuando se habilite la creación segura de administradores." y botón final
  **deshabilitado** (no crea nada).
- Menú ⋯: Ver detalle · Cambiar rol · Suspender/Reactivar cuenta (ahora en tono neutro) ·
  **Eliminar usuario** (único en rojo) → confirmación destructiva "Esta acción es
  permanente y no se puede deshacer." con Cancelar y **Eliminar usuario deshabilitado**
  + motivo "La eliminación de cuentas aún no está habilitada."
- Detalle: avatar, "Detalle de usuario", nombre, rol y estado; secciones **Información de
  cuenta** (correo, registro), **Rol y permisos** (acciones con motivos de bloqueo) y
  **Actividad**. `admin_search_users` no devuelve última actividad ni negocio asociado,
  así que se indica que se mostrarán cuando estén disponibles (no se inventan).

### 9–13. Configuración
- Pestañas General · WhatsApp · Notificaciones · Integraciones **sin badges "Pronto"**.
- **General**: Información de la plataforma (Nombre: Ranco Conecta; Zona principal:
  Lago Ranco, Chile; Estado: No configurado), Contacto y soporte (correo/WhatsApp desde la
  configuración de la app o "No configurado"), Operación (Revisión de negocios: Manual por
  administración; Recepción de nuevas publicaciones: No configurado).
- **WhatsApp**: misma funcionalidad; "Eventos no disponibles (2)" → **"Otros eventos
  (2)"** plegado.
- **Notificaciones**: grupos Negocios / Usuarios / Plataforma con 6 interruptores y
  descripción; aviso explícito "Vista previa… Estos ajustes todavía no se guardan." (sin
  botón de guardar, sin persistencia).
- **Integraciones**: estado vacío "No hay integraciones configuradas." sin botones de
  conectar.
- Bug corregido: los interruptores estaban sobre un `Container` con fondo y su ripple/hover
  no se veía (aserción de Flutter); el grupo ahora es un `Material` con borde.

## Responsive
- Tests: Contacto 390/768/1024/1440/1600; Notificaciones con 1, 2 y 20 elementos en
  390/1024/1440; Usuarios (barra + modal) 390/768/1440; Configuración (las tres pestañas
  nuevas) 390/768/1024/1440/1600; barridos existentes en verde.

## Tests
- `phase_3_25_admin_ux_polish_test.dart` (37): sin resumen + cards; franja legal en
  píldoras; Contacto (campos, 5 motivos, texto de ayuda, selección única, 5 anchos);
  Notificaciones (categorías, filtros leído/tipo, grupos, vacío filtrado y general,
  9 combinaciones de cantidad × ancho); Usuarios (modal preparado y deshabilitado, menú con
  Eliminar en rojo y confirmación permanente deshabilitada, detalle por secciones, 3
  anchos); Configuración (General con "No configurado", vista previa de notificaciones
  sin guardar, integraciones vacías, WhatsApp con "Otros eventos", 5 anchos).

## Validación final
- `dart format` (0 cambios) · `flutter analyze` sin issues · `check_text_encoding.ps1` OK ·
  `git diff --check` código 0 · `flutter build web --release` OK.
- `flutter test`: **618 aprobados, 6 fallan**. Los 6 son tests de historial legal que
  asumen el comportamiento anterior (Términos → Privacidad → Contacto con `push` y
  "Volver" a la página legal previa):
  `legal_navigation_test.dart` (3), `phase_3_23_prebeta_final_test.dart` (1),
  `phase_3_24_provider_legal_test.dart` (1) y `phase_3_24_1_legal_cards_test.dart` (1).
  Fallan por el **cambio intencional de Codex en curso (3.25.1)**: dentro de legales usa
  `replace` y "Volver" regresa al origen (`returnTo`) o a `/`. El spec de esta fase indica
  no tocar esa lógica, y Codex estaba editando esos mismos archivos, por lo que no los
  reescribí. Quedan para su cierre de 3.25.1.

## Revisión en navegador (build release servido localmente)
- **Revisado**: Contacto 1440×900 y 390×844; Términos 1440×900; Privacidad 1024×700.
  Hallazgo corregido: encabezado desalineado respecto al contenido.
- **No revisado en navegador** (requieren sesión real; no hay credenciales): Notificaciones,
  Admin / Usuarios y Admin / Configuración. Cubiertos por pruebas de widget.
- La ventana de la app estaba oculta: algunas capturas muestran el fundido de arranque
  congelado; no es un defecto de layout.

## Pendientes para Codex
1. Actualizar los 6 tests de historial legal a la semántica `returnTo` (o retirarlos a
   favor de `phase_3_25_1_legal_navigation_test.dart`).
2. Crear administrador: RPC segura y conexión del modal (`showCreateAdminDialog`).
3. Eliminar usuario: operación segura y conexión de `showDeleteUserDialog` (hoy el botón
   final está deshabilitado).
4. Detalle de usuario: exponer última actividad y negocios asociados en
   `admin_search_users` (o una consulta de detalle) para la sección Actividad.
5. Configuración: persistencia de General (estado de plataforma, recepción de
   publicaciones) y de Notificaciones (hoy vista previa local).
6. Notificaciones: si se agregan tipos nuevos de cuenta/sistema, alinear
   `notificationCategoryOf`.
7. Contacto: verificado al cierre — el envío real de Codex usa `_reason` como asunto y
   los banners de éxito/error de esta fase, con textos ya ajustados al envío real.
