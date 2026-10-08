# Fase 3.24.1 — Cards legales expandibles (Codex)

Fecha: 2026-10-04. Sin deploy, commit, push ni DB push.

## 1. Estado inicial encontrado

Se leyó `docs/phase-3-24-claude-provider-legal-polish.md` y se inspeccionaron Privacidad, Términos, Contacto, el footer compartido y los tests legales. El árbol de trabajo ya tenía numerosos cambios sin commit de fases anteriores, incluidas una implementación de cards legales y `test/phase_3_24_1_legal_cards_test.dart`. Se preservaron. También había cambios ajenos en Auth, router, Supabase, configuración de producción y otras áreas; ninguno fue editado para esta fase.

## 2. Baseline de tests

Antes de modificar archivos se ejecutaron los tests legales relevantes: `legal_navigation_test.dart`, `phase_3_24_provider_legal_test.dart`, `phase_3_24_1_legal_cards_test.dart` y `phase_3_23_prebeta_final_test.dart`: **78/78** aprobados. El reporte de 3.24 consignaba **555/555** para su estado anterior.

## 3. Archivos modificados en esta intervención

- `lib/features/legal/presentation/legal_screen.dart`: footer natural en Privacidad, Términos y Contacto.
- `test/phase_3_24_1_legal_cards_test.dart`: comprobación explícita de una o dos columnas y ausencia de relleno bajo una página corta.
- Este reporte.

La implementación de cards y los ajustes a otros tests legales ya estaban presentes al comenzar esta intervención; forman parte del estado de trabajo auditado, no de los cambios nuevos descritos arriba.

## 4. Privacidad

Cinco cards, inicialmente cerradas. El grid desktop usa dos columnas y la quinta card ocupa el ancho completo. Una card abierta muestra el texto completo en el mismo lugar y cierra la abierta anterior. Se conserva el resumen «En pocas palabras», los metadatos, el cierre legal y los enlaces. No hay índice lateral ni chips móviles. Las cards usan `AnimatedSize` de 180 ms y el chevron gira. El footer ahora sigue el contenido normal incluso cuando sobra altura de viewport.

## 5. Términos

Cuatro cards con el mismo componente y comportamiento, en disposición 2 × 2 para desktop. El contenido expandido conserva el texto de cada sección.

## 6. Contacto

Mantiene el formulario, los canales configurados únicamente cuando existen y el aviso de canal pendiente en ausencia de configuración. No se convirtió en acordeón. El footer sigue el contenido normal y el cierre no enlaza Contacto consigo mismo.

## 7. Responsive

Los tests verifican **390, 768, 1024, 1440 y 1600 px** en Privacidad y Términos, con cards cerradas y abiertas, sin errores de layout. Comprueban una columna a 390 y 768 px, y dos columnas desde 1024 px. Contacto se prueba en los mismos cinco anchos.

## 8. Tests agregados o modificados

Se ampliaron los tests existentes de esta fase para comprobar explícitamente las columnas en los cinco anchos y que el footer quede a menos de 48 px del bloque de enlaces en una ventana alta de 1400 px. Los tests existentes cubren contenido íntegro al abrir, estado inicial, apertura y cierre, una sola card abierta, navegación `push`/`pop`, cierre legal y Contacto. Suite final: **580/580**.

## 9. Revisión visual

Se sirvió `build/web` localmente y se revisó en Microsoft Edge:

- Privacidad: 1440 × 900 cerrada y abierta; 390 × 844 abierta.
- Términos: 1440 × 900 y 390 × 844 cerrada; 390 × 844 abierta.
- Contacto: 1440 × 900 y 390 × 844.

Se comprobaron grid, columna móvil, espaciado, chevrons, contenido expandido, cierre y footer. No se observó overflow ni saltos anómalos. Las capturas temporales de Playwright se retiraron del árbol de trabajo al terminar la revisión.

## 10. Validación final

- `dart format .`: 196 archivos inspeccionados; 2 formateados (los archivos Dart de esta intervención).
- `flutter analyze`: sin issues.
- `flutter test`: **580/580**, verde.
- `scripts/check_text_encoding.ps1`: UTF-8 estructural OK.
- `git diff --check`: código 0 (avisos de normalización LF/CRLF en archivos preexistentes).
- `flutter build web --release`: correcto.

## 11. Bugs encontrados

El uso de `RancoFooterSliver` podía empujar el footer al fondo del viewport en páginas cortas. En estas tres rutas se sustituyó por `SliverToBoxAdapter` con el mismo `RancoSiteFooter`, sin cambiar el componente compartido ni otras rutas. Una prueba con viewport alto verifica la separación real.

## 12. Contenido y pendientes

Se comparó el bloque fuente de las nueve secciones legales del archivo actual con `HEAD`: coincide tras normalizar espacios (**1953 caracteres en ambos**). No se cambió texto, fecha, versión ni orden. No hay pendientes bloqueantes. Queda como QA opcional revisar Contacto con canales reales configurados y navegación por teclado en navegador.
