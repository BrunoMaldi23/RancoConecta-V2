# Design System

Ranco Conecta uses Material 3 with a custom color scheme inspired by Lago Ranco, forest, water, clay, and community trust.

Core colors:

- Forest `#2F7353`
- Lake `#2D6F8F`
- Clay `#BF6842`
- Moss `#7A8B3A`
- Mist `#EAF3F0`

Tokens are centralized for spacing, radius, breakpoints, and animation durations in `lib/theme/ranco_tokens.dart`.

Screens should consume `ThemeData`, `ColorScheme`, and tokens rather than scattering hex values. Cards are reserved for bounded content or repeated items, not page-level wrappers.
