import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/layout/ranco_responsive.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/ranco_app_bar.dart';
import '../../../core/widgets/ranco_error_state.dart';
import '../../../core/widgets/ranco_page_empty_state.dart';
import '../../../core/widgets/ranco_segmented_control.dart';
import '../../../core/widgets/ranco_skeleton.dart';
import '../../../shared/models/app_notification.dart';
import '../../../theme/ranco_colors.dart';
import '../../../theme/ranco_tokens.dart';
import '../application/notification_providers.dart';
import '../data/notification_repository.dart';

/// Categoría visible de una notificación, derivada de su `type` real
/// (FASE 3.25: solo presentación).
enum NotificationCategory { business, requests, account, system }

NotificationCategory notificationCategoryOf(String type) {
  final code = type.toLowerCase();
  if (code == 'contact_message') return NotificationCategory.system;
  if (code.contains('request') ||
      code.contains('booking') ||
      code.contains('reservation') ||
      code.contains('quote') ||
      code.contains('message')) {
    return NotificationCategory.requests;
  }
  if (code.startsWith('business') ||
      code.startsWith('provider') ||
      code.contains('review')) {
    return NotificationCategory.business;
  }
  if (code.contains('account') ||
      code.contains('role') ||
      code.contains('profile') ||
      code.contains('suspend')) {
    return NotificationCategory.account;
  }
  return NotificationCategory.system;
}

extension on NotificationCategory {
  String get label => switch (this) {
        NotificationCategory.business => 'Negocios',
        NotificationCategory.requests => 'Solicitudes',
        NotificationCategory.account => 'Cuenta',
        NotificationCategory.system => 'Sistema',
      };
}

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _unreadOnly = false;

  /// `null` = todas las categorías.
  NotificationCategory? _category;

  @override
  Widget build(BuildContext context) {
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
          const SizedBox(width: 8),
        ],
      ),
      body: notifications.when(
        data: (items) {
          if (items.isEmpty) {
            return const _EmptyNotifications();
          }
          final unread = items.where((item) => item.isUnread).length;
          final visible = [
            for (final item in items)
              if ((!_unreadOnly || item.isUnread) &&
                  (_category == null ||
                      notificationCategoryOf(item.type) == _category))
                item,
          ];
          final groups = groupNotificationsByDay(visible, DateTime.now());

          return RancoContentContainer(
            width: RancoContainerWidth.form,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(0, 16, 0, 40),
              children: [
                _Header(total: items.length, unread: unread),
                const SizedBox(height: 16),
                _Filters(
                  unreadOnly: _unreadOnly,
                  unread: unread,
                  category: _category,
                  onUnreadOnly: (value) => setState(() => _unreadOnly = value),
                  onCategory: (value) => setState(() => _category = value),
                ),
                const SizedBox(height: 6),
                AnimatedSwitcher(
                  duration: RancoDurations.quick,
                  child: visible.isEmpty
                      ? _FilteredEmpty(
                          key: const ValueKey('filtered-empty'),
                          unreadOnly: _unreadOnly,
                          onReset: () => setState(() {
                            _unreadOnly = false;
                            _category = null;
                          }),
                        )
                      : Column(
                          key: ValueKey('list-$_unreadOnly-$_category'),
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final (label, groupItems) in groups) ...[
                              _GroupHeader(
                                  label: label, count: groupItems.length),
                              for (final item in groupItems)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _NotificationTile(
                                    notification: item,
                                    onTap: () =>
                                        _openNotification(context, ref, item),
                                  ),
                                ),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          );
        },
        // Esqueleto con la misma altura que las filas: sin salto al cargar.
        loading: () => RancoContentContainer(
          width: RancoContainerWidth.form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(0, 46, 0, 32),
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (var i = 0; i < 4; i++)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: RancoSkeleton(height: 76),
                ),
            ],
          ),
        ),
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
      failure: (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No pudimos marcar tus notificaciones.'),
          ));
        }
      },
    );
  }

  Future<void> _openNotification(
    BuildContext context,
    WidgetRef ref,
    AppNotification notification,
  ) async {
    final result = await ref
        .read(notificationRepositoryProvider)
        .markRead(notification.id);
    if (result.when(success: (_) => false, failure: (_) => true)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No pudimos marcar la notificación como leída.'),
        ));
      }
      return;
    }
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

/// Agrupa por día local: Hoy, Ayer y Anteriores.
List<(String, List<AppNotification>)> groupNotificationsByDay(
  List<AppNotification> items,
  DateTime now,
) {
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final buckets = <String, List<AppNotification>>{
    'Hoy': [],
    'Ayer': [],
    'Anteriores': [],
  };
  for (final item in items) {
    final local = item.createdAt.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    final key = !day.isBefore(today)
        ? 'Hoy'
        : !day.isBefore(yesterday)
            ? 'Ayer'
            : 'Anteriores';
    buckets[key]!.add(item);
  }
  return [
    for (final entry in buckets.entries)
      if (entry.value.isNotEmpty) (entry.key, entry.value),
  ];
}

class _Header extends StatelessWidget {
  const _Header({required this.total, required this.unread});

  final int total;
  final int unread;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Text(
            'Revisa novedades sobre tu cuenta y actividad.',
            style: TextStyle(
              color: RancoColors.textSecondary,
              fontSize: 14.5,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          unread == 0
              ? '$total en total'
              : '$unread sin leer · $total en total',
          style: const TextStyle(
            color: RancoColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// [Todas] [Sin leer] + categoría. En angosto, la categoría pasa a una fila
/// propia con desplazamiento horizontal.
class _Filters extends StatelessWidget {
  const _Filters({
    required this.unreadOnly,
    required this.unread,
    required this.category,
    required this.onUnreadOnly,
    required this.onCategory,
  });

  final bool unreadOnly;
  final int unread;
  final NotificationCategory? category;
  final ValueChanged<bool> onUnreadOnly;
  final ValueChanged<NotificationCategory?> onCategory;

  @override
  Widget build(BuildContext context) {
    final readFilter = RancoSegmentedControl<bool>(
      segments: [
        const RancoSegment(value: false, label: 'Todas'),
        RancoSegment(value: true, label: 'Sin leer', count: unread),
      ],
      selected: unreadOnly,
      onChanged: onUnreadOnly,
    );
    final categories = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (value, label) in [
            (null, 'Todos'),
            for (final item in NotificationCategory.values) (item, item.label),
          ]) ...[
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                selected: category == value,
                showCheckmark: false,
                label: Text(label),
                onSelected: (_) => onCategory(value),
              ),
            ),
          ],
        ],
      ),
    );
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 680) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [readFilter, const SizedBox(height: 10), categories],
        );
      }
      return Row(
        children: [
          readFilter,
          const SizedBox(width: 16),
          Expanded(child: categories),
        ],
      );
    });
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 10),
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: RancoColors.textSecondary,
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            letterSpacing: .8,
          ),
        ),
      ),
    );
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
    final created = notification.createdAt.toLocal();
    final now = DateTime.now();
    final isToday = created.year == now.year &&
        created.month == now.month &&
        created.day == now.day;
    final date = isToday
        ? DateFormat.Hm('es').format(created)
        : DateFormat.MMMd('es').format(created);
    final unread = notification.isUnread;
    final category = notificationCategoryOf(notification.type);
    final hasLink = notification.deepLink?.trim().isNotEmpty == true;

    return Semantics(
      label: unread ? 'No leída' : null,
      child: Material(
        color: unread ? const Color(0xFFF3FAF6) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
            decoration: BoxDecoration(
              border: Border.all(
                color: unread
                    ? RancoColors.forest.withValues(alpha: 0.22)
                    : const Color(0xFFE1EAE5),
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: unread
                        ? const Color(0xFFDDEFE6)
                        : const Color(0xFFF0F4F2),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    _iconFor(notification.type, category),
                    color: unread ? RancoColors.forest : RancoColors.slate,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (unread) ...[
                            const _UnreadDot(),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              notification.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: RancoColors.textPrimary,
                                fontSize: 14.5,
                                fontWeight:
                                    unread ? FontWeight.w800 : FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            date,
                            style: const TextStyle(
                              color: RancoColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        notification.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: RancoColors.textSecondary,
                          fontSize: 13.5,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        category.label,
                        style: const TextStyle(
                          color: Color(0xFF7D8C85),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                // "Ver" solo cuando la notificación lleva a algún lugar.
                SizedBox(
                  width: 24,
                  child: hasLink
                      ? const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Icon(
                            Icons.chevron_right_rounded,
                            size: 22,
                            color: RancoColors.textSecondary,
                            semanticLabel: 'Ver',
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconFor(String type, NotificationCategory category) {
    final code = type.toLowerCase();
    if (code.contains('message')) return Icons.chat_bubble_outline_rounded;
    if (code.contains('quote')) return Icons.request_quote_outlined;
    if (code.contains('lodging') || code.contains('booking')) {
      return Icons.bed_outlined;
    }
    if (code.contains('table')) return Icons.restaurant_outlined;
    return switch (category) {
      NotificationCategory.requests => Icons.assignment_outlined,
      NotificationCategory.business => Icons.storefront_outlined,
      NotificationCategory.account => Icons.person_outline_rounded,
      NotificationCategory.system => Icons.notifications_none_rounded,
    };
  }
}

class _UnreadDot extends StatelessWidget {
  const _UnreadDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: RancoColors.forest,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _FilteredEmpty extends StatelessWidget {
  const _FilteredEmpty({
    required this.unreadOnly,
    required this.onReset,
    super.key,
  });

  final bool unreadOnly;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE1EAE5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.done_all_rounded, color: RancoColors.forest),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              unreadOnly
                  ? 'Estás al día: no hay notificaciones sin leer.'
                  : 'No hay notificaciones en esta categoría.',
              style: const TextStyle(
                color: RancoColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(onPressed: onReset, child: const Text('Ver todas')),
        ],
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
        title: 'No tienes notificaciones pendientes.',
        message: 'Cuando haya novedades sobre solicitudes o tu cuenta '
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
