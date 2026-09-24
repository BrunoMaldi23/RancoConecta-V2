import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_mapper.dart';
import '../../../core/result/result.dart';
import '../../../features/auth/data/supabase_auth_repository.dart';
import '../../../shared/models/request_attachment.dart';

final requestAttachmentRepositoryProvider =
    Provider<RequestAttachmentRepository>((ref) {
  return RequestAttachmentRepository(ref.watch(supabaseClientProvider));
});

class PendingRequestAttachment {
  const PendingRequestAttachment({
    required this.fileName,
    required this.mimeType,
    required this.bytes,
  });

  final String fileName;
  final String mimeType;
  final Uint8List bytes;

  int get sizeBytes => bytes.length;
}

class RequestAttachmentRepository {
  const RequestAttachmentRepository(this._client);

  static const bucket = 'request-attachments';
  static const maxBytes = 10 * 1024 * 1024;

  final SupabaseClient? _client;

  Future<Result<List<RequestAttachment>>> list(String requestId) async {
    final client = _client;

    if (client == null) {
      return const Success([]);
    }

    try {
      final rows = await client
          .from('request_attachments')
          .select(
            'id,request_id,storage_path,file_name,mime_type,size_bytes,created_at',
          )
          .eq('request_id', requestId)
          .order('created_at', ascending: true);

      return Success(
        rows.map((row) => _fromJson(Map<String, dynamic>.from(row))).toList(),
      );
    } catch (error) {
      return Failure(
        mapSupabaseFailure(
          error,
          fallbackMessage: 'No pudimos cargar los adjuntos.',
        ),
      );
    }
  }

  Future<Result<RequestAttachment>> upload({
    required String requestId,
    required PendingRequestAttachment attachment,
  }) async {
    final client = _client;
    final userId = client?.auth.currentUser?.id;

    if (client == null || userId == null) {
      return const Failure(
        AppFailure(
          type: AppFailureType.auth,
          message: 'Debes ingresar para subir adjuntos.',
        ),
      );
    }

    if (!_allowedMimeTypes.contains(attachment.mimeType)) {
      return const Failure(
        AppFailure(
          type: AppFailureType.validation,
          message: 'Formato no permitido.',
        ),
      );
    }

    if (attachment.sizeBytes <= 0 || attachment.sizeBytes > maxBytes) {
      return const Failure(
        AppFailure(
          type: AppFailureType.validation,
          message: 'El archivo supera el tamaño permitido.',
        ),
      );
    }

    final safeName = attachment.fileName.replaceAll(
      RegExp(r'[^a-zA-Z0-9._-]'),
      '_',
    );
    final storagePath =
        'requests/$requestId/${DateTime.now().microsecondsSinceEpoch}-$safeName';

    try {
      await client.storage.from(bucket).uploadBinary(
            storagePath,
            attachment.bytes,
            fileOptions: FileOptions(
              upsert: false,
              contentType: attachment.mimeType,
            ),
          );

      try {
        final row = await client
            .from('request_attachments')
            .insert({
              'request_id': requestId,
              'uploader_user_id': userId,
              'storage_path': storagePath,
              'file_name': attachment.fileName,
              'mime_type': attachment.mimeType,
              'size_bytes': attachment.sizeBytes,
            })
            .select()
            .single();

        return Success(_fromJson(Map<String, dynamic>.from(row)));
      } catch (error) {
        await client.storage.from(bucket).remove([storagePath]);
        rethrow;
      }
    } catch (error) {
      return Failure(
        mapSupabaseFailure(
          error,
          fallbackMessage: 'No pudimos subir el adjunto.',
        ),
      );
    }
  }

  Future<Result<Uri>> signedUrl(RequestAttachment attachment) async {
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
      final url = await client.storage.from(bucket).createSignedUrl(
            attachment.storagePath,
            60 * 10,
          );

      return Success(Uri.parse(url));
    } catch (error) {
      return Failure(
        mapSupabaseFailure(
          error,
          fallbackMessage: 'No pudimos abrir el adjunto.',
        ),
      );
    }
  }

  static const _allowedMimeTypes = {
    'image/jpeg',
    'image/png',
    'image/webp',
    'application/pdf',
  };

  static RequestAttachment fromJsonForTest(Map<String, dynamic> json) {
    return _fromJson(json);
  }
}

RequestAttachment _fromJson(Map<String, dynamic> json) {
  return RequestAttachment(
    id: json['id'] as String,
    requestId: json['request_id'] as String,
    storagePath: json['storage_path'] as String,
    fileName: json['file_name'] as String? ?? 'Adjunto',
    mimeType: json['mime_type'] as String? ?? 'application/octet-stream',
    sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}
