# Coding Standards

## Dart y Flutter

- Usar null safety.
- Preferir widgets pequeños y claros.
- Evitar lógica pesada en UI.
- Usar `const` cuando corresponda.
- Usar nombres claros.
- Eliminar código muerto.
- Mantener imports limpios.
- Seguir patrones existentes antes de crear abstracciones nuevas.

## Estado y datos

- Usar providers existentes cuando apliquen.
- Mantener acceso a datos en repositories.
- No acceder directamente a Supabase desde widgets.
- No duplicar reglas de negocio ya centralizadas.

## Limpieza

No dejar:

- TODO abandonados;
- prints temporales;
- archivos backup;
- código comentado antiguo;
- scripts de parche puntual;
- widgets sin referencia.

## Formato y texto

- Mantener UTF-8.
- Evitar mojibake.
- Ejecutar `dart format` sobre archivos Dart modificados.
