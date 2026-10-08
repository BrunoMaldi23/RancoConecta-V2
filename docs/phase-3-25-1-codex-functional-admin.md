# Fase 3.25.1 — navegación legal y funciones administrativas

Fecha: 2026-10-04/05. Trabajo local, sin deploy, commit, push ni DB push.

## Estado inicial y baseline

Se leyeron `phase-3-24-1-codex-legal-cards.md` y el reporte de Claude de 3.25 cuando apareció durante esta fase. Se inspeccionaron rutas, legales, Contacto, notificaciones, Auth, roles, RLS, migraciones, administración y configuración. El árbol ya contenía numerosos cambios de fases anteriores, incluso archivos de producción, Auth, router, `vercel_output` y migraciones sin seguimiento; se conservaron.

Baseline antes de editar: `flutter test` **580/580**. Claude trabajó en paralelo en la presentación 3.25; su reporte registró **618 aprobadas y 6 fallidas** por expectativas antiguas de navegación. Las pruebas antiguas se actualizaron únicamente para el comportamiento nuevo de Volver y del formulario/CRUD conectado.

## Arquitectura encontrada

- Roles reales: `customer`, `provider`, `admin`, `super_admin`; estado `active`, `pending`, `suspended`, `blocked`, `deleted`. El visitante es un usuario anónimo, no otro rol de base.
- Existían `admin_search_users`, `admin_change_user_role`, `admin_set_account_suspension`, auditoría en `audit_logs` y protección de rol/estado del lado del servidor. WhatsApp ya se guarda en `system_settings` por RPC validado y auditado; se mantuvo el envío manual.
- Las notificaciones ya tenían `read_at`, RPC de listado, lectura individual, lectura total y contador. La UI de Claude tenía filtros y categorías. No existía `contact_messages`, ni operación segura para invitar administradores o retirar acceso a usuarios.
- Docker Desktop no tenía motor activo. No se aplicaron migraciones ni se hizo una prueba SQL contra una base local o remota.

## Cambios de Codex en esta fase

### Navegación legal

`legal_navigation.dart` conserva `returnTo` en una lista de rutas internas válidas, rechaza URL externas y valores `next` externos, hace `push` al entrar desde otra área y `replace` entre legales. Volver usa el origen inicial; el deep link sin origen vuelve a `/` como fallback. Se conectaron enlaces del footer, acceso, consentimiento y páginas legales. No se rediseñaron las cards ni se cambió el contenido legal.

### Contacto

El formulario invoca `submit-contact` y gestiona validación, carga, doble envío, éxito con limpieza y error recuperable. La Edge Function pública limita el tamaño del body, normaliza y valida los cuatro campos del lado servidor y usa la clave privilegiada solo en el servidor. Asocia `user_id` cuando el token corresponde a un usuario con perfil; anónimo queda `null`. La tabla `contact_messages` tiene RLS, lectura administrativa y cambio de estado auditado; un trigger genera aviso administrativo `contact_message` si está habilitado. Los canales públicos se leen desde configuración; si no hay canales aparece el aviso de canal adicional pendiente. No se agregaron direcciones o teléfonos fijos en Flutter.

### Notificaciones

Se conservó el repositorio y sus RPC existentes. Se muestran los grupos locales Hoy, Ayer y Anteriores. Se comprueba el resultado al marcar una o todas como leídas y se muestra un error cuando falla. `contact_message` se clasifica en Sistema. El aviso de contacto no tiene deep link porque aún no existe una ruta administrativa para su detalle; las rutas reales existentes mantienen su destino.

### Usuarios administrativos

Se conectaron las acciones existentes de listar, buscar, filtrar, cambiar rol, suspender y reactivar. La invitación y la eliminación de acceso pasan por `admin-user`, una Edge Function que verifica token y perfil administrativo activo. Invitar usa Supabase Auth Admin API del servidor, crea/actualiza perfil `admin`, audita y revierte el usuario Auth creado si falla la preparación. No hay contraseña fija ni clave de servicio en Flutter. Eliminar requiere confirmación, bloquea autoeliminación y super admin, protege el último administrador activo mediante RPC, inspecciona FKs públicas, conserva referencias y auditoría, marca el perfil como eliminado/anónimo y usa borrado suave de Auth. Si falla el paso Auth, la cuenta queda bloqueada y la operación puede reintentarse.

### Configuración

Se conservaron los datos fijos reales de nombre/zona y los campos operativos sin backend como solo lectura. Se agregaron `support_email`, `support_whatsapp` y tres preferencias para eventos con emisor real: negocio nuevo, cambios de negocio y mensaje de contacto. RPC de servidor validan permisos y datos, guardan y auditan. Los demás interruptores de la UI siguen inactivos porque hoy no hay emisores de esos eventos. Integraciones mantiene el estado vacío. WhatsApp administrativo mantiene su RPC y flujo manual existentes.

## Migraciones y funciones nuevas

- `20261005000000_contact_messages.sql`: tabla, RLS, estado auditado y aviso administrativo.
- `20261005001000_admin_user_deletion.sql`: borrado lógico, guardas y auditoría.
- `20261005002000_contact_and_notification_settings.sql`: canales, preferencias y triggers condicionados.
- Edge Functions: `submit-contact` y `admin-user`; configuración en `supabase/config.toml`. Ambas validan solicitudes en servidor. `verify_jwt=false` permite que Contacto reciba anónimos y que `admin-user` devuelva un 401 controlado; esta última comprueba token y rol activo antes de operar.

## Pruebas y validación

- Nuevas pruebas Flutter de navegación legal (incluido origen malicioso), formulario de Contacto, guardas y diálogos CRUD, y persistencia UI de canales/preferencias. Se ajustaron pruebas antiguas que esperaban stack legal creciente o acciones todavía no conectadas.
- `dart format .`: correcto.
- `flutter analyze`: sin issues.
- `flutter test`: **630/630**.
- `scripts/check_text_encoding.ps1`: UTF-8 estructural OK.
- `git diff --check`: OK.
- `flutter build web --release`: OK, `build/web` generado localmente.
- Deno: 2/2 pruebas de validación de Contacto; `deno check --node-modules-dir=none` para ambas Edge Functions correcto.

## Revisión de diff y pendientes reales

Los archivos principales propios son `legal_navigation.dart`, `contact_repository.dart`, `admin_settings_repository.dart`, las dos pantallas conectadas, `notifications_screen.dart`, tres migraciones, dos Edge Functions, pruebas 3.25.1 y este reporte. `legal_screen.dart` y `admin_settings_screens.dart` también contienen el trabajo visual de Claude; no se atribuye a Codex. El árbol contiene cambios preexistentes en Auth, router, infraestructura, producción y artefactos web; no se revirtieron ni se incluyeron deliberadamente en esta fase.

Pendiente de verificación operativa: aplicar las migraciones y publicar las Edge Functions en un entorno autorizado, luego probar RLS, invitación/correo, estados y flujos completos contra Supabase. No se hizo porque el motor Docker local estaba inactivo y el usuario prohibió DB push/deploy. No se inventó configuración SMTP. Los avisos de contacto son visibles en Notificaciones, pero no enlazan a detalle hasta que exista una pantalla administrativa de mensajes.
