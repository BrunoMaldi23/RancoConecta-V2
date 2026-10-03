# Fase 3.10: experiencia de visitante y preparación de producción

## Flujo visitante

- La exploración, el detalle y los formularios de solicitud se abren sin sesión. Nombre y WhatsApp se piden al enviar, junto con correo y localidad opcionales.
- El formulario integrado crea una sesión anónima cuando hace falta, guarda el perfil y registra los tres consentimientos con versión, usuario, acción y fecha en la estructura creada durante la fase 3.9. Si falla cualquier paso, la solicitud permanece sin enviar.
- Las reservas de alojamiento pueden usar rango o noches específicas. `selectedDates` y el primer/último día se mantienen en el estado de presentación. Como el contrato existente acepta solo entrada y salida, cada tramo consecutivo de noches manuales se envía como una reserva independiente. El resumen y la confirmación informan cuántas solicitudes se enviarán. Si hay un fallo parcial, se retiran de la selección las noches ya enviadas para evitar duplicados al reintentar.
- En rango, la salida sigue siendo la fecha de checkout y las noches se calculan como `salida - entrada`; por ejemplo, del 1 al 5 son cuatro noches. El ejemplo de cinco noches en la solicitud requiere una decisión de producto antes de cambiar este contrato.

## Canales y dominio

- `PUBLIC_SITE_URL` se valida como `https://www.rancoconecta.cl` en el despliegue. La app no usa URLs locales para confirmación o recuperación en producción.
- `/contacto` valida nombre, correo y mensaje y abre el cliente de correo con el mensaje preparado cuando existe `CONTACT_EMAIL`. También muestra enlaces para `CONTACT_WHATSAPP` y `CONTACT_INSTAGRAM` cuando se configuran. Estos canales siguen pendientes de definición interna; el botón de envío queda deshabilitado hasta tener un destinatario real.
- El archivo `supabase/config.toml` incluye valores de desarrollo local. No se modificó por la restricción de esta fase; los valores alojados de Site URL y Redirect URLs deben comprobarse en el panel de Supabase.
- La confirmación de correo y recuperación de contraseña todavía requieren pruebas con un buzón real. La notificación interna al administrador se implementó mediante la migración aditiva `20261001190000_notify_admins_on_business_review.sql`, aplicada al proyecto alojado en la fase 3.11. Su activación en una transición real sigue pendiente de prueba con cuentas proveedor y administradora.

## Verificación

- `flutter analyze`, `flutter test` y `flutter build web --release`.
- Antes de publicar: probar contacto real, consentimiento con migración aplicada, reservas manuales con mínimo de noches, recuperación de contraseña, registro proveedor y aviso al administrador en el proyecto alojado.
