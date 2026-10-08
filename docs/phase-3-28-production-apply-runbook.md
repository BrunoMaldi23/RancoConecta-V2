# Runbook de producción — estado posterior a Fase 3.32

> **APPLY PARCIAL EJECUTADO 2026-10-07. NO REPETIR MIGRACIONES NI BACKFILLS.** Las 32 migraciones pendientes se aplicaron por bloques; historial final 64/64, 0 pendientes. El smoke de solicitud anónima no encontró un negocio publicado con categoría primaria y servicio activo coincidentes. No hubo frontend deploy, commit ni push. Ver el informe de Fase 3.33.

## Ejecución Fase 3.33 — estado actual

Apply parcial ejecutado el 2026-10-07 con autorización humana. Las 32 migraciones pendientes se aplicaron por bloques; historial final 64/64, 0 pendientes. Se aplicaron las tres categorías aprobadas, se configuró el secret requerido y se desplegaron las cuatro Edge Functions. El smoke de solicitud anónima no pudo crear una solicitud válida porque los datos actuales no contienen una combinación de negocio publicado, categoría primaria y servicio activo. Por la regla de abort no se desplegó frontend, ni se creó commit/push. No repetir migraciones ni backfills ya aplicados. Ver `phase-3-33-production-apply-report.md`.

## Estado y guardas

- Proyecto producción: RancoConecta (`exdaagbftotnnoyetcpg`). Confirmar el ref antes de cualquier intervención futura.
- No volver a aplicar este paquete ni ejecutar `db push` general.
- El hotfix `20261007160000_emergency_grants_only.sql` ya se aplicó y registró. No repetir.
- Inventario al inicio del apply: **64 migraciones locales / 32 remotas / 32 pendientes**. Estado posterior: **64/64, 0 pendientes**.
- No se requiere decision de primer SuperAdmin. La identidad global confirmada es `admin@lagoranco.cl`, profile ID `a7affb25-ad32-4836-be38-cb2af81343c7`, con `role=admin` en la transicion.
- Personas consumidoras no tienen cuenta: `anon` navega y envía una solicitud con datos de contacto; no se crea Auth user/profile.

## Flujo público nuevo y condición pendiente

El flujo se implementa en `20261007222000_anonymous_customer_submissions.sql`: RPC disponible solo a `service_role`, sin permisos directos anon, consentimiento, límites e idempotencia durables. El secret quedó PRESENT, las tres categorías aprobadas y el backup ya fueron aplicados/verificados. Antes del frontend deploy, resolver datos elegibles de negocio/categoría/servicio y repetir el smoke HTTP válido de solicitud anónima.

## Secuencia de migraciones aplicada (histórico; no repetir)

La siguiente secuencia se aplicó tras backup verificado, preflight y autorización humana:

1. Aplicar el paquete pendiente completo en orden timestamp, después del preflight. No marcar versiones manualmente. El conjunto actual de 32 incluye:
   - 15: `20261004120000`–`20261004141000`.
   - 9: `20261005000000`–`20261005008000`.
   - 5: `20261007170000`–`20261007210000`.
   - 2: `20261007220000_add_legacy_customer_role.sql` y `20261007221000_simplify_admin_provider_visitor_roles.sql`.
   - 1: `20261007222000_anonymous_customer_submissions.sql` (solicitudes y reservas anonimas).
2. No repetir `20261007160000_emergency_grants_only.sql` salvo que el preflight muestre regresión y se apruebe una corrección aislada.
3. La migracion anonima cierra el paquete actual. Ejecutar sus assertions SQL de grants, consentimiento, rate limit, idempotencia y reservas antes del Edge deploy.

## Apply por bloques y asserts

### A. Backup/snapshot

- Crear backup cifrado antes del apply.
- Verificar integridad y hacer restore en PostgreSQL aislado.
- Abort si checksum/decrypt/restore/schema comparison falla. Restaurar snapshot previo en QA si un ensayo cambia el baseline.

### B. Preflight y grants

- Confirmar project ref, migration history, grants efectivos por anon/authenticated/PUBLIC, RPC admin, policies y tablas.
- Esperado del hotfix previo: TRUNCATE anon/authenticated=0 y RPC admin anon=0.
- Abort ante cualquier drift; no repetir automáticamente el hotfix.

### C. Identidad/roles

- Aplicar solo después del cierre requests/QA.
- La migración conserva Auth/profile IDs, negocios e historial. `customer` histórico pasa a `legacy_customer` suspendido; no se promueve. Un `admin` ambiguo queda provider solo con relación de negocio propia, si no queda legacy. Perfiles super_admin anteriores se convierten a admin. Solo el ID confirmado recibe la promoción explícita.
- Aserciones: ID confirmado activo `admin`; cero `customer`/`super_admin` en perfiles; no existen admins activos no revisados; 0 pérdida de Auth/profile/negocios/solicitudes/reservas/notificaciones/auditoría.
- Último admin: probar rollback transaccional de degradar/suspender/soft-delete y borrar perfil.
- Abort si aparece una identidad admin legacy no explicada o conteos distintos al snapshot firmado.

### D. Ownership y funcionalidad

- Verificar `businesses.owner_id -> profiles(id) ON DELETE RESTRICT`, providers propietarios y ausencia de huérfanos.
- Aplicar funcionalidad en el orden de dependencias del inventario actualizado, solo tras snapshots/assertions por bloque.
- Incluye Contacto, settings y notificaciones si faltan en la history remota.
- No corregir categorías ambiguas automáticamente. Aplicar solo backfills con evidencia objetiva y aprobación para cada uno de los otros tres.

### E. Secrets y Edge

- Configurar `ADMIN_NOTIFICATION_WEBHOOK_SECRET` si sigue REQUIRED antes de desplegar la función que lo consume. Generarlo fuera del repo mediante RNG criptográfico; pasarlo por archivo temporal privado a `supabase secrets set --env-file`, borrar ese archivo inmediatamente y no imprimirlo.
- Deploy solo tras migraciones/asserts: `submit-contact`, `admin-user`, `notify-provider-review` y `submit-request`. Validar CORS explicito y health/smoke sin PII.
- Abort si falta un secret requerido, CORS no coincide, o Edge type-check/health fallan.

### F. Superficie de aplicación

- No se requiere decision de primer SuperAdmin. La identidad global confirmada es `admin@lagoranco.cl`, profile ID `a7affb25-ad32-4836-be38-cb2af81343c7`, con `role=admin` en la transicion.
- Probar Admin/Provider/anon, solicitudes y reservas con cuentas/datos QA primero.
- Frontend deploy solo con build release aprobado y smoke final de Home/Explore/detalle/Contacto/solicitud/login/provider.

### G. Git

- Solo después de revisión humana: stage los archivos aprobados, revisar diff, commit y push según política del repositorio. Esta fase no hizo commit ni push.

## Rollback

- Grants: solo el rollback exacto documentado para grants; aplicar únicamente con aprobación y si postflight detecta una regresión crítica.
- Roles: preferir corrección forward auditada. No revertir automáticamente una promoción/democión porque ya puede haber administración legítima; conservar audit logs. Restore del backup si hay pérdida/corrupción o grants/roles no pueden recuperarse con una corrección puntual.
- Ownership/data backfill: rollback por fila solo si la evidencia/valor previo se registró; restore si la integridad referencial/data diff no se puede reconciliar.
- Edge/secrets/frontend: revertir versión Edge o frontend; rotar secret si se expuso. No borrar tablas/datos como rollback por defecto.
- En cualquier abort condition: parar el bloque, guardar métricas sin PII, no marcar migraciones futuras como aplicadas.

## Decisiones humanas que quedan después del cierre técnico

1. Elegir categorías para tres negocios marcados `MANUAL_REVIEW_REQUIRED`.
2. Configurar el secret requerido `ADMIN_NOTIFICATION_WEBHOOK_SECRET`.
3. Aprobar el apply de producción y el backup inmediatamente previo.

No queda pendiente elegir primer SuperAdmin; la identidad admin confirmada es la indicada arriba.
