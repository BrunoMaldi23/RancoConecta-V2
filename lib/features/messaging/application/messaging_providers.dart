import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/conversation.dart';
import '../data/messaging_repository.dart';

final conversationListProvider =
    FutureProvider<List<ConversationSummary>>((ref) async {
  final result =
      await ref.watch(messagingRepositoryProvider).listConversations();
  return result.when(
    success: (items) => items,
    failure: (failure) => throw failure,
  );
});

final conversationMessagesProvider =
    FutureProvider.family<List<ChatMessage>, String>(
        (ref, conversationId) async {
  final repository = ref.watch(messagingRepositoryProvider);
  final result = await repository.listMessages(conversationId);
  await repository.markRead(conversationId);

  return result.when(
    success: (items) => items,
    failure: (failure) => throw failure,
  );
});

final unreadMessagesCountProvider = FutureProvider<int>((ref) async {
  final result = await ref.watch(messagingRepositoryProvider).unreadCount();
  return result.when(
    success: (count) => count,
    failure: (_) => 0,
  );
});

final messagingRealtimeProvider = Provider<void>((ref) {
  final repository = ref.watch(messagingRepositoryProvider);
  final client = repository.client;

  if (client == null) {
    return;
  }

  final channel = client.channel('ranco-messaging-global')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'messages',
      callback: (_) {
        ref.invalidate(conversationListProvider);
        ref.invalidate(unreadMessagesCountProvider);
      },
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'conversation_members',
      callback: (_) {
        ref.invalidate(conversationListProvider);
        ref.invalidate(unreadMessagesCountProvider);
      },
    )
    ..subscribe();

  ref.onDispose(() {
    client.removeChannel(channel);
  });
});

final conversationRealtimeProvider =
    Provider.family<void, String>((ref, conversationId) {
  final repository = ref.watch(messagingRepositoryProvider);
  final client = repository.client;

  if (client == null) {
    return;
  }

  final channel = client.channel('ranco-conversation-$conversationId')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'conversation_id',
        value: conversationId,
      ),
      callback: (_) {
        ref.invalidate(conversationMessagesProvider(conversationId));
        ref.invalidate(conversationListProvider);
        ref.invalidate(unreadMessagesCountProvider);
      },
    )
    ..subscribe();

  ref.onDispose(() {
    client.removeChannel(channel);
  });
});
