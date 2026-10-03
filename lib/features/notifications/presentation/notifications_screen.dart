import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/layout/ranco_responsive.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/ranco_app_bar.dart';
import '../../../core/widgets/ranco_error_state.dart';
import '../../../core/widgets/ranco_page_empty_state.dart';
import '../../../shared/models/app_notification.dart';
import '../../../theme/ranco_colors.dart';
import '../application/notification_providers.dart';
import '../data/notification_repository.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(notificationsRealtimeProvider);

    final notifications = ref.watch(notificationListProvider);
    // "Leer todo" solo cuando hay algo sin leer.
    final hasUnread =
        notifications.valueOrNull?.any((item) => item.isUnread) ?? false;

    return Scaffold(
      backgroundColor: RancoColors.canvas,
      appBar: RancoAppBar(
        title: 'Notificaciones',
        fallbackRoute: '/account',
        actions: [
          if (hasUnread)
            TextButton(
              onPressed: () => _markAllRead(ref),
              child: const Text('Marcar todo como leído'),
            ),
        ],
      ),
      body: notifications.when(
        data: (items) {
          if (items.isEmpty) {
            return const _EmptyNotifications();
          }

          return RancoContentContainer(
            width: RancoContainerWidth.form,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 18),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = items[index];
                return _NotificationTile(
                  notification: item,
                  onTap: () => _openNotification(context, ref, item),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => RancoErrorState(
          message: _failureMessage(error),
          onRetry: () => ref.invalidate(notificationListProvider),
        ),
      ),
    );
  }

  Future<void> _markAllRead(WidgetRef ref) async {
    final result = await ref.read(notificationRepositoryProvider).markAllRead();
    result.when(
      success: (_) {
        ref.invalidate(notificationListProvider);
        ref.invalidate(unreadNotificationsCountProvider);
      },
      failure: (_) {},
    );
  }

  Future<void> _openNotification(
    BuildContext context,
    WidgetRef ref,
    AppNotification notification,
  ) async {
    await ref.read(notificationRepositoryProvider).markRead(notification.id);
    ref.invalidate(notificationListProvider);
    ref.invalidate(unreadNotificationsCountProvider);

    if (!context.mounted) {
      return;
    }

    final deepLink = notification.deepLink;
    if (deepLink == null || deepLink.trim().isEmpty) {
      return;
    }

    context.go(deepLink);
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat.MMMd('es').format(notification.createdAt);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(
              color: notification.isUnread
                  ? RancoColors.forest.withValues(alpha: 0.28)
                  : const Color(0xFFD4E2DC),
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5F1EC),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  _iconFor(notification.type),
                  color: RancoColors.forest,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              color: RancoColors.textPrimary,
                              fontWeight: notification.isUnread
                                  ? FontWeight.w900
                                  : FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          date,
                          style: const TextStyle(
                            color: RancoColors.textSecondary,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      notification.body,
                      style: const TextStyle(
                        color: RancoColors.textSecondary,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (notification.isUnread) ...[
                const SizedBox(width: 8),
                const _UnreadDot(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(String type) {
    return switch (type) {
      'new_message' => Icons.chat_bubble_outline_rounded,
      'quote_received' || 'quote_accepted' => Icons.request_quote_outlined,
      'service_request_created' => Icons.assignment_outlined,
      'booking_created' || 'booking_status_changed' => Icons.bed_outlined,
      _ => Icons.notifications_none_rounded,
    };
  }
}

class _UnreadDot extends StatelessWidget {
  const _UnreadDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      margin: const EdgeInsets.only(top: 6),
      decoration: const BoxDecoration(
        color: RancoColors.forest,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      child: RancoPageEmptyState(
        icon: Icons.notifications_none_rounded,
        title: 'No tienes notificaciones',
        message: 'Cuando haya novedades sobre tus solicitudes o tu cuenta '
            'aparecerán aquí.',
      ),
    );
  }
}

String _failureMessage(Object error) {
  if (error is AppFailure) {
    return error.message;
  }
  return 'No pudimos cargar las notificaciones.';
}
