import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_mapper.dart';
import '../../../core/result/result.dart';
import '../../../features/auth/data/supabase_auth_repository.dart';
import '../../../shared/models/conversation.dart';

final messagingRepositoryProvider = Provider<MessagingRepository>((ref) {
  return MessagingRepository(ref.watch(supabaseClientProvider));
});

class MessagingRepository {
  const MessagingRepository(this._client);

  final SupabaseClient? _client;

  SupabaseClient? get client => _client;

  Future<Result<List<ConversationSummary>>> listConversations() async {
    final client = _client;

    if (client == null) {
      return const Success([]);
    }

    try {
      final rows = await client.rpc<List<dynamic>>('conversation_list');
      return Success(
        rows
            .whereType<Map>()
            .map((row) => ConversationSummaryDto.fromJson(
                  Map<String, dynamic>.from(row),
                ))
            .toList(),
      );
    } catch (error) {
      return Failure(
        mapSupabaseFailure(
          error,
          fallbackMessage: 'No pudimos cargar tus mensajes.',
        ),
      );
    }
  }

  Future<Result<List<ChatMessage>>> listMessages(String conversationId) async {
    final client = _client;

    if (client == null) {
      return const Success([]);
    }

    try {
      final rows = await client.rpc<List<dynamic>>(
        'conversation_messages',
        params: {
          'p_conversation_id': conversationId,
          'p_limit': 80,
          'p_before': null,
        },
      );

      return Success(
        rows
            .whereType<Map>()
            .map((row) => ChatMessageDto.fromJson(
                  Map<String, dynamic>.from(row),
                ))
            .toList()
            .reversed
            .toList(),
      );
    } catch (error) {
      return Failure(
        mapSupabaseFailure(
          error,
          fallbackMessage: 'No pudimos cargar la conversación.',
        ),
      );
    }
  }

  Future<Result<String>> getOrCreateConversation({
    required String contextType,
    required String contextId,
  }) async {
    final client = _client;

    if (client == null) {
      return const Failure(
        AppFailure(
          type: AppFailureType.offline,
          message: 'Supabase no está configurado.',
        ),
      );
    }

    try {
      final id = await client.rpc<String>(
        'get_or_create_context_conversation',
        params: {
          'p_context_type': contextType,
          'p_context_id': contextId,
        },
      );
      return Success(id);
    } catch (error) {
      return Failure(
        mapSupabaseFailure(
          error,
          fallbackMessage: 'No pudimos abrir el chat.',
        ),
      );
    }
  }

  Future<Result<ChatMessage>> sendMessage({
    required String conversationId,
    required String body,
  }) async {
    final client = _client;

    if (client == null) {
      return const Failure(
        AppFailure(
          type: AppFailureType.offline,
          message: 'Supabase no está configurado.',
        ),
      );
    }

    try {
      final row = await client.rpc<Map<String, dynamic>>(
        'send_message',
        params: {
          'p_conversation_id': conversationId,
          'p_body': body.trim(),
        },
      );

      return Success(
        ChatMessageDto.fromMessageRow(row),
      );
    } catch (error) {
      return Failure(
        mapSupabaseFailure(
          error,
          fallbackMessage: 'No pudimos enviar el mensaje.',
        ),
      );
    }
  }

  Future<Result<void>> markRead(String conversationId) async {
    final client = _client;

    if (client == null) {
      return const Success(null);
    }

    try {
      await client.rpc<void>(
        'mark_conversation_read',
        params: {'p_conversation_id': conversationId},
      );
      return const Success(null);
    } catch (error) {
      return Failure(
        mapSupabaseFailure(
          error,
          fallbackMessage: 'No pudimos marcar la conversación como leída.',
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
      final count = await client.rpc<int>('unread_conversation_count');
      return Success(count);
    } catch (error) {
      return Failure(
        mapSupabaseFailure(
          error,
          fallbackMessage: 'No pudimos leer mensajes pendientes.',
        ),
      );
    }
  }
}

class ConversationSummaryDto {
  const ConversationSummaryDto._();

  static ConversationSummary fromJson(Map<String, dynamic> json) {
    return ConversationSummary(
      id: json['id'] as String,
      contextType: json['context_type'] as String? ?? 'service_request',
      contextId: json['context_id'] as String? ?? '',
      requestId: json['request_id'] as String?,
      title: json['title'] as String? ?? 'Conversación',
      preview: json['preview'] as String? ?? 'Sin mensajes todavía',
      lastMessageAt: DateTime.parse(
        json['last_message_at'] as String? ??
            DateTime.fromMillisecondsSinceEpoch(0).toIso8601String(),
      ),
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class ChatMessageDto {
  const ChatMessageDto._();

  static ChatMessage fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      senderName: json['sender_name'] as String? ?? 'Usuario',
      messageType: json['message_type'] as String? ?? 'text',
      body: json['body'] as String?,
      attachmentPath: json['attachment_path'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      isMine: json['is_mine'] as bool? ?? false,
    );
  }

  static ChatMessage fromMessageRow(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      senderName: 'Tú',
      messageType: json['message_type'] as String? ?? 'text',
      body: json['text'] as String?,
      attachmentPath: json['attachment_path'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      isMine: true,
    );
  }
}
