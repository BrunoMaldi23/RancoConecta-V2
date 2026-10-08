# FASE 3.24 — UX polish: Provider Join + Legales premium (Claude)

Fecha: 2026-10-04 · Solo UX/UI frontend. Sin cambios en Supabase, RLS, RPC,
migraciones, contratos, modelos, auth, registro, consentimiento, callbacks ni
navegación funcional. Sin deploy, commit, push ni DB push.

## 1. Auditoría inicial
- Reportes leídos: 3.21, 3.22A, 3.22A.1 y 3.23.
- Cambios de Codex desde 3.23: **ninguno** en `lib/` ni `test/` (mtime revisado).
- Baseline: `flutter analyze` sin issues · `flutter test` **539/539**.
- Flujo real de `/provider/join` (sin cambios): sin sesión → `/sign-up?next=/account`
  (crear acceso); con sesión → `registerProviderIdentity()` → `/account`.

## 2. Cambios en `/provider/join`
Archivo: `lib/features/auth/presentation/sign_in_screen.dart`, solo la presentación de
`ProviderJoinScreen` (`startPublication` intacto).
- Columna de **920 px** en desktop (antes 680): la página ya no queda como una columna
  estrecha perdida en la pantalla.
- Encabezado discreto: volver (44 px) + "Ser parte de Ranco Conecta". **Se quitó el
  logo aislado** de la esquina superior; la marca se integra en el hero.
- **Hero semi-horizontal**: a la izquierda, emblema + "PARA NEGOCIOS DE LAGO RANCO",
  "Haz visible tu negocio" y "Crea tu perfil, muestra tus servicios y conecta con
  personas de la zona."; a la derecha, 3 beneficios reales (catálogo local · solicitudes
  y reservas en un solo lugar · perfil editable desde tu cuenta). Se apila en < 760 px.
- **Stepper**: horizontal en ≥ 900 px (número, conector, ícono, título, una línea de
  microcopy) y vertical compacto en tablet/móvil. Pasos: 01 Crear acceso, 02 Completar
  negocio, 03 Definir cobertura, 04 Enviar a revisión. Con sesión iniciada, el paso 01
  se marca como completado. Semántica "Paso n de 4".
- **CTA**: "Crear mi acceso" (lleva al registro, que es el paso real) o
  "Activar mi acceso prestador" si ya hay sesión. Se eliminaron "Comenzar/Continuar
  publicación" (todavía no se publica nada). Nota: "Puedes guardar tu avance y
  continuar más tarde." No aparece "Ya tengo una cuenta".

## 3. Cambios en legales (Términos y Privacidad)
Archivo: `lib/features/legal/presentation/legal_screen.dart`. Textos legales, versión,
fecha, orden de secciones, rutas y `push`/`pop` sin cambios.
- Metadatos: "Actualizado el 1 oct 2026 · Versión 2026-10-01" (misma fecha y versión).
- **"En pocas palabras"** al inicio del artículo, con ideas que ya dice el texto:
  - Privacidad: explorar sin datos personales · solo se piden datos al reservar,
    contactar un negocio o crear una cuenta · no publicamos tu teléfono en el catálogo.
  - Términos: explorar el catálogo es libre · cada negocio es responsable de la
    información que publica · una solicitud enviada no garantiza su aceptación.
  - Un solo bloque con barra lateral (no tarjeta). Reemplaza el párrafo de entrada.
- Secciones: padding 24/24, cuerpo con interlineado 1.7; número + título en línea; el
  destacado "No publicamos tu teléfono en el catálogo." se mantiene en su sección.
- Índice lateral: 212 px, línea vertical fina, elementos inactivos en gris (13,5 px),
  activo en verde; sigue siendo sticky (corrección de 3.23).
- Móvil: los chips quedan en **una sola fila de 36 px** con desplazamiento horizontal
  suave; el chip de la sección activa **se desplaza solo a la vista**. Se usa el
  controlador horizontal de la fila: un `ensureVisible` también movía el scroll vertical
  y cancelaba el salto a la sección (bug detectado por test y corregido).

## 4. Cambios en contacto y footer
- **Cierre único** (`_LegalClosing`) que reemplaza la ayuda + las tres tarjetas de
  "Más información": banda "¿Necesitas ayuda?" / "Puedes utilizar el canal de contacto
  de Ranco Conecta." + botón "Contacto", y debajo una navegación pequeña
  **Términos · Privacidad · Contacto** (enlaces subrayados con `push`; la página actual
  en negrita y sin enlace).
- Contacto usa el mismo cierre sin la banda de ayuda (no se ofrece ir a sí misma).
  Mantiene el encabezado compacto de 3.23 y los canales solo si están configurados; sin
  canales muestra el aviso existente "Canal de contacto pendiente…" (no se inventan
  correos, WhatsApp ni redes).
- Footer global: queda **inmediatamente después** del contenido (test: separación
  < 48 px; mismo componente de siempre).
- Corrección visual: el resumen usaba un borde solo izquierdo con radio (Flutter no
  admite radio en bordes no uniformes y se veía un contorno extraño); ahora es una barra
  lateral recta.

## 5. Responsive
- Tests: `/provider/join` en 390, 430, 768, 1024, 1280, 1440 y 1600 (stepper
  vertical < 1024, horizontal ≥ 1024, CTA visible, sin overflow). Términos, Privacidad y
  Contacto en 390–1600 (8 anchos, 3.23) siguen en verde.
- **Revisión real en navegador** (build release servido localmente):
  - `/provider/join` a 1440×900 y 390×844.
  - `/politica-privacidad` a 1440×900: encabezado, resumen, índice; salto desde el
    índice a "Tus opciones" con el índice fijo arriba y la sección activa marcada;
    banda de cierre, enlaces y footer inmediatamente después.
  - Nota: la ventana de la app estaba oculta, lo que congela las animaciones; en las
    capturas aparece el fundido del arranque a medio camino (no es un defecto de layout).
  - **No revisados en navegador**: Términos y Contacto (cubiertos por tests).

## 6. Tests
Nuevo `test/phase_3_24_provider_legal_test.dart` (16): join en 7 anchos (beneficios,
pasos, stepper horizontal/vertical, CTA, nota, sin "Ya tengo una cuenta" ni "Publicar"),
columna 880–960 px, CTA que mantiene el flujo `/sign-up?next=/account`, variante con
sesión (paso 01 hecho + CTA de activación), resúmenes de Privacidad y Términos, índice
desktop angosto, chips móviles en una fila que saltan a la sección, banda de cierre con
CTA y enlaces compactos + historial push/pop, Contacto sin auto-enlace y con estado
honesto sin canales.
Ajustados por cambio intencional: `phase_3_20_premium_ux_test.dart` (CTA, metadatos,
frase de privacidad presente en resumen y destacado), `access_flow_test.dart` (CTA),
`legal_navigation_test.dart` y `phase_3_23_prebeta_final_test.dart` (enlaces del cierre
localizados por `ValueKey('legal-links')`, footer inmediatamente después).

## 7. Validaciones
`dart format lib test` (0 cambios) · `flutter analyze --no-pub` sin issues ·
`flutter test` **555/555** · `check_text_encoding.ps1` OK · `git diff --check` código 0 ·
`flutter build web --release` OK (tras el último cambio).

## 8. Pendientes para Codex
- Ninguno bloqueante. Si se quiere que el paso "Crear acceso" se marque también para
  visitantes que crearon cuenta pero no confirmaron el correo, exponer ese estado
  (hoy solo se usa `currentUser()` no anónimo).

## 9. Pendientes de QA manual
- Términos y Contacto en navegador real (ventana activa): resumen, chips, cierre.
- Scroll largo con rueda/trackpad en legales (el índice sigue y se detiene al final).
- `/provider/join` con sesión real de cliente: "Activar mi acceso prestador" y llegada a
  Cuenta.
- Lectores de pantalla: anuncio "Paso n de 4" y enlaces de la navegación legal.
