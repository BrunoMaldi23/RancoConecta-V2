# Fase 3.25.7 — snapshot remoto y ensayo preproducción

**READY FOR REMOTE APPLY: NO.** La copia real fue restaurada y las 24 migraciones pendientes se aplicaron al snapshot local. Los contratos de integridad y seguridad pasaron. El apply remoto aún carece de recuperación remota restaurable verificada y de bootstrap controlado para el primer super_admin.

## Baseline y backup

- Inicio: remoto 31 migraciones; repo 53 (22 pendientes). Tras las correcciones locales: 55 migraciones y 24 pendientes. El historial remoto no cambió.
- Supabase CLI reportó walg_enabled=true, pitr_enabled=false, backups=[] y sin backup físico. Dashboard no se verificó.
- Se exportaron schema public, schema auth y datos. El dump tenía 42 tablas públicas de aplicación, 27 tablas Auth en el esquema y 68 bloques COPY con datos.
- Staging guardado fuera del repo en %LOCALAPPDATA%\RancoConecta\phase-3-25-7-private. La carpeta tiene ACL explícita para la cuenta Windows actual; además se creó un ZIP cifrado con DPAPI CurrentUser y su round-trip SHA-256 se verificó. El archivo DPAPI requiere el mismo perfil Windows. El filesystem no aceptó EFS.
- Las copias temporales en claro siguen en esa carpeta con ACL restringida. El intento de borrarlas fue rechazado por el control de política del entorno; no se copiaron al repo. El ZIP DPAPI es la copia cifrada verificada.
- Una llamada inicial `supabase db dump --linked --dry-run` imprimió una contraseña temporal de conexión CLI `cli_login_postgres`. No era una clave service_role, no se copió a archivos y una conexión enlazada posterior la renovó. Las consultas remotas restantes fueron de lectura (historial, backup y agregados); el CLI renueva ese login temporal al conectarse.

## Restauración y fidelidad

- Se usó una instancia Supabase local separada, con puertos propios y migraciones automáticas desactivadas durante la restauración. Se restauraron ambos esquemas y los datos; después se instalaron los tres triggers de auth.users que dependen de funciones public.
- Los conteos remotos de las 68 tablas coincidieron con la exportación: cero diferencias. La restauración lógica completa terminó sin errores.
- Antes de migrar: 15 profiles, 12 businesses, 12 business_members, 7 lodging_bookings, 0 service_requests, 0 gastronomy_table_reservations, 3 notifications, 11 audit_logs, 5 system_settings, 15 auth.users y 6 auth.identities.
- Checksum antes/después: business_id/owner_id, profile id/role, solicitudes y relaciones de reservas coincidieron. Los cinco settings originales conservaron su checksum; se agregaron cinco defaults.

## Secuencia y resultado de datos

El remoto tenía versiones aplicadas hasta 20261003181310. En el snapshot local se representaron esas 31 versiones reales (sin `migration repair`) y `supabase migration up` aplicó las 24 pendientes en orden, desde 20261004120000 hasta 20261005008000. Todas pasaron.

| Tabla | Antes | Después | Diferencia | Nota |
|---|---:|---:|---:|---|
| auth.users | 15 | 15 | 0 | igual |
| auth.identities | 6 | 6 | 0 | igual |
| profiles | 15 | 15 | 0 | roles/checksum iguales |
| businesses | 12 | 12 | 0 | ownership íntegro |
| business_members | 12 | 12 | 0 | igual |
| service_requests | 0 | 0 | 0 | igual |
| lodging_bookings | 7 | 7 | 0 | igual |
| gastronomy_table_reservations | 0 | 0 | 0 | igual |
| notifications | 3 | 3 | 0 | igual |
| audit_logs | 11 | 14 | +3 | trazas esperadas de roles ambiguos |
| system_settings | 5 | 10 | +5 | defaults nuevos; originales sin cambios |
| provider_role_migration_candidates | — | 3 | +3 | registros nuevos, no perfiles |
| contact_messages | — | 0 | 0 | tabla nueva; pruebas limpiadas |
| super_admin_sessions | — | 0 | 0 | tabla nueva; fixtures limpiados |

Las 68 tablas de datos originales conservaron sus conteos salvo auditoría y defaults explicados. Al final: 45 tablas públicas, 27 Auth y 55 versiones en el historial local.

## Roles, ownership y seguridad

- Roles antes/después: admin=1, provider=1, customer=13, super_admin=0. Tres perfiles quedaron `AMBIGUO` y permanecieron customer. Los checksums de profile id/role fueron iguales; ningún admin se perdió ni hubo degradaciones automáticas.
- No existe una cuenta super_admin de producción ni procedimiento de bootstrap inicial. La prueba de administración usó un usuario local temporal que se eliminó.
- businesses.owner_id cambió en el snapshot de auth.users ON DELETE CASCADE a profiles(id) ON DELETE RESTRICT. Checksum de ownership idéntico; owners huérfanos=0; negocios perdidos=0.
- SECURITY DEFINER administrativas con EXECUTE para anon: 0. TRUNCATE para anon/authenticated: 0. La suite confirmó search_path explícito, RLS de contact_messages, grants directos bloqueados y auditoría no manipulable.
- El snapshot tenía la función `protect_profile_privileged_fields()` pero no su trigger. Se añadió 20261005008000 para instalarlo idempotentemente.

## Defectos corregidos

1. La eliminación lógica guardaba account_status=deleted, pero el CHECK remoto lo rechazaba. 20261005007000 permite deleted tanto para el CHECK de texto remoto como para el enum del reset limpio, preservando valores existentes. Se añadió aserción de soft delete con Auth y negocio conservados.
2. Faltaba el trigger que aplica el guard de cambios de rol en el snapshot. 20261005008000 repara ese drift sin editar migraciones antiguas.
3. Se ajustaron fixtures SQL: lodging_bookings ahora incluye base_amount/total_amount requeridos; la prueba anon acepta el rechazo por falta de grant. La suite de seguridad comprueba presencia del trigger y soft delete auditado.

## Contacto, Edge Functions y Admin

- Home con is_featured, accepts_requests, rating_avg y review_count: HTTP 200.
- submit-contact: CORS OPTIONS 200, GET 405, payload inválido 400, anónimo válido 201; autenticado válido 201 y user_id asociado al profile correcto. Los mensajes temporales se borraron; contact_messages final=0.
- admin-user sin JWT: 401. Con super_admin local de prueba: invitación 201; cambio de rol, suspensión y reactivación 204; eliminación lógica 200. Auth siguió presente, el profile quedó deleted y la auditoría registró crear, cambiar rol, suspender, reactivar y borrar. Las cuentas/sesión de prueba se limpiaron; no salió ningún correo real.
- Los cinco settings originales conservaron valores; cinco defaults se añadieron sin sobrescribir. Home mantuvo 12 negocios.

## Suites y validación final

- `supabase db reset --local --no-seed`: OK, 55/55 migraciones desde cero.
- SQL: 6/6 suites pasaron tanto en snapshot como en reset limpio.
- Flutter: `dart format .` (203 archivos, 0 cambios), `flutter analyze` OK, `flutter test` 630/630, `flutter build web --release` OK.
- UTF-8 OK; `git diff --check` OK (avisos LF→CRLF informativos).
- Deno 2/2; type-check de submit-contact y admin-user OK.
- Home HTTP, Edge HTTP, RLS, conteos y checksums del snapshot OK.

## Rollback y decisión

- **Comprobado localmente:** restauración completa del snapshot en instancia aislada, comparación de conteos/checksums, aplicación de migraciones y suites. El archivo DPAPI pasó round-trip SHA-256.
- **No comprobado para producción:** PITR desactivado, CLI sin backups listados y sin restore remoto ni restore en un proyecto alternativo. Antes de aplicar, el operador debe confirmar backup restaurable en Dashboard o ensayar dump/restore en un proyecto alternativo con procedimiento oficial Supabase. No usar DROP como rollback. Una restauración desde este snapshot perdería/requeriría reconciliar escrituras posteriores a su hora de captura.
- El bootstrap de la primera cuenta super_admin también sigue pendiente; sin esa cuenta, las acciones globales no tendrán operador autorizado. La prueba admin fue solo con fixtures locales.

**READY FOR REMOTE APPLY: NO.** No se cambió esquema, datos ni roles de usuarios reales; no se ejecutó migración, deploy ni push remoto. El historial remoto continúa en 31 versiones.
