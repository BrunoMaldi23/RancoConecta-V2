# FASE 3.21 — Refactor UX/UI global + hub prestador (Claude)

Fecha: 2026-10-04 · Solo UX/UI, layout, estados y navegación perceptual. Sin cambios en
Supabase, RLS, RPC, migraciones, contratos de datos, reglas de roles ni lógica sensible.
Sin deploy, sin commit, sin push.

Validaciones: `dart format lib test` · `flutter analyze --no-pub` sin issues ·
`flutter test` **462/462** OK (37 nuevos en `test/phase_3_21_ux_refactor_test.dart`) ·
`check_text_encoding.ps1` OK · `git diff --check` limpio · `flutter build web --release` OK.

> **Trabajo en paralelo con Codex.** Durante la fase Codex modificó `app_router.dart`
> (nueva ruta unificada `/provider/business`, `/provider/status` y `/provider/dashboard`
> redirigen a ella), `supabase_auth_repository.dart` (`providerRegistration`),
> `sign_in_screen.dart` (flujo de registro de prestador con `next=/account`, botón
> "Ser parte de Ranco Conecta"), `account_screen.dart` (estado de carga/errores del negocio,
> `onManage → /provider/business`), `admin_settings_screens.dart` y la migración
> `20261004120000_provider_identity_and_draft_reuse.sql`. No toqué el router ni la lógica de
> auth; en los archivos compartidos hice solo ediciones de presentación acotadas. El hub se
> alineó a `/provider/business`.

## 1. Flujo prestador

- **Acceso proveedor** (`/provider/sign-in`): bajo "Ingresar" → divisor →
  "¿Aún no tienes acceso proveedor?" → botón secundario de ancho completo
  **"Ser parte de Ranco Conecta"** → subtexto "Crea tu acceso para gestionar tus servicios o
  negocio.". Ya no se usa "Publicar mi negocio" como acción de registro.
- **Onboarding** (`/provider/join`): título de barra "Ser parte de Ranco Conecta".
- **Crear acceso** (registro prestador): título "Crea tu acceso", subtítulo
  "Únete a Ranco Conecta como prestador.", campos Nombre completo / Correo / Contraseña /
  Confirmar contraseña, bloque "Antes de continuar" con las 3 casillas (3.20, cada una con su
  "Ver …"), CTA "Crear acceso" y pie **"¿Ya tienes acceso? Ingresar"**. Textos legales de
  aceptación sin cambios.

## 2. Cuenta

- Tarjeta **Mi negocio** rediseñada: ícono del tipo, nombre, tipo ("Servicio",
  "Alojamiento"…), badge semántico con punto y etiqueta canónica (**Borrador, En revisión,
  Publicado, Cambios solicitados, Rechazado, Suspendido…** — antes decía "Pendiente"),
  frase de contexto cuando no está publicado ("Estamos revisando tu publicación.") y un único
  CTA **"Gestionar negocio"** (ancho natural en desktop, completo en móvil).
  "Ver perfil público" (ícono con tooltip) y accesos Reservas/Calendario solo si está
  publicado.
- Sin negocio asociado: "Configura tu negocio" + "Comenzar configuración".
- **Carga**: esqueleto con la forma real (encabezado, tarjeta de perfil, tarjeta de negocio)
  en lugar de filas genéricas/spinner. Se eliminó el helper `_publicationLabel` (quedó sin
  uso).
- Seguridad ("Contraseña y sesión actual") y "Cerrar sesión" separados, como en 3.20.

## 3. Hub "Mi negocio"

Nuevo `lib/features/provider_dashboard/presentation/provider_hub.dart`:

- `providerHubSections(capabilities, type)`: secciones por tipo de negocio con las mismas
  capacidades/limites que el tablero anterior, en orden operación → contenido → perfil.
  - Servicio: Solicitudes · Servicios · Cobertura · Fotos · Perfil
  - Alojamiento: Reservas · Calendario · Tarifas · Fotos · Alojamiento
  - Gastronomía: Reservas (si plan) · Menú · Fotos · Perfil
  - Comercio: Horarios · Ubicación · Fotos · Perfil y contacto (antes "Perfil" y "Contacto"
    eran dos tarjetas a la misma ruta)
  - Turismo / Emergencia: Fotos · Perfil (+ Cobertura en emergencia)
  - Secciones sin pantalla (Productos, Experiencias, Disponibilidad, reservas Pro) se
    listan como "Próximamente en tu plan" con candado y tooltip, sin pestaña.
- `ProviderHubTabBar`: pestañas **Resumen + secciones**, subrayado verde, scroll horizontal
  en móvil, 46 px de alto táctil. Va en el `bottom` del AppBar (nuevo parámetro
  `RancoAppBar.bottom`) del resumen y de **todas** las pantallas de gestión existentes
  (perfil, servicios, cobertura, ubicación, horarios, solicitudes, reservas, calendario,
  fotos, tarifas, alojamiento, menú, reservas de mesa). Cada pestaña abre la misma ruta que
  antes; el router conserva sus guardas. Solo aparece con negocio publicado.
- `ProviderHubHeader`: ícono, nombre, tipo, badge de estado, "Cambiar negocio" (si hay
  varios) y "Ver perfil público" (si está publicado).
- **Resumen publicado** (`ProviderDashboardScreen`): header → métricas reales de servicio
  (servicios, localidades, días de atención, solicitudes nuevas) → 2 columnas en desktop:
  **Solicitudes recientes** (4 últimas con estado y "Ver todas") | **Acciones rápidas**
  (Ver perfil público, Editar negocio, Gestionar fotos) + "Próximamente en tu plan". Otros
  tipos muestran "Gestión" en la columna principal. Carga con esqueleto; error compacto con
  Reintentar.
- **Resumen no publicado** (`ProviderBusinessStatusScreen`, ya no es una pantalla aislada):
  - Borrador: "Tu publicación aún no está visible." + **Progreso de configuración**
    ("n de 5", barra y checklist Tipo / Información / Categoría / Cobertura / Revisión,
    calculado del borrador guardado con la lectura existente `getBusinessDraft`) + CTA
    **"Continuar configuración"**. El asistente no se abre solo.
  - En revisión: "Estamos revisando tu publicación." + "Enviado el dd/mm/aaaa" + **Qué
    sigue** (3 pasos) + "Volver a Cuenta" + "Avisar al administrador por WhatsApp" solo si
    `reviewWhatsAppDetailsProvider` devuelve datos (sin cambios de lógica).
  - Cambios solicitados / Rechazado / Suspendido: "Observación del equipo" destacada y
    seleccionable; CTA "Corregir publicación" cuando aplica.
  - Sin negocios: estado vacío "Aún no tienes un negocio" + "Crear negocio".
- Nuevo `providerBusinessDraftProvider` (`application/business_onboarding_providers.dart`):
  envuelve la lectura existente del repositorio; no agrega consultas nuevas.

## 4. Wizard (5 pasos)

`provider_registration_screen.dart` — misma lógica de guardado, validación y envío
(métodos `_saveDraft`, `_next`, `_submit`, etc. intactos salvo la animación de página):

- Pasos: **Tipo · Información · Categoría · Cobertura · Revisión**.
- Columna de 760 px. Stepper fijo compacto: en ≥ 560 px círculos numerados con check y
  etiquetas; en móvil "Paso 2 de 5 · Información" + barra segmentada.
- Cambio de paso con fade (`AnimatedSwitcher`, 250 ms) en lugar de `PageView`: sin
  saltos de altura y cada paso empieza arriba.
- Acciones **pegadas al formulario** (no al borde de la ventana): "Atrás" (outline) y
  primario de ancho natural (≥ 160 px) a la derecha; en móvil dos botones en fila.
  "Guardar" sigue en la barra superior. Errores y "Borrador guardado." aparecen junto a
  las acciones.
- Tipo: tarjetas verticales en grilla 2–3 columnas de igual alto con check de selección.
- Información: campos con label (accesibles), descripción con ayuda "Mínimo 20 caracteres.",
  contacto en pares (Teléfono/WhatsApp, Correo/Sitio web) en desktop.
- **Categoría**: el dropdown de 27 opciones se reemplazó por un campo seleccionable que abre
  un **selector con búsqueda** (diálogo en desktop, bottom sheet en móvil) agrupado
  editorialmente: Turismo · Alojamiento · Gastronomía · Servicios · Emergencias · Otros
  (`categoryPickerGroup`, solo presentación; datos intactos).
- Servicios de la categoría: chips seleccionables con contador "n seleccionados".
- Cobertura: "Selecciona dónde atiendes" + contador "2 localidades seleccionadas" + chips.
- **Revisión**: resumen seccionado **Negocio · Actividad · Cobertura · Contacto** con
  "Editar" por sección (vuelve al paso sin perder datos), localidades unidas con " · ",
  "Pendiente" en rojo suave para lo que falta; **Requisitos** con "n de m listos";
  "Confirmo que la información es correcta"; CTA **"Enviar a revisión"**.
- Salir desde el paso 1 vuelve a `/account` (antes `/provider/join`); tras enviar, al hub.

## 5. Footer

- **Bug corregido**: dentro de `RancoFooterSliver` el `Align` interno de
  `RancoContentContainer` se expandía y la superficie gris del footer rellenaba todo el
  hueco de las páginas cortas (bloque gris enorme). Ahora el footer mide lo que su
  contenido y se apoya al fondo de la ventana; en páginas largas va tras el contenido.
  Cubierto por dos tests (página corta / larga).
- Diseño de 3.20 sin cambios: 3 columnas (Ranco Conecta / Para negocios / Ayuda), sin
  "Redes próximamente", fondo neutro.

## 6. Sidebar / drawer

- Logo del sidebar más presente (emblema 42 px, texto 18) manteniendo el asset real.
- "Mi negocio" (sidebar y top bar) abre `/provider/business` directamente (sin salto por
  redirección).
- Drawer móvil: todas las entradas de negocio abren el hub; antes un borrador abría el
  asistente directamente.
- Jerarquía Descubrir / Tu actividad / Cuenta / Gestión / Administración y "Cerrar sesión"
  abajo, ya existentes.

## 7. Solicitudes

- Sin cambios estructurales (3.18–3.20 ya cumplen: contador, segmentos Activas /
  Cotizaciones / En curso / Finalizadas, filas desktop/tarjetas móvil, footer tras el
  contenido). Solicitudes del prestador ahora viven dentro del hub (pestaña + bloque
  "Solicitudes recientes").

## 8. Guardados

- Sin cambios (grilla 1/2/3–4 alineada a la izquierda dentro del contenedor y
  `BusinessCard` compartida desde 3.18/3.20).

## 9. Notificaciones

- Grupos **Hoy · Ayer · Esta semana · Anteriores** (antes sin "Esta semana").
- Fila compacta: padding 12, ícono 36 que distingue leída/no leída (no solo color: punto +
  peso tipográfico + etiqueta semántica "No leída"), cuerpo a 2 líneas.
- Vacío: "No tienes notificaciones" / "Cuando haya novedades sobre solicitudes o tu cuenta
  aparecerán aquí."

## 10. Admin

- **Configuración**: navegación superior General · **WhatsApp** · Notificaciones ·
  Integraciones. Solo WhatsApp es funcional; las demás se ven deshabilitadas con "Pronto"
  y tooltip, sin pantallas vacías. El bloque de WhatsApp (3.20) queda debajo.
- **Auditoría**: cabecera de tabla Fecha · Actor · Acción · Recurso · Resultado (desktop)
  sobre el estado vacío informativo; en angosto se omite (se presentará como línea de
  tiempo).
- Resumen, Negocios, Usuarios, Categorías, Estadísticas y Revisión: se mantiene lo
  entregado en 3.20 (KPI + 2 columnas, cabecera fija, paginador, segmentos de usuarios con
  acciones con tooltip/motivo, CRUD de categorías con diálogo, revisión con pestañas y riel
  de decisión fijo). No se rehicieron para no pisar el trabajo de Codex en
  `admin_settings_screens.dart`.

## 11. Legal

- Sin cambios en esta fase: banda de encabezado, fecha/versión, índice lateral sticky en
  desktop y desplegable "En esta página" en móvil, columna de 760 px (3.20).

## 12. Responsive

- Nuevos barridos (390, 430, 768, 1024, 1366, 1440, 1600): hub publicado y no publicado.
  Cuenta prestador (390/768/1440) y asistente (390/430/768) sin overflow.
- Barrido existente `phase_3_14_responsive_test.dart` (12 pantallas + 7 admin × 10 anchos)
  sigue en verde, incluida Configuración con la nueva navegación.
- Hub: header en columna < 620 px, pestañas con scroll horizontal, métricas 2 por fila en
  móvil, columnas apiladas < 860 px. Wizard: stepper compacto < 560 px, campos en pares
  ≥ 520 px, acciones en fila.

## 13. Loading / error states

- `RancoErrorState` rediseñado (afecta a todas sus pantallas): ícono suave, título humano,
  texto breve ("Inténtalo nuevamente en unos segundos." si hay reintento), botón
  "Reintentar" de 44 px; alineado arriba, ancho máx. 440; variante `compact` para bloques
  dentro de una página. Nuevo parámetro opcional `detail`. Nunca muestra el error técnico.
- Nuevos `RancoSkeletonBox` y `RancoSkeletonCard` (`ranco_states.dart`) para componer
  esqueletos con la forma real: Cuenta (perfil + negocio), resumen del hub, solicitudes
  recientes, chips de servicios/localidades y categoría en el asistente.
- Asistente: carga con `RancoLoadingState` en vez de spinner centrado.
- Barra de progreso del borrador: el test detectó que `semanticsValue` debía ser
  porcentaje (Flutter lo valida); corregido.

## 14. Pendientes para Codex

1. **`_ProviderBusinessHub` en `app_router.dart`**: el estado de carga es un
   `CircularProgressIndicator` centrado y el error un texto suelto. Sugerencia: reutilizar
   `ProviderDashboardScreen`/`ProviderBusinessStatusScreen` con su propio esqueleto o
   `RancoLoadingState`, y `RancoErrorState(message: 'No pudimos cargar tu negocio.', onRetry: …)`.
2. **Métricas del prestador (Vistas / Contactos)**: no existe una consulta segura por
   negocio para el prestador; el resumen solo muestra métricas reales de gestión. Exponer
   un RPC `provider_business_metrics(business_id)` (vistas, clics de contacto/WhatsApp,
   guardados) para agregarlas al resumen.
3. **Fotos antes de publicar**: el router bloquea `/provider/photos` para negocios no
   publicados, por eso el progreso del borrador no incluye "Fotos". Si se habilita, sumar
   el paso al checklist.
4. **Edición en revisión**: el hub no ofrece "Editar" mientras está `pending_review`
   porque `canContinueOnboarding` lo impide. Si el backend lo permite, exponer la regla y
   se agrega el botón.
5. **Admin Configuración — General / Notificaciones / Integraciones**: hoy deshabilitadas
   ("Pronto"). Al existir backend, conectar cada sección.
6. **Admin Auditoría**: consulta paginada (fecha, actor, acción, recurso, resultado) para
   llenar la tabla ya preparada.
7. **Agrupación de categorías**: el selector agrupa por slug/nombre. Un campo
   `group`/`vertical` en `categories` haría la agrupación exacta y editable desde admin.
8. **Tests de auth**: `_FakeAuthRepository` en `access_flow_test.dart` y
   `ranco_navigation_drawer_test.dart` ya fueron actualizados por Codex al nuevo
   `providerRegistration`; ajusté solo el finder del botón "Ser parte de Ranco Conecta"
   (ahora `OutlinedButton`).
9. No revisado en navegador con sesión real (requiere credenciales): hub, asistente,
   Cuenta prestador y Admin. Cubiertos por pruebas de widget y barridos de layout.

## Archivos tocados (Claude)

- Nuevos: `provider_dashboard/presentation/provider_hub.dart`,
  `provider_registration/application/business_onboarding_providers.dart`,
  `test/phase_3_21_ux_refactor_test.dart`, este documento.
- Reescritos (UI): `provider_dashboard_screen.dart`, `provider_business_status_screen.dart`,
  `provider_registration_screen.dart` (UI; lógica conservada), `ranco_error_state.dart`.
- Ediciones acotadas: `ranco_app_bar.dart` (`bottom`), `ranco_states.dart` (esqueletos),
  `ranco_site_footer.dart` (altura), `account_screen.dart` (tarjeta de negocio, esqueleto),
  `sign_in_screen.dart` (textos prestador), `notifications_screen.dart`,
  `admin_settings_screens.dart` (navegación de secciones), `admin_screens.dart` (auditoría),
  `app_shell.dart` y `ranco_navigation_drawer.dart` (ruta del hub, logo),
  `service_management_screens.dart`, `provider_requests_screen.dart`,
  `provider_bookings_screen.dart`, `provider_gastronomy_screens.dart`,
  `lodging_calendar_screen.dart`, `lodging_information_screen.dart`,
  `lodging_photos_screen.dart`, `lodging_rates_screen.dart` (pestañas del hub).
- Tests actualizados por cambio intencional: `phase_3_20_premium_ux_test.dart`
  (agrupación con "Esta semana"; botón de registro; acciones de usuarios admin ahora
  habilitadas tras el backend de Codex), `commerce_management_test.dart`
  (secciones en el hub), `auth_provider_separation_test.dart` (esqueleto de Cuenta),
  `access_flow_test.dart` (tipo de botón), `ranco_navigation_drawer_test.dart` (ruta
  `/provider/business` registrada en el router de prueba).
