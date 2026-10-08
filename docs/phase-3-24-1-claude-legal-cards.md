# FASE 3.24.1 — Legales en cards expandibles (Claude)

Fecha: 2026-10-04 · Solo presentación. Sin cambios en backend, Supabase, RLS, Auth,
router, contenido legal ni flujo de registro. `/provider/join` no se tocó. Sin deploy,
commit ni push.

## Auditoría inicial
- Sin cambios de Codex desde 3.24 (mtime revisado en `lib/`, `test/` y `docs/`).
- Único archivo de producción modificado: `lib/features/legal/presentation/legal_screen.dart`.

## Cambios
### Términos y Privacidad
- **Se eliminó** el índice lateral "En esta página", su lógica sticky/scroll-spy, los
  chips móviles y el layout de artículo largo.
- Se conservan: barra superior, encabezado (título, descripción, "Actualizado el 1 oct
  2026 · Versión 2026-10-01"), "En pocas palabras", cierre legal y footer global.
- Las secciones (Privacidad 01–05, Términos 01–04) son **cards expandibles** en un grid
  de **1060 px** máximo:
  - Desktop (≥ 760 px de contenido): **dos columnas independientes** con separación de
    16 px; abrir una card no estira a su vecina. Con un número impar (Privacidad), la
    card 05 ocupa el ancho completo.
  - Tablet/móvil: una columna, sin scroll horizontal.
- **Card cerrada**: número, ícono discreto, título, **primera oración literal** del
  texto (máx. 2 líneas, siempre reserva 2 líneas para que las filas queden alineadas),
  "Ver detalle" + chevron hacia abajo. No muestra el texto completo.
- **Card abierta**: se expande en el mismo lugar (`AnimatedSize` 180 ms, chevron que rota
  180 ms) y muestra **todo** el texto legal existente, sin resumir ni modificar; en
  "Con quién los compartimos" se mantiene el destacado "No publicamos tu teléfono en el
  catálogo." "Ocultar detalle" + chevron hacia arriba.
- **Una sola card abierta a la vez.** Sin carrusel, modal, nueva ruta, tabs ni índice.
- Accesibilidad: cada card es un botón con estado `expanded`; título como encabezado.

### "En pocas palabras"
- Mismos 3 puntos. Padding 18; ancho completo; en desktop los puntos van **en tres
  columnas** (≈ 90 px de alto medidos en navegador a 1024 px); en móvil, apilados.

### Contacto
- Mismo encabezado, cierre legal y footer. Los canales configurados (`CONTACT_WHATSAPP`,
  `CONTACT_EMAIL`, `CONTACT_INSTAGRAM`) se muestran como **tarjetas compactas** (ícono,
  nombre, valor). Sin canales, se mantiene el aviso "Canal de contacto pendiente…".
  No se inventan datos.

### Footer
- Con las cards cerradas, la página de Privacidad a 1440×900 tiene un desplazamiento
  máximo < 500 px (test) y el footer queda a < 48 px del cierre legal. El footer no se
  estira (mismo componente).

## Responsive
- Tests: Términos y Privacidad en **390, 768, 1024, 1440 y 1600**, cerradas y con una
  card abierta; Contacto en los mismos anchos. Sin overflow.
- **Revisión real en navegador** (build release servido localmente):
  - Privacidad 1440×900: resumen en 3 columnas, grid 2×2 + card 05 ancha, cierre visible
    sin bajar. Se detectó desalineación entre columnas (cards con resumen de 1 línea más
    bajas) y se corrigió reservando 2 líneas.
  - Privacidad 1024×700: filas alineadas; la card 03 abierta muestra texto completo y
    destacado sin estirar la 04.
  - Términos 390×844: una columna de cards compactas.
  - No revisados en navegador: Contacto y Términos en desktop (cubiertos por tests).
  - La ventana de la app estaba oculta: algunas capturas fallaron o mostraron el fundido
    de arranque congelado; no afecta el layout.

## Tests
- Nuevo `test/phase_3_24_1_legal_cards_test.dart` (36): cards presentes y cerradas en
  Privacidad y Términos; al abrir cada card aparece el **texto fuente completo e
  idéntico**; una sola abierta a la vez y cierre al volver a tocar; sin overflow en 5
  anchos (cerradas y abiertas); destacado dentro de la card 03; altura de card cerrada
  100–150 px; puntos del resumen lado a lado en desktop; página corta y footer inmediato;
  historial push/pop tras abrir una card; Contacto sin regresiones en 5 anchos.
- Reemplazados por obsoletos (el índice/chips ya no existen): en
  `phase_3_23_prebeta_final_test.dart` (encabezado/índice, índice sticky, chips) →
  "contenido sobre el pliegue sin índice" y "una columna de cards en móvil"; en
  `phase_3_24_provider_legal_test.dart` (índice angosto, chips) → "dos columnas con la
  card impar a ancho completo". Ajustes de conteo de frases en
  `phase_3_20_premium_ux_test.dart` y `phase_3_24_provider_legal_test.dart`.
- Nota: la altura exacta del resumen (~110 px) no se puede afirmar en tests porque la
  fuente de pruebas tiene ancho fijo (≈ el doble que Roboto); se verificó en navegador.

## Validación final
`dart format` (0 cambios) · `flutter analyze --no-pub` sin issues · `flutter test`
**580/580** · `check_text_encoding.ps1` OK · `git diff --check` código 0 ·
`flutter build web --release` OK (tras el último cambio).

## Pendientes de QA manual
- Contacto con canales configurados (`--dart-define`) para ver las tarjetas reales.
- Teclado: Tab/Enter sobre las cards y foco visible.
- Términos y Contacto en desktop con la ventana activa.
