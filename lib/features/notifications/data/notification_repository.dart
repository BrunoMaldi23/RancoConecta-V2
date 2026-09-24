import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failure_mapper.dart';
import '../../../core/result/result.dart';
import '../../../features/auth/data/supabase_auth_repository.dart';
import '../../../shared/models/app_notification.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.watch(supabaseClientProvider));
});

class NotificationRepository {
  const NotificationRepository(this._client);

  final SupabaseClient? _client;

  SupabaseClient? get client => _client;

  Future<Result<List<AppNotification>>> list() async {
    final client = _client;

    if (client == null) {
      return const Success([]);
    }

    try {
      final rows = await client.rpc<List<dynamic>>('notification_list');
      return Success(
        rows
            .whereType<Map>()
            .map((row) => AppNotificationDto.fromJson(
                  Map<String, dynamic>.from(row),
                ))
            .toList(),
      );
    } catch (error) {
      return Failure(
        mapSupabaseFailure(
          error,
          fallbackMessage: 'No pudimos cargar tus notificaciones.',
        ),
      );
    }
  }

  Future<Result<int>> unreadCount() async {
    final client = _client;

    if (client == null) {
      return const Success(0);
    }

    try {
      final count = await client.rpc<int>('unread_notification_count');
      return Success(count);
    } catch (error) {
      return Failure(
        mapSupabaseFailure(
          error,
          fallbackMessage: 'No pudimos leer notificaciones pendientes.',
        ),
      );
    }
  }

  Future<Result<void>> markRead(String notificationId) async {
    final client = _client;

    if (client == null) {
      return const Success(null);
    }

    try {
      await client.rpc<void>(
        'mark_notification_read',
        params: {'p_notification_id': notificationId},
      );
      return const Success(null);
    } catch (error) {
      return Failure(
        mapSupabaseFailure(
          error,
          fallbackMessage: 'No pudimos marcar la notificación como leída.',
        ),
      );
    }
  }

  Future<Result<void>> markAllRead() async {
    final client = _client;

    if (client == null) {
      return const Success(null);
    }

    try {
      await client.rpc<void>('mark_all_notifications_read');
      return const Success(null);
    } catch (error) {
      return Failure(
        mapSupabaseFailure(
          error,
          fallbackMessage: 'No pudimos marcar tus notificaciones.',
        ),
      );
    }
  }
}

class AppNotificationDto {
  const AppNotificationDto._();

  static AppNotification fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'notification',
      title: json['title'] as String? ?? 'Notificación',
      body: json['body'] as String? ?? '',
      entityType: json['entity_type'] as String?,
      entityId: json['entity_id'] as String?,
      deepLink: json['deep_link'] as String?,
      readAt: DateTime.tryParse(json['read_at']?.toString() ?? ''),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
