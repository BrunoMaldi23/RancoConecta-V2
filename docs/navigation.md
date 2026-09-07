# Navigation

The app uses `go_router` with a `StatefulShellRoute`.

Sprint 0 routes:

- `/`
- `/explore`
- `/requests`
- `/saved`
- `/account`
- `/sign-in`

The main shell adapts from `NavigationBar` on compact screens to `NavigationRail` on wider layouts. Future desktop layouts can extend the same breakpoint tokens into a sidebar pattern.
