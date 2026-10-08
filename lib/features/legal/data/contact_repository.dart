import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

String _newContactIdempotencyKey() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex =
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}

class ContactRepository {
  const ContactRepository(this.client);

  final SupabaseClient? client;

  Future<Map<String, String>> channels() async {
    final supabase = client;
    if (supabase == null) return const {'email': '', 'whatsapp': ''};
    final value =
        await supabase.rpc<Map<String, dynamic>>('public_contact_channels');
    return {
      'email': value['email']?.toString() ?? '',
      'whatsapp': value['whatsapp']?.toString() ?? '',
    };
  }

  Future<void> send({
    required String name,
    required String email,
    required String subject,
    required String message,
  }) async {
    final supabase = client;
    if (supabase == null) throw StateError('Supabase no está configurado.');
    await supabase.functions.invoke(
      'submit-contact',
      headers: {'Idempotency-Key': _newContactIdempotencyKey()},
      body: {
        'name': name.trim(),
        'email': email.trim(),
        'subject': subject,
        'message': message.trim(),
      },
    );
  }
}
