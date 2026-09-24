import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/20260923190000_context_chat_notifications.sql',
  ).readAsStringSync();

  test('defines contextual chat rpc surface', () {
    expect(migration, contains('get_or_create_context_conversation'));
    expect(migration, contains('send_message'));
    expect(migration, contains('mark_conversation_read'));
    expect(migration, contains('conversation_list'));
    expect(migration, contains('conversation_messages'));
    expect(migration, contains('unread_conversation_count'));
  });

  test('uses conversation members for RLS instead of open authenticated access',
      () {
    expect(migration,
        contains('create table if not exists public.conversation_members'));
    expect(migration, contains('public.user_can_access_conversation'));
    expect(migration, contains('conversation members read conversations'));
    expect(migration, contains('conversation members read messages'));
    expect(migration, isNot(contains('using (true)')));
    expect(migration, isNot(contains('to authenticated using (true)')));
  });

  test('adds notification list, unread state and deep links', () {
    expect(migration, contains('notification_list'));
    expect(migration, contains('mark_notification_read'));
    expect(migration, contains('mark_all_notifications_read'));
    expect(migration, contains('unread_notification_count'));
    expect(migration, contains('add column if not exists deep_link'));
    expect(migration, contains("'/messages/' || p_conversation_id::text"));
  });

  test('publishes messaging and notifications tables for realtime', () {
    expect(
        migration,
        contains(
            'alter publication supabase_realtime add table public.messages'));
    expect(
        migration,
        contains(
            'alter publication supabase_realtime add table public.conversations'));
    expect(
        migration,
        contains(
            'alter publication supabase_realtime add table public.conversation_members'));
    expect(
        migration,
        contains(
            'alter publication supabase_realtime add table public.notifications'));
  });

  test('accepting a quote creates or reuses the contextual conversation', () {
    expect(
        migration, contains('create or replace function public.accept_quote'));
    expect(
      migration,
      contains(
          "public.get_or_create_context_conversation(\n    'service_request'"),
    );
    expect(migration, contains("'quote_accepted'"));
  });
}
