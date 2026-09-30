# Ranco Conecta Codex Instructions

Estas reglas aplican a cualquier trabajo futuro en Ranco Conecta 2.0.

Antes de modificar:

1. Revisar la arquitectura existente.
2. Buscar componentes, providers, repositorios y modelos reutilizables.
3. No duplicar lógica.
4. No crear archivos innecesarios.
5. Mantener UTF-8.
6. Mantener separación por capas.

Toda modificación debe ser:

- pequeña;
- validable;
- reversible.

Cuando corresponda, ejecutar:

- `dart format` sobre archivos modificados;
- `flutter analyze --no-pub`;
- `.\scripts\check_text_encoding.ps1`;
- `git diff --check`.

No avanzar si la validación deja errores introducidos por el cambio.
