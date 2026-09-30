# Arquitectura

## Stack

- Frontend: Flutter / Dart.
- Backend: Supabase.
- Base de datos: PostgreSQL.
- Storage: Supabase Storage.

## Flutter

La aplicación usa una arquitectura por features.

Estructura esperada:

```text
lib/features/<feature>/
  data/
  application/
  presentation/
```

Responsabilidades:

- `data`: repositories, datasources y modelos de intercambio.
- `application`: providers y lógica de aplicación.
- `presentation`: pantallas y widgets.

Reglas:

- No poner acceso directo a Supabase dentro de widgets.
- No crear soluciones paralelas si existe un patrón del proyecto.
- Reutilizar modelos, repositories, providers y widgets existentes.
- No mover archivos masivamente si no aporta claridad real.
- Mantener las verticales separadas cuando sus reglas de negocio sean distintas.
