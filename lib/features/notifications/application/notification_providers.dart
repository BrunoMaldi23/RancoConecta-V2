import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/app_notification.dart';
import '../../auth/application/auth_controller.dart';
import '../data/notification_repository.dart';

final notificationListProvider =
    FutureProvider<List<AppNotification>>((ref) async {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) return const [];
  final result = await ref.watch(notificationRepositoryProvider).list();
  return result.when(
    success: (items) => items,
    failure: (failure) => throw failure,
  );
});

final unreadNotificationsCountProvider = FutureProvider<int>((ref) async {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) return 0;
  final result = await ref.watch(notificationRepositoryProvider).unreadCount();
  return result.when(
    success: (count) => count,
    failure: (_) => 0,
  );
});

final notificationsRealtimeProvider = Provider<void>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return;
  final repository = ref.watch(notificationRepositoryProvider);
  final client = repository.client;

  if (client == null) {
    return;
  }

  final channel = client.channel('ranco-notifications')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'notifications',
      callback: (_) {
        ref.invalidate(notificationListProvider);
        ref.invalidate(unreadNotificationsCountProvider);
      },
    )
    ..subscribe();

  ref.onDispose(() {
    client.removeChannel(channel);
  });
});
