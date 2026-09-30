# Supabase Review

Revisar:

- migraciones;
- RLS;
- RPC;
- Storage;
- permisos;
- índices;
- foreign keys;
- grants.

Toda migración debe ser segura, preferentemente aditiva y compatible con datos existentes.

No aprobar:

- `DROP` destructivo sin confirmación;
- tablas sin RLS;
- RPCs sin validación de auth u ownership;
- duplicación de usuarios, negocios, media o categorías;
- cambios de firma innecesarios.
