# Fase 3.9: activación de producción

## Cambios que requieren configuración

1. Las migraciones `20261001000000_user_consents.sql` y `20261001001000_provider_review_notification_dedup.sql` se aplicaron al proyecto alojado el 1 de octubre de 2026. El formulario visitante bloquea el envío si no puede registrar el consentimiento.
2. En **Supabase Authentication → URL Configuration**, configurar Site URL `https://www.rancoconecta.cl` y Redirect URLs `https://www.rancoconecta.cl/**`. El archivo `supabase/config.toml` configura el entorno local de Supabase; no demuestra ni cambia por sí solo los valores del proyecto alojado.
3. La migración `20261001190000_notify_admins_on_business_review.sql` se aplicó al proyecto alojado. Su trigger crea una notificación interna para cada administrador activo cuando un negocio cambia a `pending_review`; el índice único anterior evita duplicados. La Edge Function `notify-provider-review` y el webhook descritos originalmente no están desplegados ni son necesarios para este aviso interno. Falta probar el trigger con una transición real y una cuenta administradora.
4. Definir el responsable legal y el correo de contacto. Configurar `CONTACT_EMAIL` para activar el enlace de correo en `/contacto` y revisar los textos de `/terminos` y `/politica-privacidad` antes de la beta pública. El responsable y su correo siguen pendientes por decisión del equipo.
5. Configurar opcionalmente `SENTRY_DSN`, `POSTHOG_PROJECT_TOKEN` (o `POSTHOG_KEY`) y `POSTHOG_HOST` en `.env.production.local`. Sin esos valores, la app funciona y la telemetría correspondiente queda desactivada. Los eventos PostHog solo contienen nombre del evento e ID aleatorio de sesión; no incluyen datos de contacto ni términos de búsqueda.

## Verificación antes de publicar

- Probar confirmación de correo, recuperación de contraseña y configuración de contraseña desde un correo real. Todos los enlaces deben regresar a `https://www.rancoconecta.cl`.
- Probar un visitante nuevo y uno con perfil previo: entrada pública, exploración, reserva de alojamiento, reserva gastronómica y solicitud de servicio. Cada envío debe requerir consentimiento y conservar el borrador al volver.
- Probar creación de acceso proveedor, confirmación de correo, envío a revisión, notificación interna al administrador, publicación y rechazo.
- Confirmar que `/terminos`, `/politica-privacidad` y `/contacto` se abren desde la bienvenida y el pie del catálogo.
- Ejecutar `flutter analyze`, `flutter test` y `git diff --check`. Revisar manualmente los anchos 390, 768, 1024 y 1366 px en un navegador real.

La entrega de notificaciones por correo a un proveedor externo requiere una decisión separada sobre el servicio y los datos compartidos. El intento de añadir Resend fue rechazado por la revisión automática y no forma parte de esta implementación.
