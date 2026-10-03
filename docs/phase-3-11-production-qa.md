# Fase 3.11: estado de producción y QA beta

Fecha: 1 de octubre de 2026.

## Producción comprobada

- `https://www.rancoconecta.cl` quedó asociado a un despliegue Vercel listo (`dpl_CHCB93KeCCoBefU3bc6c3VN6Qsfd`). El dominio, rutas SPA y assets principales respondieron HTTP 200.
- Una sesión nueva de Edge cargó bienvenida, Home, Explore, ficha pública, reserva de alojamiento, Términos, Privacidad, Contacto y acceso proveedor sin errores de consola. Explore mostró seis prestadores reales. La ruta `/admin` redirigió a login para un visitante sin sesión.
- La navegación atrás del navegador devolvió Contacto → Privacidad → Términos. La bienvenida se comprobó también a 390 px.
- Supabase Auth `/auth/v1/health` respondió HTTP 200 con la clave pública de producción.
- En el dominio publicado, el formulario de registro mostró las tres aceptaciones separadas y la pantalla de recuperación de contraseña cargó sin errores de consola. No se creó una cuenta ni se solicitó un correo de recuperación sin buzón de prueba.
- Consultas anónimas de solo lectura a `notifications` y `user_consents` devolvieron cero filas visibles (HTTP 200); esto comprueba aislamiento para ese caso, no todos los permisos de proveedor o admin.
- `CONTACT_EMAIL` no está definido por decisión del equipo: el formulario muestra que el canal está pendiente y mantiene el envío deshabilitado. No se envió información a un servicio externo.

## Migraciones

Antes de esta fase había 21 versiones sincronizadas y cuatro pendientes: `20260930120000`, `20260930121000`, `20261001000000`, `20261001001000`. Se aplicaron esas cuatro y la nueva migración aditiva `20261001190000`. La lista final muestra 26 versiones locales y 26 remotas idénticas. No se modificó el historial previo.

La migración nueva crea un trigger para notificar internamente a administradores activos en la transición de un negocio a `pending_review`. La configuración de WhatsApp permanece en el backend y el panel admin ofrece un enlace `wa.me`; no existe envío automático a WhatsApp. La Edge Function antigua no está desplegada. Aún no se comprobó el trigger ni la configuración de número con un negocio real y una cuenta administradora.

## QA de visitante

- La entrada a Home y Explore no pidió login. Se abrió una ficha de alojamiento pública y su formulario de reserva.
- El calendario en rango mostró del 5 al 9 de octubre como cuatro noches y calculó $260.000 a $65.000 por noche. El modo manual seleccionó solo el 5, 7 y 9, sin marcar los días intermedios. Ese conjunto quedó bloqueado por la estancia mínima de dos noches consecutivas del alojamiento probado.
- Tras confirmar un rango válido, el flujo mostró un diálogo de confirmación y luego solicitó nombre y WhatsApp, correo y localidad opcionales, además de aceptaciones separadas de Términos, Privacidad y tratamiento de datos.
- Se detuvo antes de registrar consentimiento o enviar una reserva: no había datos de contacto de prueba autorizados. Por ello no se verificaron persistencia, historial ni recepción por proveedor.
- El filtro Gastronomía mostró cero negocios publicados en el catálogo de producción; no hay un negocio real disponible para probar la reserva de mesa. Se abrió la ficha pública de Servicios del Ranco y su formulario de solicitud de servicio sin login. La prueba se detuvo antes de enviar datos.

## Verificación de código y build

- `scripts/check_text_encoding.ps1`, `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze --no-pub`, `flutter test` (184 pruebas) y `git diff --check` pasaron.
- El script oficial `scripts/deploy-production.ps1 -SkipGit -SkipVercel` pasó y produjo `flutter build web --release` con defines públicos saneados. Después se publicó el contenido generado mediante `vercel --prod --yes`.
- La app usa `PUBLIC_SITE_URL=https://www.rancoconecta.cl` para los redirects de registro y recuperación. No se encontró un redirect productivo a localhost en el código. Los valores locales de `supabase/config.toml` se mantienen para desarrollo.
- Sentry y PostHog están integrados de forma opcional y no tenían DSN ni clave configurados en el archivo de producción; por eso no se comprobó recepción real de eventos. Sentry desactiva PII por defecto. Los eventos PostHog no incluyen datos de contacto ni mensajes privados.

## Pendientes para cerrar la beta

1. Confirmar en el proyecto alojado de Supabase Auth la Site URL `https://www.rancoconecta.cl` y el redirect permitido `https://www.rancoconecta.cl/**`. La configuración local no prueba estos valores remotos.
2. Probar con un buzón y cuenta proveedor de prueba: registro, aceptación real, correo de confirmación, contraseña, reenvío, recuperación y retorno al dominio; perfil y negocio propios; envío a revisión.
3. Probar con una cuenta administradora real: acceso y RLS, recepción del aviso interno, detalle, aprobación/rechazo, publicación pública y enlace WhatsApp con el número configurado. No se presume que el trigger o `wa.me` hayan entregado un aviso real.
4. Completar con contactos autorizados los envíos reales de alojamiento y servicio, y comprobar historial, datos visibles al proveedor y continuidad del borrador. Para gastronomía hace falta además un negocio publicado con reserva de mesa habilitada.
5. Definir internamente responsable legal y `CONTACT_EMAIL`, revisar textos legales y habilitar/probar contacto. Configurar y validar Sentry/PostHog si se decide activarlos.
6. Revisar el árbol Git completo y crear checkpoint/push solo cuando estén validados los flujos anteriores. Esta fase heredó cambios sin commit de fases anteriores; no se hizo commit parcial.

No se declara la fase completa mientras queden estas pruebas de producción pendientes.

Tras la revisión adicional solicitada, no se hizo otro despliegue Vercel: se espera a que las pruebas pendientes pasen antes de publicar una nueva versión.
