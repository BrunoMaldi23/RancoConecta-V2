# Security Review

Revisar:

- exposición de datos;
- permisos;
- auth;
- RLS;
- Supabase Storage;
- buckets públicos;
- variables sensibles;
- ownership de negocios;
- grants de RPC.

No aprobar:

- secretos en el repositorio;
- lectura pública de datos privados;
- escritura sin ownership;
- policies demasiado amplias;
- storage público sin necesidad de producto.
