# Fase 3.17.3 — Auditoría end-to-end de solicitudes del visitante

## Causa raíz y datos existentes

`/requests` observaba `myRequestsProvider`, cuyo repositorio consultaba **solo** `public.service_requests` con `customer_id = UID actual`. Las reservas de alojamiento se crean en `public.lodging_bookings`; las de mesa en `public.gastronomy_table_reservations`. No existía agregación entre verticales. Además, `myRequestsProvider` no dependía del estado de Auth: tras cambiar de sesión podía conservar una lista de otro UID hasta una invalidación.

Un dump de datos **solo de lectura** del proyecto Supabase enlazado, consultado localmente por conteos y eliminado después, encontró al momento de la auditoría:

| Tabla | Total | Estado | UID solicitantes distintos |
| --- | ---: | --- | ---: |
| `service_requests` | 0 | — | 0 |
| `lodging_bookings` | 7 | 7 `pending` | 4 |
| `gastronomy_table_reservations` | 0 | — | 0 |

La distribución de las siete reservas es 2, 2, 2 y 1 por UID. No se mostraron UUID, nombres, teléfonos ni correos. Esto demuestra que la lista anterior era vacía aunque había siete reservas de alojamiento en el proyecto remoto. No permite identificar cuál de los cuatro UID corresponde a la sesión actual del usuario ni si alguno era Auth anónimo: eso requeriría comparar la sesión concreta y `auth.users.is_anonymous` mediante una consulta administrativa autorizada. Si el UID actual no coincide con uno de los cuatro, RLS seguirá devolviendo vacío correctamente. No se halló una tabla de reservas turísticas: el flujo de turismo usa solicitudes de servicio cuando ofrece actividades.

## Creación, identidad y contacto

| Vertical | Creación | Propietario guardado | Lectura del visitante |
| --- | --- | --- | --- |
| Servicio/turismo | `create_direct_service_request` | `service_requests.customer_id = auth.uid()` | mismo `customer_id` |
| Alojamiento | `create_lodging_booking` | `lodging_bookings.guest_user_id = auth.uid()` | mismo `guest_user_id` |
| Gastronomía | `create_gastronomy_table_reservation` | `gastronomy_table_reservations.user_id = auth.uid()` | mismo `user_id` |

Los tres RPC obtienen el UID del contexto Auth; el cliente no les entrega un UID solicitante arbitrario. `ensureVisitorContactAndConsent` crea una sesión anónima si falta, guarda nombre/teléfono en `profiles` bajo ese mismo UID, guarda correo opcional en metadata de Auth y registra consentimientos antes de llamar al RPC. El repositorio de servicio exige sesión; alojamiento y gastronomía también la comprueban en sus RPC. La relación de las tres solicitudes queda en el UID de la sesión que ejecutó el RPC.

No existe un flujo de vinculación entre UID anónimo y una cuenta distinta. `signInWithPassword` cambia a la cuenta existente, cuyo UID es otro; una solicitud creada con el UID anónimo permanece bajo ese UID y no aparece automáticamente en `/requests` de la cuenta posterior. No se cambió ownership ni se infirió identidad por correo o teléfono. El RPC de alojamiento copia el nombre desde metadata/correo de Auth, mientras el formulario visitante guarda el nombre en `profiles`; por ello `guest_name` de la reserva puede quedar con el valor genérico aunque el vínculo por UID y el contacto del perfil se conservan. Queda como ajuste separado si se requiere mostrar ese nombre en el panel prestador.

## RLS y prestadores

El dump remoto confirmó RLS habilitada y políticas SELECT para propietario: `customer_id = auth.uid()` en solicitudes de servicio, `guest_user_id = auth.uid()` en alojamiento y `user_id = auth.uid()` en mesa. Las políticas adicionales permiten al prestador consultar reservas de negocios que gestiona mediante `user_can_manage_business`; la solicitud de servicio dirigida al negocio es visible para su prestador. La política de solicitudes compatibles también contempla **solicitudes abiertas sin `business_id`** para prestadores compatibles, conducta existente que no se amplió en esta fase. El remoto conserva algunas políticas heredadas de propietario de negocio, además de las de gestor; la migración administrativa pendiente no se aplicó.

En INSERT, `service_requests` tiene `WITH CHECK (customer_id = auth.uid())`; el SQL local comprobó que un cliente no puede insertar con el UID de otro. Las reservas de alojamiento y mesa se insertan mediante RPC `SECURITY DEFINER` que fija el propietario desde `auth.uid()`; no hay política INSERT abierta para esas tablas. `anon` sin sesión no obtiene solicitudes por RLS; una sesión Auth anónima usa el rol `authenticated` y puede leer sus propias filas mientras conserve su UID.

## Fuente unificada, navegación y actualización

Se agregó `CustomerActivityItem` y `CustomerActivityRepository`. La fuente consulta por UID actual las tres tablas con una selección mínima de columnas, fusiona los resultados y los ordena por fecha. Una solicitud de servicio dirigida a un negocio con `business_type = tourism` se tipifica como TURISMO en el modelo agregado. `myCustomerActivityProvider` observa `authStateProvider`, por lo que un cambio de cuenta vuelve a consultar con el nuevo UID. `/requests` usa esa fuente y conserva las tarjetas y filtros diseñados. Los estados se normalizan solo en Flutter: `pending` → Pendiente; alojamiento `accepted` y mesa `confirmed` → Aceptada; `rejected` → Rechazada; `cancelled` → Cancelada; estados finales de servicio → Finalizada. No se modificaron enums de base de datos.

La solicitud de servicio conserva su detalle `/requests/:id`. No existen pantallas de detalle de reserva para huésped o comensal; sus tarjetas conducen a `/business/:id` como ruta existente relacionada con el negocio, sin simular un detalle de reserva. La UI no fue rediseñada. Al entrar con solo solicitudes aceptadas/finalizadas, el filtro inicial elige el primer segmento con registros para evitar una lista visualmente vacía.

Después de crear un servicio se invalidan la lista del visitante y la cola del prestador **en el ProviderContainer de ese dispositivo**. Cada segmento de reserva de alojamiento creado invalida la actividad del visitante y la lista del prestador local, incluso si un segmento posterior falla. La reserva de mesa invalida la actividad del visitante y el provider local de reservas del restaurante. El provider agregado también se invalida al cambiar Auth y permite reintentar tras error. El visitante no necesita reiniciar la aplicación para ver lo recién creado. Un prestador en otra sesión o dispositivo no recibe esa invalidación Riverpod; su pantalla requiere una recarga propia y todavía no tiene una suscripción Realtime. Ese comportamiento queda pendiente si se exige actualización inmediata entre dispositivos.

## Pruebas y límites

`supabase/tests/phase_3_17_3_requests.sql` pasó en Supabase local con `ON_ERROR_STOP=1` y **ROLLBACK**. Usa identidades sintéticas A/B, prestadores A/B y un UID Auth anónimo. Comprueba: A ve su servicio, alojamiento y mesa; B ve solo su servicio; prestador A ve las solicitudes de sus negocios; prestador B no ve las de A; la sesión anónima ve su solicitud; el rol `anon` sin sesión no; y el cliente no puede falsificar `customer_id` en INSERT. No se crearon cuentas ni solicitudes persistentes.

Las pruebas Flutter cubren los tres tipos en `/requests`, navegación existente, mapeo de estados, cambio de UID y recarga tras invalidación. La prueba previa de solicitudes de visitante se adaptó al nuevo provider sin eliminarla. Resultado: **368 tests aprobados**; `flutter analyze --no-pub`, UTF-8, `git diff --check` y `flutter build web --release` correctos.

No se creó migración porque no fue necesario cambiar esquema, RPC o RLS. Las migraciones `20260923185000`, `20261003000000` y `20261003181310` siguen pendientes en remoto según la fase 3.17.2. Esta corrección frontend tampoco está desplegada: el remoto conserva los siete registros y la aplicación publicada todavía puede mostrar el comportamiento anterior. Antes de atribuir las siete reservas a una cuenta concreta, hay que comparar su UID de sesión con los UID propietarios mediante un canal administrativo seguro. **No hubo db push, deploy, reset, borrado ni reasignación de ownership.**
