import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/data/supabase_auth_repository.dart';
import '../features/provider_dashboard/application/provider_context.dart';
import '../features/provider_dashboard/application/provider_dashboard_providers.dart';
import '../features/profile/application/profile_providers.dart';

/// Flujo único de cierre de sesión de la app.
///
/// 1. Termina la sesión en Supabase, la fuente de verdad de la sesión.
/// 2. Limpia el estado privado cacheado del usuario anterior.
/// 3. Deja [authStateProvider] en NO SESSION.
/// 4. Navega a `/sign-in` sin recargar ni refrescar la app.
///
/// El [ProviderContainer] se captura al inicio, con el widget todavía montado,
/// porque Supabase emite `signedOut` antes de terminar `signOut()`: mientras
/// corre ese await el router puede desmontar la pantalla y cualquier uso
/// posterior de `ref` lanzaría `StateError`.
Future<void> signOutAndGoToSignIn(
  BuildContext context,
  WidgetRef ref,
) async {
  final container = ProviderScope.containerOf(context, listen: false);

  // 1. Cierre de sesión real en Supabase.
  await ref.read(authRepositoryProvider).signOut();

  // 2. Estado privado del usuario anterior.
  container.invalidate(currentProfileProvider);
  container.invalidate(myProviderBusinessProvider);
  container.invalidate(myProviderBusinessesProvider);
  container.invalidate(activeProviderBusinessProvider);
  container.invalidate(providerContextProvider);
  container.read(activeProviderBusinessIdProvider.notifier).state = null;

  // 3. NO SESSION en el provider canónico de auth. El stream de Supabase ya
  //    emitió el cambio durante `signOut()`; solo se fuerza la reevaluación si
  //    el estado todavía no quedó resuelto, para que el router no siga viendo
  //    la sesión anterior al navegar.
  final auth = container.read(authStateProvider);
  if (auth.isLoading || auth.valueOrNull != null) {
    container.invalidate(authStateProvider);
    await container
        .read(authStateProvider.future)
        .catchError((Object _) => null);
  }

  // 4. Vuelve al login sin F5, reload ni delays artificiales.
  if (context.mounted) {
    // Si la acción salió desde el drawer abierto, se cierra con el mismo
    // mecanismo que _go antes de navegar (patrón ya usado en el proyecto).
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold != null &&
        (scaffold.isDrawerOpen || scaffold.isEndDrawerOpen)) {
      Navigator.of(context).maybePop();
    }
    context.go('/sign-in');
  }
}
