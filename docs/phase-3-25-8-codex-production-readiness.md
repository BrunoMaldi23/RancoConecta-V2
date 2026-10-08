# Fase 3.25.8 — preparación para producción

**READY FOR REMOTE APPLY: NO.** La preparación local y el bootstrap están probados. La copia de seguridad remota restaurable y la presencia de secretos en producción siguen sin verificarse; esta fase no consultó ni modificó Supabase remoto.

## 1. Recuperación de la sesión interrumpida

Antes de editar se ejecutaron `git status` y `git diff --stat`. El repositorio estaba en `main`, actualizado respecto de `origin/main`, con numerosas modificaciones y archivos nuevos de fases anteriores. No se descartó ni revirtió ninguno. El reporte 3.25.8 no existía.

Ya estaban creados al retomar:

- `scripts/backup-supabase-logical.ps1`, `scripts/restore-supabase-logical.ps1`.
- `scripts/bootstrap-first-super-admin.sql`, `scripts/bootstrap-first-super-admin-core.sql`.
- `scripts/supabase-production-preflight.sql`, `scripts/supabase-production-postflight.sql`.
- `supabase/tests/phase_3_25_8_bootstrap.sql`.
- No había migración posterior a `20261005008000_install_profile_privilege_guard.sql`.

El test de bootstrap existía, pero no había evidencia de ejecución. La fase 3.25.7 documentaba el snapshot real restaurado localmente, 68 tablas comparadas, las 24 migraciones pendientes aplicadas al snapshot, seis suites SQL, 630 tests Flutter y PITR desactivado sin backups listados por CLI. Esa documentación confirma `super_admin=0` en producción y que los tres candidatos ambiguos permanecieron como customer.

Trabajo completado al retomar: ejecución de validaciones y suites; casos de auto-promoción provider/customer añadidos a la prueba de bootstrap; script de backup endurecido para borrar los dumps en claro después de verificar el round-trip cifrado; este reporte. No se añadió ninguna migración.

## 2. Backup, restauración y validación

El estado de recuperación conocido sigue siendo: PITR desactivado; CLI no listó backups automáticos; Dashboard no verificado. El snapshot lógico de 3.25.7 se restauró localmente y pasó la comparación de conteos/checksums. El ZIP protegido con DPAPI tuvo round-trip SHA-256 correcto. Esto prueba el snapshot anterior, pero no acredita una copia remota restaurable hoy ni una ejecución extremo a extremo de los nuevos scripts.

El script `scripts/backup-supabase-logical.ps1` formaliza seis dumps (schema y datos de `public`, `auth` y `storage`), manifiesto con tamaños/SHA-256, ZIP cifrado con DPAPI `CurrentUser` y comprobación de descifrado/hash. Ahora elimina los archivos en claro solo después de comprobar el round-trip. El archivo requiere el mismo perfil Windows para descifrarlo. El dump no se almacena en el repositorio.

Procedimiento operativo previsto:

1. Confirmar en Supabase Dashboard un backup recuperable y su retención. Si no existe, desde una estación operacional aprobada ejecutar el script de backup con el project ref; custodiar el DPAPI bajo el mismo usuario/perfil y guardar una copia cifrada fuera del equipo según la política de recuperación.
2. Restaurar/desencriptar con `scripts/restore-supabase-logical.ps1` a una carpeta privada fuera del repo. El script verifica contenido permitido, integridad de los seis archivos y presencia de exactamente tres triggers Auth que dependen de `public`; prepara esos triggers para instalarlos después del esquema public.
3. Restaurar el staging en un proyecto QA aislado (nunca producción), en orden schema public/auth/storage, datos y triggers diferidos. Comparar los conteos del preflight y checksums/relaciones antes de migrar.
4. Aplicar ahí las migraciones exactas de la sección 5; ejecutar postflight, suites SQL, API/Edge y smoke tests; comparar conteos/checksums. Conservar salida agregada sin datos personales.

**Limitación de esta fase:** los scripts de backup/restore no se ejecutaron contra el proyecto remoto porque estaba prohibido tocarlo. El script de restore prepara y valida los dumps; el replay en un proyecto QA requiere conexión operacional aprobada y sigue pendiente. No declarar listo el apply remoto hasta completar esa prueba y confirmar backup/PITR restaurable.

## 3. Modelo `super_admin` y bootstrap

Producción no tenía `super_admin`; no se seleccionó ni promovió ninguna cuenta real. El modelo de 3.25.6/3.25.7 distingue el SuperAdmin global de los permisos tenant y requiere una sesión global explícita, temporal y auditada. La sesión se inicia mediante `start_super_admin_session`, con propósito y vencimiento; los helpers tenant se basan en ownership/membership.

El bootstrap inicial es una operación única de operador DB privilegiado, fuera de una RPC pública. `scripts/bootstrap-first-super-admin.sql` toma advisory lock, exige propietario DB, rechaza actor=destino, requiere cero SuperAdmin, y acepta únicamente un perfil Auth no anónimo, activo y con rol `admin`. Escribe auditoría `first_super_admin_bootstrapped` y comprueba postcondiciones. Segunda ejecución queda bloqueada por `BOOTSTRAP_ALREADY_COMPLETED`. Elegir el UUID requiere aprobación humana y verificación fuera de banda del titular; no se elige automáticamente.

`supabase/tests/phase_3_25_8_bootstrap.sql` pasó sobre reset local limpio y revierte fixtures al terminar. Cubrió cero SuperAdmin → exactamente uno, auditoría, bloqueo de repetición/idempotencia, admin tenant sin auto-promoción, provider y customer sin auto-promoción vía API, sesión global explícita y rechazo de degradación/eliminación del último SuperAdmin. La promoción inicial usa un fixture admin, nunca una cuenta real.

## 4. Runbook de aplicación y rollback

Antes de cualquier ventana futura:

1. Restaurar/ensayar el backup en QA y aprobar baseline agregado; confirmar rollback recuperable.
2. Congelar cambios de esquema y tráfico administrativo según el plan de 3.25.5. Aplicar migraciones por timestamp, sin saltos; detenerse ante divergencia de conteos, roles, grants o ownership.
3. Tras la última migración y verificaciones, ejecutar el bootstrap manual solo con el UUID aprobado y verificado. Ejecutar `scripts/supabase-production-postflight.sql` y registrar salida agregada.
4. Desplegar Edge Functions y frontend en un cambio separado, después de verificar secretos/ACL y smoke tests. No mezclar con esta secuencia SQL.

El rollback primario es restaurar el backup probado en el destino aprobado y reconciliar escrituras ocurridas desde su captura. No usar `DROP` ni hacer UPDATE inversos globales de roles: pueden destruir cambios legítimos. Ante una falla de una función, volver a la versión anterior o deshabilitar esa función sin borrar mensajes/datos. El postflight detecta FK `owner_id`, huérfanos, único SuperAdmin activo, candidatos ambiguos, tablas/grants/RLS, RPC anon, TRUNCATE, columnas Home e índices/settings.

## 5. Migraciones exactas

El repositorio tiene **55 migraciones**. El inventario de 3.25.7 confirmó 31 versiones aplicadas en remoto hasta `20261003181310`; quedan estas **24 migraciones locales pendientes** para el plan remoto:

1. `20261004120000_provider_identity_and_draft_reuse.sql`
2. `20261004121000_admin_user_role_management.sql`
3. `20261004122000_notification_recipients_and_activity.sql`
4. `20261004123000_category_audit.sql`
5. `20261004124000_review_requirements_by_type.sql`
6. `20261004125000_admin_audit_read.sql`
7. `20261004130000_suspended_session_gate.sql`
8. `20261004131000_admin_account_suspension.sql`
9. `20261004132000_pre_request_execute_roles.sql`
10. `20261004132500_capture_provider_role_candidates.sql`
11. `20261004133000_provider_role_separation.sql`
12. `20261004134000_admin_mutation_capability.sql`
13. `20261004135000_restrict_notification_helper.sql`
14. `20261004140000_role_business_transition_guard.sql`
15. `20261004141000_admin_settings_audit_and_user_status.sql`
16. `20261005000000_contact_messages.sql`
17. `20261005001000_admin_user_deletion.sql`
18. `20261005002000_contact_and_notification_settings.sql`
19. `20261005003000_pre_request_service_role.sql`
20. `20261005004000_revoke_anon_admin_rpc.sql`
21. `20261005005000_reconcile_business_home_fields.sql`
22. `20261005006000_security_roles_grants_owner.sql`
23. `20261005007000_allow_soft_deleted_profiles.sql`
24. `20261005008000_install_profile_privilege_guard.sql`

No se ejecutó `db push`, ni se modificó historial remoto.

## 6. Checkpoints y assertions

- Preflight: `scripts/supabase-production-preflight.sql` produce solo agregados para perfiles/roles/admins, negocios/owners, solicitudes, reservas, notificaciones y auditoría. Capturar antes de migrar.
- Postflight: `scripts/supabase-production-postflight.sql` falla ante huérfanos, FK distinta de `profiles(id) ON DELETE RESTRICT`, cantidad de SuperAdmins distinta de uno activo, candidatos customer ambiguos promovidos, contacto/RLS/grants inseguros, RPC admin ejecutable por anon, TRUNCATE API, campos/índice Home o defaults ausentes. Comparar agregados antes/después.
- Las suites 3.25.6 y 3.25.8 validan grants/RLS, RPC admin, sesiones, auditoría, roles y bootstrap; no sustituyen la comparación del snapshot ni la revisión de migración en QA.

## 7. Edge Functions y secretos

Type-check local pasó para `submit-contact`, `admin-user` y `notify-provider-review`. Los tests Deno de validación de contacto/CORS pasaron **4/4**. La integración HTTP local de `submit-contact` y `admin-user` pasó: CORS, métodos/payloads, contacto anónimo/autenticado y RLS, permisos admin, invitación local, cambios de rol/suspensión, auditoría y último administrador. No se envió correo externo.

| Secreto/configuración | Local | Producción |
|---|---|---|
| `SUPABASE_URL` | PRESENT (runtime local) | UNVERIFIED |
| `SUPABASE_ANON_KEY` | PRESENT (runtime local) | UNVERIFIED |
| `SUPABASE_SERVICE_ROLE_KEY` | PRESENT (runtime local) | UNVERIFIED |
| `ADMIN_NOTIFICATION_WEBHOOK_SECRET` | no requerido por las dos funciones probadas | UNVERIFIED |

La presencia remota no se consultó para no operar sobre Supabase. `notify-provider-review` solo tuvo type-check, no prueba HTTP local. No se desplegó ninguna función.

La fase 3.25.7 reportó que la contraseña temporal de login de CLI expuesta por un `--dry-run` anterior fue renovada por una conexión enlazada posterior. En esta continuación no se usó ni mostró ninguna credencial remota.

## 8. Validación ejecutada al retomar

| Comando/validación | Resultado |
|---|---|
| `dart format .` | OK, 203 archivos, 0 cambios |
| `flutter analyze` | OK, sin issues |
| `flutter test` | OK, **630/630** |
| `scripts/check_text_encoding.ps1` | OK |
| `git diff --check` | OK; advertencias LF→CRLF informativas |
| `flutter build web --release` | OK |
| `npx supabase db reset --local --no-seed` | OK, 55/55 migraciones |
| Suites SQL 3.17 admin, 3.17.3 requests, 3.21 security, 3.22 admin, 3.25.6 security, 3.25.8 bootstrap | **6/6 OK**; test 3.25.8 vuelto a ejecutar tras ampliar provider/customer |
| Deno shared tests | **4/4 OK** |
| Deno type-check de las 3 Edge Functions | OK |
| HTTP local Edge/API | OK para integración 3.25.2 (`submit-contact`, `admin-user`) |

## 9. Estado final

- Migraciones en repo: **55**; pendientes según inventario remoto de 3.25.7: **24**.
- Tests Flutter: **630**.
- Bootstrap/seguridad SQL: **6/6 suites**, incluidos escenarios 3.25.8.
- Backup: snapshot anterior restaurado localmente y ZIP DPAPI verificado; flujo nuevo documentado y backup endurecido, pero falta probar sus scripts de extremo a extremo en QA y confirmar recuperación remota/PITR.
- `super_admin`: ninguno en producción según baseline previo; bootstrap local probado; ningún usuario real promovido.
- Edge/secrets: local probado según arriba; presencia de secretos de producción no verificada.
- Rollback: documentado; falta validar recuperación contra backup operativo actual.

**READY FOR REMOTE APPLY: NO.** Bloqueos técnicos: backup remoto restaurable y retención/PITR actuales no confirmados; procedimiento de backup→descifrado→replay con los scripts de esta fase no ensayado; secretos Edge de producción sin verificar. Resolver en QA/operaciones autorizadas antes de plantear apply.

Confirmación: sin cambios remotos, sin DB push, sin creación/promoción de SuperAdmin remoto, sin despliegue Edge ni frontend, sin commit y sin push. Ningún dump real se añadió al repo.
