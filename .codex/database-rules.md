# Database Rules

Supabase y PostgreSQL deben evolucionar de forma segura.

Siempre:

- usar migraciones aditivas cuando sea posible;
- no borrar datos sin confirmación explícita;
- evitar `DROP` destructivo;
- mantener RLS obligatorio en tablas expuestas;
- validar ownership y permisos de prestador;
- preservar compatibilidad con llamadas actuales salvo decisión explícita.

Antes de crear tablas:

- revisar si existe un modelo reutilizable;
- revisar si una tabla actual cubre el caso;
- evitar duplicar usuarios, negocios, media o categorías.

Toda tabla nueva debe revisar:

- primary key;
- foreign keys;
- índices;
- timestamps;
- triggers de `updated_at` si corresponde;
- políticas RLS;
- grants mínimos necesarios.

RPCs:

- validar autenticación;
- validar ownership;
- mantener firmas estables cuando existan clientes usando la función;
- devolver errores claros;
- no saltarse RLS sin una razón explícita y documentada.
