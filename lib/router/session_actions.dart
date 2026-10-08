import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/result/result.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/data/supabase_auth_repository.dart';
import '../features/admin/application/admin_providers.dart';
import '../features/favorites/application/favorite_providers.dart';
import '../features/messaging/application/messaging_providers.dart';
import '../features/notifications/application/notification_providers.dart';
import '../features/service_requests/application/service_request_providers.dart';
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
Future<void> signOutAndGoToSignIn(BuildContext context, WidgetRef ref,
    {String destination = '/sign-in'}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  if (container.read(signingOutProvider)) return;
  final repository = ref.read(authRepositoryProvider);
  container.read(signingOutProvider.notifier).state = true;

  // 1. Cierre de sesión real en Supabase.
  final result = await repository.signOut();
  if (result is Failure<void>) {
    container.read(signingOutProvider.notifier).state = false;
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo cerrar sesión.')),
      );
    }
    return;
  }

  // 2. Estado privado del usuario anterior.
  container.invalidate(currentProfileProvider);
  container.invalidate(myProviderBusinessProvider);
  container.invalidate(myProviderBusinessesProvider);
  container.invalidate(activeProviderBusinessProvider);
  container.invalidate(lodgingDetailsProvider);
  container.invalidate(providerBusinessMediaProvider);
  container.invalidate(serviceBusinessManagementProvider);
  container.invalidate(lodgingCalendarMonthProvider);
  container.invalidate(providerContextProvider);
  container.invalidate(favoriteBusinessesProvider);
  container.invalidate(favoriteIdsProvider);
  container.invalidate(isFavoriteProvider);
  container.invalidate(myCustomerActivityProvider);
  container.invalidate(myRequestsProvider);
  container.invalidate(requestDetailProvider);
  container.invalidate(requestQuotesProvider);
  container.invalidate(requestAttachmentsProvider);
  container.invalidate(providerRequestQueueProvider);
  container.invalidate(notificationListProvider);
  container.invalidate(unreadNotificationsCountProvider);
  container.invalidate(conversationListProvider);
  container.invalidate(conversationMessagesProvider);
  container.invalidate(unreadMessagesCountProvider);
  container.invalidate(adminUsersProvider);
  container.invalidate(adminCategoriesProvider);
  container.invalidate(adminBusinessReviewPageProvider);
  container.invalidate(adminBusinessReviewDetailProvider);
  container.invalidate(adminReviewStatsProvider);
  container.invalidate(adminAnalyticsSummaryProvider);
  container.invalidate(adminWhatsAppSettingsProvider);
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

  container.read(signingOutProvider.notifier).state = false;

  // 4. Vuelve al login sin F5, reload ni delays artificiales.
  if (context.mounted) {
    // Si la acción salió desde el drawer abierto, se cierra con el mismo
    // mecanismo que _go antes de navegar (patrón ya usado en el proyecto).
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold != null &&
        (scaffold.isDrawerOpen || scaffold.isEndDrawerOpen)) {
      Navigator.of(context).maybePop();
    }
    context.go(destination);
  }
}
