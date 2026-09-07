# Navigation

The app uses `go_router` with a `StatefulShellRoute`.

Sprint 0 routes:

- `/`
- `/explore`
- `/requests`
- `/saved`
- `/account`
- `/sign-in`
- `/sign-up`
- `/forgot-password`
- `/account/edit`
- `/business/:id`
- `/business/:id/request`
- `/requests/:id`

The main shell adapts from `NavigationBar` on compact screens to `NavigationRail` on wider layouts. Future desktop layouts can extend the same breakpoint tokens into a sidebar pattern.

Protected routes refresh from Supabase auth state changes through a small `GoRouterRefreshStream`, so session restore/sign-out can affect route access without manual session storage.
