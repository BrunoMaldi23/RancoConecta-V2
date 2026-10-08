# Fase 3.31 — Modelo final de roles

## Addendum Fase 3.32: solicitudes y reservas an?nimas

El visitante contin?a siendo `anon`, sin identidad Auth ni fila en `profiles`. La solicitud de servicio se env?a por `submit-request` y se guarda con nombre, tel?fono y consentimiento; las reservas de mesa y alojamiento usan el mismo canal seguro. No se habilita acceso directo de anon a las tablas. El detalle de implementaci?n, l?mites y contratos queda en `phase-3-32-anonymous-customer-flow.md`.

Las solicitudes/reservas an?nimas son ahora parte del modelo ADMIN / PROVIDER / ANON. Las cuentas hist?ricas `legacy_customer` no participan en estos flujos.

## Resultado ejecutivo

Modelo producto acordado: **ADMIN / PROVIDER / ANON**. No se aplicó ningún cambio remoto, no se desplegó, y no hubo commit ni push.

**ROLE MODEL MIGRATION: NOT READY**  
**READY FOR PRODUCTION APPLY: NO**

El bloqueo técnico restante es el flujo anónimo completo de solicitudes: el formulario y las operaciones asociadas todavía dependen de una sesión/perfil visitante, mientras `service_requests.customer_id` sigue siendo obligatorio y el contrato no guarda nombre/teléfono del visitante en la solicitud. La nueva migración retira las políticas y RPC de consumidor registradas; por eso no debe aplicarse hasta que exista y se pruebe el reemplazo anónimo seguro, con rate limit/idempotencia, confirmación, solicitudes y reservas compatibles.

## Cambios preparados

- `ProfileRole` expone `admin`, `provider` y `legacyCustomer`; los aliases de compatibilidad para serializaciones/tests antiguos no son roles del producto. `admin` es el gate global y `provider` no lo supera.
- La consola ya no inicia una sesión `super_admin` separada. El helper SQL final comprueba perfil `admin` activo directamente.
- El selector de usuarios ofrece solo Administrador/Proveedor y el filtro ya no presenta visitantes ni clientes.
- `notify-provider-review` notifica a perfiles `admin` activos.
- `/sign-up` solo permite el flujo proveedor (`next=/account`); el acceso general lleva a `/provider/join`.
- Se añadieron migraciones `20261007220000_add_legacy_customer_role.sql` y `20261007221000_simplify_admin_provider_visitor_roles.sql`.
- La transición reserva la promoción global al ID confirmado y a perfiles históricos `super_admin`; otros `admin` ambiguos pasan a `provider` solo si tienen un negocio propio; sin esa evidencia quedan como `legacy_customer` suspendidos. Perfiles `customer` se conservan como `legacy_customer` suspendidos. No se borra ni cambia ninguna identidad Auth, negocio ni historial.
- La tabla `super_admin_sessions` queda sin uso de aplicación y sus RPC de inicio/cierre pierden EXECUTE. Se conserva por ahora como residuo histórico sin privilegios API; no se ha hecho un `DROP`.
- La búsqueda administrativa solo devuelve `admin` y `provider`. El RPC de cambio de rol acepta solo esos dos valores y el backend protege el último administrador activo.
- Se quitaron las policies/RPC de consumidor sobre solicitudes hasta que el nuevo flujo anónimo esté listo. Esto es deliberadamente un bloqueo de apply, no una afirmación de que las solicitudes públicas estén implementadas.

## Transición de datos simulada

Snapshot cifrado de producción restaurado en PostgreSQL 16 aislado, sin Docker. Se reprodujo la secuencia exacta de **29 migraciones pendientes anteriores** (no se repitió el hotfix `20261007160000`, ya registrado), seguida de las dos nuevas migraciones. Resultado: 31/31 aplicadas en orden.

Baseline/postflight de roles del snapshot:

| ROLE BEFORE | ROLE AFTER | COUNT | REASON |
|---|---|---:|---|
| admin confirmado | admin | 1 | identidad global confirmada explícitamente |
| provider | provider | 1 | se conserva |
| customer | legacy_customer | 13 | identidad/perfil conservado, suspendido y sin acceso de producto; sin promoción |
| super_admin | admin | 0 | no había filas en el snapshot restaurado |

Negocios antes/después: **12/12**. Perfiles: **15/15**. No se borraron identidades. La política `profiles_role_check` acepta solo `admin`, `provider`, `legacy_customer`; no quedan perfiles con `customer` o `super_admin`.

El test SQL `supabase/tests/phase_3_31_role_model.sql` pasó contra la copia migrada. Incluye gate admin, roles retirados, búsqueda de usuarios, policies/RPC de solicitudes retiradas, permisos de sesión legacy y rechazo transaccional de la degradación del único admin.

## Migraciones pendientes

El estado base del reporte 3.30 era 61 locales/32 remotas/29 pendientes. Esta fase añade dos migraciones: **63 locales/32 remotas/31 pendientes**. No se marcó nada en producción.

Secuencia ejecutada en la copia:

1. `20261004120000`–`20261004141000` (15 migraciones).
2. `20261005000000`–`20261005008000` (9 migraciones).
3. `20261007170000`, `20261007180000`, `20261007190000`, `20261007200000`, `20261007210000` (5 migraciones).
4. `20261007220000_add_legacy_customer_role.sql`.
5. `20261007221000_simplify_admin_provider_visitor_roles.sql`.

El hotfix grants-only `20261007160000` sigue aplicado y no forma parte de las pendientes.

## Seguridad/roles

- `current_user_is_admin()` ya no depende de `super_admin_sessions`; significa `auth.uid()` con perfil `admin` y estado `active`.
- `is_super_admin()` queda temporalmente como alias de compatibilidad sin semántica separada; no hay llamada de consola Flutter. Las RPC `start_super_admin_session` y `end_super_admin_session` no son ejecutables por roles API.
- El trigger SQL previene `customer`/`super_admin` nuevos y evita dejar cero admins activos al degradar, suspender, eliminar o borrar el perfil del último administrador. El RPC de rol permite solo `admin` y `provider`; el cambio de UI confirma antes de ejecutar.
- El perfil histórico ambiguo no se transforma a admin. Los perfiles que aún no tienen evidencia suficiente no se promueven.
- El ownership de negocios continúa siendo relación `businesses.owner_id`; la prueba aislada conserva 12 negocios.
- La auditoría `SECURITY DEFINER` completa de Fase 3.30 no sustituye una reauditoría posterior a estos cambios; este pase valida solo el contrato de rol y las funciones reemplazadas.

## Bloqueos que impiden aplicar

1. **Solicitudes anónimas no terminadas.** Agregar campos públicos (nombre/teléfono), `customer_id` nullable o equivalente, RPC con validación de negocio/servicio, RLS sin lectura anónima, idempotencia y rate limit durable; adaptar la pantalla y su confirmación. La sesión/perfil visitante actual contradice el modelo final.
2. **Reservas/actividad aún ligadas a Auth.** Auditar y adaptar reservas de mesa/alojamiento donde el modelo permita visitantes; no se ha cambiado el esquema ni el UI de reservas en esta fase.
3. **Auth visitante legado.** El trigger de alta no crea perfil para `auth.users.is_anonymous`, pero pantallas/repositorios actuales todavía intentan crear sesión anónima y persistir perfil/consentimiento. Esa ruta requiere reemplazo antes de aplicar.
4. `app_role` y código SQL histórico mantienen referencias compatibles a valores retirados. No se borró el tipo ni la tabla de sesiones sin una auditoría completa de dependencias en el conjunto final.

Los puntos anteriores son bloqueos técnicos reales; por tanto las decisiones humanas de categorías, secret y autorización no habilitan todavía el apply.

## Validaciones

- `dart format .`: 204 archivos revisados; 4 formateados durante esta fase.
- `flutter analyze`: PASS.
- `flutter test`: primer pase detectó 4 aserciones antiguas (ADMIN no global, etiqueta SuperAdmin, rol cliente eliminable); se actualizaron al modelo nuevo. Resultado final pendiente de reejecución.
- Secuencia aislada: 31 migraciones PASS.
- Contrato SQL de roles: PASS.
- Deno, Edge type-check, build, encoding y `git diff --check`: pendientes de la corrida final.

## Producción

No se ejecutaron consultas ni escrituras remotas en esta fase. No se aplicaron migraciones, no se cambiaron perfiles/roles, no se desplegó Edge/frontend, y no hubo commit/push. El hotfix remoto previo sigue siendo una referencia del reporte anterior; no fue revalidado aquí.
