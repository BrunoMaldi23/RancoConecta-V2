# Fase 3.25.5 — Plan de migración remota Supabase

Fecha: 2026-10-05. Proyecto consultado en modo solo lectura: `ranco_conecta_2` (`exdaagbftotnnoyetcpg`, región `us-east-1`). No se ejecutaron escrituras remotas, migraciones, `db push`, deploy, ni cambios de usuarios o datos. El reporte no contiene nombres, correos ni credenciales.

## Resultado

**READY FOR REMOTE APPLY: NO.** La estructura remota y las migraciones están inventariadas para el subconjunto crítico, pero no se puede dar una secuencia de aplicación que cumpla la regla de recuperación: el endpoint de backups informa `pitr_enabled=false` y `backups=[]`; debe verificarse en Dashboard si el plan ofrece un backup diario restaurable. Además, el modelo actual hace que `super_admin` comparta autorización de administrador tenant y hay divergencias estructurales no reproducidas fielmente en el dry run anterior. No ejecutar las 20 migraciones hasta resolver esos puntos y repetir simulación contra un snapshot completo.

## 1. Estado de migraciones y baseline

`npx supabase migration list --linked` confirmó 31 versiones aplicadas, desde `20260907000000` hasta `20261003181310`. Las 20 locales restantes son exactamente las versiones de la tabla de clasificación de abajo. El repo tiene 51 migraciones. No se propone `migration repair`: la historia remota representa lo que realmente se ejecutó; que haya objetos manuales preexistentes debe reconciliarse mediante migraciones idempotentes auditadas, no marcando versiones como aplicadas.

## 2. Comparación del drift

El inventario comparó columnas, tipos, nullability/defaults disponibles, PK/FK/UNIQUE/CHECK, índices, triggers, RLS/policies y permisos para `profiles`, `businesses`, `business_members` (identidad de prestador/tenant), `notifications`, `system_settings`, `audit_logs`, `service_requests`, `lodging_bookings` y `gastronomy_table_reservations`. `contact_messages` no existe remotamente; sí está creada en el reset local. No existe tabla `providers` en ninguno de los dos catálogos consultados: identidad de prestador se expresa mediante `profiles.role` y `business_members`.

| Área | Local esperado | Remoto actual | Clasificación / acción propuesta |
|---|---|---|---|
| `profiles.role`, `account_status` | enums `app_role`, `account_status`; mismas etiquetas funcionales | `text` con CHECK de valores | A: drift histórico legítimo/probable baseline remoto. Mantener tipos remotos por ahora: convertir `text` a enum puede fallar en datos/funciones y exige reconciliación propia, no está cubierto por las 20 migraciones. |
| `profiles` resto, PK y FK | UUID PK `id`; FK a `auth.users(id) ON DELETE CASCADE`; RLS | misma PK/FK y datos de columna funcionales; RLS | La forma básica coincide. Policies distintas: remoto `profiles_select_own` permite `id=auth.uid() OR is_admin()` y `profiles_update_own` con igual condición; local conserva acceso propio básico más policy restrictiva de sesión suspendida. Revisar la política amplia de actualización contra la nueva RPC/guard antes de migrar. |
| `businesses` fields Home | cuatro columnas boolean/numeric/int not null, defaults false/true/0/0, checks rating 0–5 y count >=0, índice btree | coincide, incluyendo `idx_businesses_featured`, checks y defaults | Drift ya representado en `20261005005000_reconcile_business_home_fields.sql`; esta migración valida equivalencia y es idempotente para esas piezas. |
| `businesses` tipos/columnas | `business_type`, `publication_status`, `verification_status` enum; `latitude`, `longitude`; Home fields | tipos `text` y CHECKs; `published_at` existe; no `latitude`/`longitude`; Home fields presentes | A/C mixto: schema histórico remoto/local diverge. Preservar remoto mientras no se conozca uso de `published_at` y valores geográficos. Crear migración de reconciliación explícita antes de futuras funciones que requieran esos campos; no convertir/drop en esta fase. |
| `businesses` owner | `owner_id uuid NOT NULL â†’ profiles(id) ON DELETE RESTRICT`; índice btree `businesses_owner_idx` | `owner_id uuid NOT NULL â†’ auth.users(id) ON DELETE CASCADE`; índice btree `idx_businesses_owner` | Drift estructural con efecto de borrado material; decisión en sección 3. Remoto tiene 0 owners sin profile y 0 sin auth.users al momento de la consulta. |
| `business_members` | id/business/user UUID; role/status text y checks `owner/manager/staff`, `active/invited/suspended/removed`; unique `(business_id,user_id)`; FK business cascade y user profiles cascade | mismas columnas/checks/unique y referencias observadas | Compatible en forma revisada. RLS remoto incluye “users read own business memberships”; local agrega policy restrictiva de sesión. Confirmar grants/RLS postmigración. |
| `notifications` | columnas/PK/defaults funcionales coincidentes; RLS y filtros por user_id | columnas/PK equivalentes; policies de SELECT propio y UPDATE propio leído | RLS es propia de usuario en remoto; local agrega session gate y triggers de actividad. Los eventos nuevos no hacen backfill. |
| `system_settings` | id/key/value/updated_by/timestamp y unique key; admin read y RPC auditada para mutar | misma forma; policies admin read y admin update directo | 041410 retiraría el update directo y revocaría privilegio, después crea ruta auditada. Riesgo de compatibilidad con clientes que escriban directo; confirmar consumidores antes. |
| `audit_logs` | estructura/PK coincidente; RLS con policy de lectura admin | RLS activa pero sin policy de lectura en catálogo remoto; sin acceso de cliente concedido por policy | 041250 introduce policy admin read; revisar la política y privilegios base con API roles. |
| `service_requests` | local enum `urgency/status`, `latitude/longitude`, FKs y RLS del historial local | remoto `urgency/status text` con CHECK, sin lat/long; `customer_id â†’ auth.users CASCADE`, `business_id SET NULL`, categoría/location RESTRICT; policies de cliente/proveedor/admin | Drift legítimo/compatibilidad. Las tablas y filas no deben reconstruirse. Enum conversion requiere mapeo, validar valores y funciones; dejar para migración dedicada. |
| `lodging_bookings` | reservas/alojamiento; checks de fechas, montos/huéspedes; RLS participantes | constraints revisados coinciden funcionalmente; policy remota permite huésped/dueño/manager; local agrega session gate | Compatible en tabla; comparar función de autorización y grants antes de cambiar policies. |
| `gastronomy_table_reservations` | reservas mesa y checks de estado/guest; RLS propio/manager | checks y FK business cascade y user auth cascade; policies de cliente/manager | Compatible en forma revisada; local agrega session gate y trigger de actividad. |
| `contact_messages` | tabla nueva con checks/FK, índice por estado/fecha, RLS admin read, trigger auditoría/notificación | ausente | Creación nueva, sin colisión con tabla remota. Aplicar únicamente después del bloque de funciones/settings del que depende y validar acceso público solo mediante Edge Function. |

No se encontró un índice de columna que contradiga un objeto PK/unique; los índices de `owner_id` hacen el mismo trabajo aunque tengan distinto nombre. Para esta ejecución final sigue pendiente entregar/adjuntar un dump de esquema remoto y hacer comparación completa de cada expresión de policy, definición de trigger y ACL contra los 20 archivos. No inferir que columnas coincidentes prueban semántica idéntica.

## 3. `businesses.owner_id`

La consulta remota de catálogo confirmó: `uuid NOT NULL`, FK validada `businesses_owner_id_fkey â†’ auth.users(id)`, `ON DELETE CASCADE`, `ON UPDATE NO ACTION`; índice btree `idx_businesses_owner`. Local: `uuid NOT NULL â†’ public.profiles(id)`, `ON DELETE RESTRICT`; el profile apunta a `auth.users` con cascade; índice btree `businesses_owner_idx`. Al muestrear el estado remoto actual, no había business cuyo owner no tuviera profile ni auth user (conteos 0/0). No se midió una carrera entre preflight y aplicación.

Modelo recomendado: **B — migrar remoto a `profiles(id) ON DELETE RESTRICT`, sujeto a verificación repetida inmediatamente antes de aplicar y respaldo comprobado.** La identidad de propietario está modelada como perfil en el esquema local, las membresías referencian profiles y la eliminación administrativa es lógica para conservar negocios e historial. Usar `auth.users` con cascade permite que un borrado físico de Auth borre el business del propietario; no coincide con esa retención.

- **A conservar remoto:** evita una modificación inmediata, pero deja comportamiento productivo distinto y mantiene riesgo de cascada física de business; requiere rehacer el modelo local para igualarlo, contrario a la eliminación lógica/historial.
- **B migrar a local:** requiere retirar/recrear el FK (no borrar filas), confirmar no huérfanos y ensayar el efecto de delete en un clon. Acción remota aún NO autorizada; si datos perfil faltan, abortar y remediar por separado.
- **C adaptar migraciones futuras a remoto:** aplaza el cambio, pero una base limpia ya no reproduce el modelo/cascade remoto y se propagaría el riesgo. No recomendada como estado final.

Antes de B, comparar counts business y membership; respaldar; instalar nueva FK `NOT VALID` tras asegurar perfiles; validar; solo después retirar la FK anterior. No cambiar ni soltar el FK remoto en esta fase. Revisar todas las referencias `owner_id` y triggers/funciones antes de producir la migración correctiva.

## 4. Roles y simulación de `04133000`

La migración histórica se leyó completa. El UPDATE filtra exactamente `p.role='customer'` y cambia a `provider` si existe `businesses.owner_id=p.id` **o** una membresía activa con role `owner`/`manager`. No filtra account_status/is_anonymous. Luego actualiza funciones de registro de prestador, helper `current_user_is_provider`, borrador de negocio y guard del profile. No actualiza business_members ni roles admin.

Consulta agregada remota (sin PII): `admin=1`, `customer=13`, `provider=1`; todos los perfiles del grupo observado tienen `account_status=active`; 9 customers son anónimos. Simulación exacta del predicate:

| ROL ACTUAL | ROL RESULTANTE | CANTIDAD |
|---|---|---:|
| customer, tiene negocio y membership activa owner/manager | provider | 3 |
| customer, sin match | customer | 10 (9 anónimos + 1 no anónimo) |
| provider, tiene negocio/membership | provider | 1 |
| admin, cumple el match de negocio/membership | admin | 1 |

Los tres afectados son `customer â†’ provider` y cumplen ambas condiciones (negocio directo y membership activa owner/manager); admin y provider no se degradan porque el WHERE excluye sus roles. No se incluyeron nombres/correos. El resultado no atribuye “propiedad de tenant” a `profiles.role`: `business_members.role=owner` sigue siendo rol scoped al negocio. El perfil `provider` habilita el flujo de prestador en el producto. El cambio es consistente con ese diseño solo si se acepta expresamente esa distinción. **Preflight obligatorio:** rerun counts justo antes de migrar y comparar que sigan siendo esos mismos totales por condición; abortar si cambia el conjunto o si aparecen roles/status nuevos.

La migración no cambia un rol `admin` ni `super_admin` a otro rol; al día de auditoría remoto no había ningún `super_admin`. El riesgo principal no es degradación, sino que el perfil de propietario necesita provider eligibility y que hoy se mezclan privilegios de operador de plataforma y admin tenant (ver sección 6). No editar `04133000`; aplicar tal cual solo después de documentar/aceptar los 3 cambios, o dejar pendiente hasta que `current_user_is_provider` use membresía y no perfil global. No crear migración de reversión automática.

## 5. Tipos/columnas con resolución propuesta

- `businesses`: remoto `text` + CHECK para 3 estados/tipo frente a enums locales. Mantener el modelo remoto hasta inventariar todos los valores y dependencias; migración específica posterior, con conversión transaccional ensayada, sin casts implícitos. `published_at` remoto es campo de producción sin historial identificado; conservar e incorporar a migración que lo adopte. `latitude/longitude` son locales sin remoto; revisar si Home/provider flow los requiere y migrar solo con contrato aprobado.
- `profiles`: `role` y `account_status` remotos son text CHECK frente a enums locales; historial remoto legítimo probable. No convertir como parte del lote sin snapshot/mapeo completo y catálogo de funciones/policies dependientes.
- `service_requests`: `urgency/status` text CHECK remoto vs enum local; remote no tiene coordenadas. No convertir ni omitir sin verificar DTOs y datos; extender baseline/reconciliación si columnas productivas deben ser preservadas. Pruebas de valores inesperados antes de cast.
- Otras columnas/FKs revisadas en `business_members`, `notifications`, settings, audit, lodging y table reservations son funcionalmente parecidas. Diferencias de policy/RLS están descritas arriba: 041300 añade policy restrictiva `account session allowed` a todas las tablas RLS y storage; esta intervención es transversal y no se debe tratar como un cambio rutinario.
- `contact_messages`: objeto nuevo; no hay histórico a perder. 050050 Home está ya cubierto por migración idempotente.
- **ACL de tablas (hallazgo de hardening):** para las nueve tablas remotas existentes de la comparación, `anon` y `authenticated` tienen SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES y TRIGGER. Las policies RLS limitan filas/operaciones normales —no hay policy anon de modificación y las políticas por usuario exigen `auth.uid()`—, pero estos grants exceden el mínimo; RLS no filtra `TRUNCATE`. La migración 050040 revoca EXECUTE a RPC, no estas ACL. Se necesita migración adicional explícita: revocar privilegios de tabla no necesarios de anon/authenticated y volver a conceder por tabla solo las operaciones Data API exigidas; mantener lectura anónima de businesses published y probar todos los flujos en clone. No aplicar esa revocación sin inventario de rutas/clientes porque puede romper escrituras legítimas.

Clasificación: drift histórico legítimo/probable en tipos remotos de profiles/businesses/requests; remoto desactualizado respecto a campos locales coordenadas pero origen no establecido; remoto con `published_at` y Home sin historial original, ahora reconciliado para Home. No se encontró evidencia suficiente para etiquetar ningún campo como eliminado del producto.

## 6. RPC admin anon y modelo de SuperAdmin

Se encontraron 12 funciones `admin_* SECURITY DEFINER` con EXECUTE para anon. Las 12 son propiedad `postgres`, usan `search_path=public, auth`, conservan EXECUTE para `authenticated` y `service_role`; la mayoría tiene ACL explícita a `anon`, las demás la heredan por PUBLIC. `public` no concede CREATE a anon/authenticated, así que no pueden inyectar objetos al search_path actual. Las definiciones llaman `current_user_is_admin()`; cuatro no comprueban directamente `auth.uid()` pero delegan en el helper que exige perfil activo admin/super_admin. La lógica visible no muestra una escalada inmediata para usuario normal; aun así es **REQUIERE HARDENING** por grant público indebido y por falta de una frontera adecuada entre roles. Las mutaciones están limitadas al guard interno; `admin_update_whatsapp_settings` tiene validación de número básica y no audita directamente el cambio, lo cual requiere evaluación propia antes de producción.

| RPC (firma) | Propietario / grants actuales | Rol de ejecución previsto | Estado |
|---|---|---|---|
| `admin_analytics_summary()` | postgres; anon, authenticated, service_role | authenticated admin tenant; server service_role solo desde Edge | REQUIERE HARDENING |
| `admin_business_review_detail(uuid)` | igual | igual | REQUIERE HARDENING |
| `admin_business_review_queue(text,text,text,integer,integer)` | igual | igual | REQUIERE HARDENING |
| `admin_business_review_stats()` | igual | igual | REQUIERE HARDENING |
| `admin_get_business_review(uuid)` | igual | igual; retorna campos sensibles del negocio/owner | REQUIERE HARDENING |
| `admin_list_users(integer,integer)` | igual | authenticated admin tenant | REQUIERE HARDENING |
| `admin_publish_business(uuid)` | igual | authenticated admin tenant | REQUIERE HARDENING |
| `admin_reject_business(uuid,text,boolean)` | igual | authenticated admin tenant | REQUIERE HARDENING |
| `admin_request_business_changes(uuid,text)` | igual | authenticated admin tenant | REQUIERE HARDENING |
| `admin_restore_business(uuid)` | igual | authenticated admin tenant | REQUIERE HARDENING |
| `admin_suspend_business(uuid,text)` | igual | authenticated admin tenant | REQUIERE HARDENING |
| `admin_update_whatsapp_settings(text,boolean,boolean,boolean,boolean)` | igual | authenticated admin tenant; audit/change validation required | REQUIERE HARDENING |

`20261005004000_revoke_anon_admin_rpc.sql` selecciona `admin_* SECURITY DEFINER` con EXECUTE anon y revoca de `PUBLIC, anon`. El predicate cubre las 12 firmas observadas; no revoca `authenticated`, y debe volver a comprobarse después de crear/reemplazar el set de funciones. No quita permisos a RPC administrativas con otros nombres ni cambia la guardia interna.

**Bloqueo de jerarquía:** `current_user_is_admin()` remoto/local trata `admin` y `super_admin` igual. Las 12 RPC heredan ese acceso. Esto contradice el requisito de SuperAdmin SaaS aislado de datos privados de tenants. Antes de aplicar funciones admin se requiere diseño nuevo con `tenant_admin`/membership/permiso explícito y una superficie de operador SaaS separada, además de auditar políticas `is_admin()`. No basta revocar anon ni cambiar el role enum. Hacer migración nueva posterior que estreche las RPC/policies; ensayar no acceso de super_admin sin concesión explícita y acceso de admin tenant limitado a sus negocios. Este es blocker de seguridad.

## 7. Backup, PITR y dump previo

`npx supabase backups list --project-ref exdaagbftotnnoyetcpg` devolvió: `walg_enabled=true`, `pitr_enabled=false`, `backups=[]`, `physical_backup_data={}`. Esto confirma PITR deshabilitado y que la API no lista backup físico restaurable ahora. La respuesta no demuestra por sí sola la retención diaria del plan ni si hay un backup manual/daily fuera del endpoint. No se debe asumir que hay recuperación.

Verificación manual requerida antes de continuar: Dashboard del proyecto â†’ **Database â†’ Backups**, comprobar backup completado más reciente, retención/plan, y que opción **Restore** lo ofrece; **Settings â†’ Add-ons / Point-in-Time Recovery**, confirmar PITR estado/retención. Registrar hora del último backup, intervalo, retención, procedimiento y ventana de indisponibilidad. Supabase indica que los backups diarios aparecen en Database â†’ Backups, con retención según plan; PITR se configura aparte. Ver [Supabase Database Backups](https://supabase.com/docs/guides/platform/backups). No se disparó restore ni se descargó copia.

Procedimiento lógico previo (preparar en estación protegida con acceso de mínimo personal):

1. Crear carpeta temporal cifrada con ACL solo para operador DBA; confirmar BitLocker o volumen cifrado y espacio libre; definir retención/eliminación segura. No guardar URL/password en shell history, argumentos, logs, repo o docs.
2. Desde sesión segura de Supabase CLI con login ya gestionado, descargar schema: `npx supabase db dump --linked --schema public --file <ruta_cifrada>/public-schema.sql`.
3. Dump de datos críticos. `supabase db dump --linked --data-only --use-copy` no tiene selector de inclusión de tablas en el CLI; su `--exclude` excluye únicamente y podría copiar datos ajenos al alcance. Para el subconjunto solicitado, usar `pg_dump --data-only --format=custom --no-owner --no-privileges --table=public.profiles --table=public.businesses --table=public.business_members --table=public.lodging_bookings --table=public.gastronomy_table_reservations --table=public.service_requests --table=public.system_settings --table=public.audit_logs --table=public.notifications --file=<ruta_cifrada>/critical-data.dump` con conexión entregada por vault/secret manager de forma que no quede en historial/process list; probar versión pg_dump compatible. Incluir `contact_messages` si la tabla existe al momento del backup. El archivo contiene PII y debe cifrarse antes de persistir/transmitir.
4. Capturar también globals/roles si restauración necesita roles; no asumir que copia de datos reproduce Auth/Storage/Secrets/Edge Functions. Retener copia fuera del proyecto.
5. Generar SHA-256, guardar manifest sin credenciales, verificar `pg_restore --list` y restaurar schema/data a una instancia aislada vacía de QA; ejecutar checks de counts/FKs. No restaurar encima de producción para la verificación.
6. No aprobar aplicación hasta validar restauración de la última copia diaria o confirmar PITR utilizable por Dashboard. Un dump sin restore probado no cuenta como recovery confirmada.

Supabase documenta `db dump`/`pg_dump` para copia lógica y distingue objetos Storage (metadatos sí, objetos no); el respaldo DB no sustituye backup de Storage/Auth/config. [Guía de backup](https://supabase.com/docs/guides/platform/backups).

## 8. Clasificación de las 20 pendientes

| Migración | Categoría | Motivo / condición |
|---|---|---|
| `20261004120000_provider_identity_and_draft_reuse.sql` | APLICAR DESPUÃ‰S DE MIGRACIÃ“N DE RECONCILIACIÃ“N | Reemplaza Auth trigger/draft functions existentes; comparar `pg_get_functiondef`, trigger OID/events y grants primero. |
| `20261004121000_admin_user_role_management.sql` | APLICAR DESPUÃ‰S DE MIGRACIÃ“N DE RECONCILIACIÃ“N | Define RPC y profile guard; su ACL/roles deben seguir separación admin tenant/SuperAdmin. Aplicar luego del nuevo diseño. |
| `20261004122000_notification_recipients_and_activity.sql` | APLICAR DESPUÃ‰S DE MIGRACIÃ“N DE RECONCILIACIÃ“N | Crea/reemplaza helpers y tres triggers de eventos; probar recipients, dedupe y FKs contra snapshot. |
| `20261004123000_category_audit.sql` | APLICAR SIN CAMBIOS | Auditoría futura; trigger con `DROP IF EXISTS` solo para el trigger por nombre; verificar que no exista equivalente con otro nombre. |
| `20261004124000_review_requirements_by_type.sql` | APLICAR DESPUÃ‰S DE MIGRACIÃ“N DE RECONCILIACIÃ“N | Reemplaza función remota existente; revisar columnas/types reales `businesses` y tablas por tipo. |
| `20261004125000_admin_audit_read.sql` | APLICAR DESPUÃ‰S DE MIGRACIÃ“N DE RECONCILIACIÃ“N | Añade policy de lectura admin a `audit_logs`; rediseñar condición para no heredar acceso tenant a SuperAdmin. |
| `20261004130000_suspended_session_gate.sql` | REEMPLAZAR POR MIGRACIÃ“N NUEVA | Gate transversal con `authenticator.pgrst.db_pre_request`, policies restrictivas en todas las tablas y `storage.objects`; primero inventariar clientes/roles y preservar policies remotas. Nueva migración estrecha, probada por tabla/storage. |
| `20261004131000_admin_account_suspension.sql` | APLICAR DESPUÃ‰S DE MIGRACIÃ“N DE RECONCILIACIÃ“N | RPC nueva; ensayar no auto-suspensión/último admin y política super_admin separada. |
| `20261004132000_pre_request_execute_roles.sql` | APLICAR DESPUÃ‰S DE MIGRACIÃ“N DE RECONCILIACIÃ“N | Grant depende de función de gate que debe reemplazarse/definirse; duplicado funcional de 050030. Conservar historia; el grant repetido es idempotente. |
| `20261004133000_provider_role_separation.sql` | APLICAR DESPUÃ‰S DE MIGRACIÃ“N DE RECONCILIACIÃ“N | La simulación cambia 3 customers activos a provider; consistente solo bajo preflight y aceptación explícita de provider como perfil-capacidad y owner como business_members role. No degrada admin. |
| `20261004134000_admin_mutation_capability.sql` | APLICAR DESPUÃ‰S DE MIGRACIÃ“N DE RECONCILIACIÃ“N | El helper de capacidad debe reconocer admin tenant sin elevar SuperAdmin; revisar implementación/grants contra el nuevo modelo. |
| `20261004135000_restrict_notification_helper.sql` | APLICAR SIN CAMBIOS | Revoca invocación directa de helper; triggers existentes/nuevos deben seguir funcionando como función de trigger. Confirmar grants y ejecutar eventos en clon. |
| `20261004140000_role_business_transition_guard.sql` | REEMPLAZAR POR MIGRACIÃ“N NUEVA | Trigger global actual codifica negocio/membership como protección de provider profile; reescribir después de definir roles plataforma/tenant y probar propietario, manager, admin y SuperAdmin. |
| `20261004141000_admin_settings_audit_and_user_status.sql` | APLICAR DESPUÃ‰S DE MIGRACIÃ“N DE RECONCILIACIÃ“N | Retira UPDATE directo de settings y reemplaza RPC WhatsApp, agrega overload de búsqueda; confirmar UI usa RPC y que cambios quedan auditados. |
| `20261005000000_contact_messages.sql` | APLICAR DESPUÃ‰S DE MIGRACIÃ“N DE RECONCILIACIÃ“N | Tabla nueva ausente remotamente; revisar grants/RLS/triggers con esquema real y luego probar Edge antes de producción. |
| `20261005001000_admin_user_deletion.sql` | APLICAR DESPUÃ‰S DE MIGRACIÃ“N DE RECONCILIACIÃ“N | Soft-delete/anonimización; su seguridad depende de FK negocio y roles de último admin. Probar fixtures y no invocar sobre personas reales. |
| `20261005002000_contact_and_notification_settings.sql` | APLICAR DESPUÃ‰S DE MIGRACIÃ“N DE RECONCILIACIÃ“N | Inserta keys `ON CONFLICT DO NOTHING`, reemplaza funciones de notificación; respaldar settings y redefinir recipients bajo roles nuevos. |
| `20261005003000_pre_request_service_role.sql` | APLICAR DESPUÃ‰S DE MIGRACIÃ“N DE RECONCILIACIÃ“N | Repite grant de 041320, sin cambio de datos; mantener por historial si la secuencia depende de gate corregido. |
| `20261005004000_revoke_anon_admin_rpc.sql` | APLICAR DESPUÃ‰S DE MIGRACIÃ“N DE RECONCILIACIÃ“N | Cubre las 12 anon RPC actuales y futuras `admin_*`; ejecutar después de todas las funciones y re-verificar todos los `SECURITY DEFINER`, no solo prefijo admin. |
| `20261005005000_reconcile_business_home_fields.sql` | APLICAR SIN CAMBIOS | Validada localmente; guards comprueban tipos/defaults/checks/índice equivalente. Aplicar después del baseline de businesses y antes del smoke Home. |

Ninguna de estas 20 se clasifica como NO APLICAR de forma permanente. Tres necesitan migraciones nuevas de reemplazo y varias dependen de hardening de privilegios/modelo. No aplicar en orden ciego de timestamp mientras esas migraciones de reconciliación no estén diseñadas.

## 9. Simulación local y fixtures

Validación ya registrada desde Fase 3.25.4: `supabase db reset` desde vacío aplicó 51 migraciones; una simulación con las 31 migraciones antiguas, campos Home/índice/checks existentes y FK owner remoto aplicó las 20 restantes sin errores de duplicados. SQL tests cubrieron admin/contact/settings/notificaciones/soft-delete, pero esa simulación **no reprodujo** todos los tipos/columnas/policies/triggers remotos; por tanto no es una simulación de snapshot fiel y no desbloquea remoto.

Antes de producción: exportar snapshot remoto de esquema y datos protegidos, restaurarlo a proyecto local aislado (no sobrescribir dev), validar y complementar el snapshot sin perder tipos text, `published_at`, ausencia de coordenadas, FK owner remoto, policies y grants manuales. Fixtures sintéticos: perfil `admin`, `super_admin`, customer normal, customer prestador, owner, manager, owner sin membership, negocio con/sin relaciones opcionales, solicitud con/sin negocio, reservas de ambos tipos, notificaciones/settings/contact message. Guardar conteos y hashes agregados BEFORE/AFTER; comparar cada role/FK/fila. Nunca incluir PII real en logs/tests.

Pruebas obligatorias: los 3 perfiles esperados cambian de customer a provider; resto sin cambio; cero pérdida de admin/super_admin; cero owners huérfanos; cero diferencias en counts de requests/reservas/audit; no FK inválidas; contact RLS cerrado a anon; 0 anon execute en admin RPC; Home consulta 200. Ensayar con restricciones y roles efectivos `anon`, `authenticated` normal/admin/owner/super_admin y `service_role` solo en proceso servidor.

## 10. Assertions post-migración

Ejecutar contra remoto y guardar solo resultados agregados:

```sql
-- 1) No perfiles administrativos degradados; conteos contra baseline firmado.
select role::text, account_status::text, count(*) from public.profiles group by 1,2 order by 1,2;
-- 2) Ningún business sin profile/auth owner antes y después del cambio FK.
select count(*) from public.businesses b left join public.profiles p on p.id=b.owner_id where p.id is null;
select count(*) from public.businesses b left join auth.users u on u.id=b.owner_id where u.id is null;
-- 3) FK owner y acción de borrado esperadas.
select conname, pg_get_constraintdef(oid), convalidated from pg_constraint where conrelid='public.businesses'::regclass and conname='businesses_owner_id_fkey';
-- 4) Ninguna RPC admin SECURITY DEFINER ejecutable por anon (incluye grants heredados de PUBLIC).
select p.oid::regprocedure from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and p.prosecdef and p.proname like 'admin\_%' escape '\'
and has_function_privilege('anon',p.oid,'EXECUTE');
-- 5) Campos Home, tipos, defaults, NOT NULL, checks e índice.
select column_name,data_type,is_nullable,column_default from information_schema.columns
where table_schema='public' and table_name='businesses' and column_name in ('is_featured','accepts_requests','rating_avg','review_count');
-- 6) Contact object, RLS, policies and function are installed.
select to_regclass('public.contact_messages'), (select relrowsecurity from pg_class where oid='public.contact_messages'::regclass);
-- 7) Settings keys exist, no duplicate keys; retain before/after values.
select key,count(*) from public.system_settings where key in ('support_email','support_whatsapp','notify_new_business','notify_business_changes','notify_contact_message') group by key;
-- 8) Coherent row counts for historical tables, captured before migration.
select 'businesses',count(*) from public.businesses union all select 'requests',count(*) from public.service_requests
union all select 'lodging_bookings',count(*) from public.lodging_bookings union all select 'table_reservations',count(*) from public.gastronomy_table_reservations
union all select 'audit_logs',count(*) from public.audit_logs;
```

El query del item 4 debe devolver cero filas; repetirlo para todos los `SECURITY DEFINER`, incluidos nombres no `admin_*`, y revisar EXECUTE de authenticated. En item 6, `contact_messages` debe existir antes de castear `regclass`; validar policies/RLS además de `relrowsecurity`. Home PostgREST debe responder 200 y no 42703. Las cantidades esperadas de perfiles/businesses se comparan con snapshot baseline y fixtures, no con valores inventados en este documento.

## 11. Edge Functions (no deploy)

| Función | Auth/secretos | Dependencias | Punto futuro |
|---|---|---|---|
| `submit-contact` | Endpoint público del diseño; valida payload server-side. Entorno Supabase managed `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`; no inventariar/imprimir valores | `contact_messages`, trigger de notificación, settings destinatarios; la service key solo dentro de runtime Edge | Después de contacto table/RLS, audit/notification settings y smoke local; probar OPTIONS/CORS, payload inválido y duplicado. |
| `admin-user` | JWT requerido y role/status admin validado server-side; mismos env managed; secret service role solo Edge | Auth Admin API + profiles + audit/RPC admin; debe revisar separación SuperAdmin/tenant y último admin | Ãšltimo, después de RPCs/RLS hardening; probar normal/admin y denied requests con cuentas QA remotas. |

El repo no registra secretos custom remotos al auditarse y no hay Edge Functions desplegadas. El gateway local `verify_jwt=false` hace obligatorio que la función valide JWT internamente. No desplegar `notify-provider-review` (no tiene referencia en flujos actuales) sin justificación nueva. CORS debe permitir solo el origen productivo real y OPTIONS necesario; el remoto no se probó.

## 12. Rollback y aborto por bloque

No usar DROP de columnas/tablas ni revertir con pérdida de filas. La ruta primaria de recuperación es restaurar backup/PITR comprobado a un proyecto nuevo, verificar allí, cambiar tráfico solo con plan operativo separado; restore in-place requiere ventana y aprobación expresa. Dump lógico probado es alternativa para DB, no incluye objetos de Storage ni configuración Edge.

| Bloque propuesto | Precheck / postcheck | Abort si | Recuperación |
|---|---|---|---|
| A — backup | backup reciente y restore probado; counts/hash agregados, schema dump | sin copia restaurable o conteos cambian inesperadamente | no empezar; obtener backup/activar PITR según plan y repetir. |
| B — reconcile baseline owner/types | owners perfil/auth cero, catálogos confirmados, functions dependientes; después FK válida, Home fields y mismas filas | owner no tiene profile, conversión type no válida, lock/timeout, ninguna columna semántica ambigua | cancelar transacción si aún abierta; si migración completó, restaurar snapshot probado, no DROP manual. |
| C — roles/functions/gate | snapshot de roles, RPC callers/UI, fixture role matrix; después exactos 3 cambios aprobados, admin protections y session tests | affected count differs, admin/superadmin degraded, cualquier normal obtiene admin data o usuarios legítimos bloqueados | restauración backup; no UPDATE inverso global porque no distingue provider previo. |
| D — settings/contact/notifications/soft delete | snapshot keys/counts; después RLS/grants, contact test, notifications y soft-delete fixture | settings overwritten, RLS público, notificación duplicada, filas históricas eliminadas | deshabilitar endpoint/Edge y restaurar backup; no borrar mensajes de clientes. |
| E — hardening anon RPC | ACL antes/después + llamadas JWT normal/admin; después 0 anon/PUBLIC EXECUTE y admin UI sigue | función legítima usada anon o admin normal falla | corregir grants específicos en nueva migración; restore solo si impacto de app amplio. |
| F — Edge deploy | secrets presence, CORS, Auth, service key no expuesta; después smoke test | sin JWT admin, secret missing/leak, write erróneo o CORS abierto | redeploy versión previa/deshabilitar función desde control plane; preservar mensajes/datos. |
| G — smoke | monitoreo de errors HTTP/PostgREST 42703/RLS y flujos home/auth/contact/admin/provider | error funcional o seguridad | detener rollout y rollback operacional respaldado. |

## 13. Secuencia propuesta (no ejecutada)

1. **A — recuperar primero:** Dashboard confirma backup diario/PITR, descargar/cifrar dump de schema y tablas, restaurar copia a proyecto QA aislado. Sin esto, detener.
2. **B — snapshot y conciliación:** comparar snapshot completo de funciones/triggers/ACL/policies/types, actualizar plan. Acordar owner FK B o aceptar/documentar C. Preparar nueva migración idempotente compatible con baseline remoto, con `NOT VALID`/validación online si aplica. No alterar tipos text en lote.
3. **C — identidad/roles:** tener diseñadas/revisadas (sin aplicarlas fuera de orden) las migraciones nuevas de separación `super_admin`/admin tenant y de gate/transition guard. Aplicar en orden de timestamp 041200, 041210, 041220, 041230, 041240, 041250, 041300, 041310, 041320, 041330, 041340, 041350, 041400 y 041410; mantener tráfico de usuario deshabilitado desde antes de 041300 hasta finalizar todas las reconciliaciones posteriores a 050050. Rerun de conteo y assertions tras 041330; aceptar explícitamente solo 3 perfiles customer→provider. El historial seguirá reflejando las migraciones ejecutadas realmente.
4. **D — settings y contacto:** aplicar 050000, 050010, 050020, luego 050030. Ese orden es necesario: la tabla/trigger de contacto existe antes de reemplazar `notify_admins_on_contact_message` y las keys de preferencias; soft delete solo luego de resolver roles/FK. Verificar settings preexistentes y respetar `ON CONFLICT DO NOTHING`.
5. **E — cierre de esquema/permisos:** aplicar 050040 después de todas las RPC admin; 050050 para validar/reconciliar Home. A continuación, todavía sin tráfico, aplicar migraciones nuevas posteriores a 050050 en orden: compatibilidad de esquema/FK owner acordada; aislamiento `super_admin`/admin tenant y guardas RPC/policies; reemplazo del session gate y transition guard; ACL mínimo de tablas. Revalidar grants y `SECURITY DEFINER`.
6. **F — Edge Functions:** deploy solo `submit-contact` y `admin-user` después de aplicar/verificar sus tablas/RPC/secret names y ACL; verificar presencia sin imprimir valores, JWT/CORS y smoke con cuentas autorizadas.
7. **G — verificación:** assertions de sección 10, Home/login/contact/account/notificaciones/admin/settings/provider smoke; comparar counts/hash; guardar reporte de deploy. Mantener opción de rollback respaldado.

No enviar `supabase db push` al lote completo: cuando esta fase cierre, preparar un plan de comandos por bloques aprobados con preview `migration list --linked` y diff de cada bloque. No usar `migration repair`.

## 14. Estado de seguridad y recovery

- RPC `admin_*` anon: 12/12 confirmadas; 050040 las cubre en su predicate. Sin escritura remota.
- ACL de tablas: `anon` y `authenticated` tienen grants amplios (incluido TRUNCATE) en las 9 tablas revisadas; RLS filtra operaciones de fila pero no equivale a mínimo privilegio. Falta migración dedicada secuenciada tras un mapa de operaciones Data API.
- `SECURITY DEFINER`: search_path explícito `public, auth`; guards de admin internos. Remediar grants anon/PUBLIC y resolver el privilegio super_admin.
- RLS: remote activa en tablas revisadas; remote business policies incluyen lectura pública solo published y propietarios/admin, profile update own/admin, notifications own, settings admin read/update. Local agrega session gate restrictivo a todas las tablas y storage, un cambio demasiado amplio para aplicar sin adaptación.
- Backup/PITR: PITR API false, sin backups listados; backup diario del plan no verificado. No hay recovery confirmado.
- Sin operaciones remotas de escritura, sin datos eliminados/usuarios cambiados, sin secretos expuestos, sin commit/push.

## 15. Validación local de esta fase

Validación repetida en esta fase:

- `npx supabase db reset`: PASS, reconstrucción desde cero con las 51 migraciones locales.
- `dart format .`: 203 archivos, 0 cambiados.
- `flutter analyze`: PASS, sin issues.
- `flutter test`: PASS, 630/630.
- `scripts/check_text_encoding.ps1`: PASS, UTF-8 estructural OK.
- `git diff --check`: PASS; Git mostró advertencias CRLF/LF del working tree, sin errores whitespace.
- `flutter build web --release`: PASS.
- SQL transaccional `phase_3_21_security_flow.sql`, `phase_3_22_admin_contracts.sql`, `phase_3_25_2_local_integration.sql`: PASS vía `docker exec … psql -v ON_ERROR_STOP=1 -f …`; terminan en ROLLBACK.
- Deno tests: 2/2 PASS vía `npx -y deno test`.
- Edge Function type-check: PASS vía `npx -y deno check --node-modules-dir=none` en `submit-contact/index.ts` y `admin-user/index.ts`.
- `phase_3_25_4_home_contract.mjs`: PASS, HTTP 200, cero filas visibles.
- `phase_3_25_2_local_api.mjs`: PASS; contacto, RLS, admin, roles, suspensión, protección último admin, settings/WhatsApp manual, notificaciones, actividad y soft-delete.
- Consulta remota solo lectura confirmó 31 migraciones aplicadas/20 pendientes, 12 RPC admin anon, ACL amplia de tabla, distribución agregada de roles y estado de backups indicado arriba. Ninguna consulta remota modificó datos.

## 16. Decisión

**READY FOR REMOTE APPLY: NO.** Condiciones de cierre pendientes:

1. Confirmar backup diario disponible y restaurable o habilitar PITR/procedimiento lógico probado; ahora CLI informa PITR desactivado y cero backups listados.
2. Resolver por diseño y prueba la separación SuperAdmin SaaS/admin tenant; hoy no está separada en RPC/policies.
3. Crear migraciones de reemplazo para session gate y role transition guard, además de ACL mínimo de tablas; decidir owner FK con verificación de datos y restauración confirmada.
4. Simular secuencia completa sobre snapshot que preserve todas las diferencias remotas, ejecutar fixture role matrix y asserts BEFORE/AFTER.
5. Completar prueba de restore, Edge Functions y secuencia remota por bloque con cuentas de QA autorizadas.

Hasta entonces, no aplicar migraciones remotas ni Edge Functions.
