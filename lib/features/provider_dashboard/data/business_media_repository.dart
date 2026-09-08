import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/supabase_auth_repository.dart';

final businessMediaRepositoryProvider =
    Provider<BusinessMediaRepository>((ref) {
  return BusinessMediaRepository(
    ref.watch(supabaseClientProvider),
  );
});

class ProviderMediaItem {
  const ProviderMediaItem({
    required this.id,
    required this.businessId,
    required this.mediaType,
    required this.storagePath,
    required this.sortOrder,
  });

  factory ProviderMediaItem.fromJson(
    Map<String, dynamic> json,
  ) {
    return ProviderMediaItem(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      mediaType: json['media_type'] as String? ?? 'gallery',
      storagePath: json['storage_path'] as String,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String businessId;
  final String mediaType;
  final String storagePath;
  final int sortOrder;

  bool get isCover => mediaType == 'cover';
}

class BusinessMediaRepository {
  const BusinessMediaRepository(
    this._client,
  );

  static const bucket = 'business-media';

  final SupabaseClient? _client;

  SupabaseClient get _requireClient {
    final client = _client;

    if (client == null) {
      throw StateError(
        'Supabase no esta configurado.',
      );
    }

    return client;
  }

  Future<List<ProviderMediaItem>> list(
    String businessId,
  ) async {
    final rows = await _requireClient
        .from('business_media')
        .select(
          'id,business_id,media_type,storage_path,sort_order',
        )
        .eq(
          'business_id',
          businessId,
        )
        .order(
          'sort_order',
          ascending: true,
        );

    return rows
        .map(
          (row) => ProviderMediaItem.fromJson(
            Map<String, dynamic>.from(row),
          ),
        )
        .toList();
  }

  String publicUrl(
    String path,
  ) {
    return _requireClient.storage.from(bucket).getPublicUrl(path);
  }

  Future<void> upload({
    required String businessId,
    required Uint8List bytes,
    required String extension,
  }) async {
    final client = _requireClient;
    final userId = client.auth.currentUser?.id;

    if (userId == null) {
      throw StateError(
        'Debes iniciar sesion.',
      );
    }

    final current = await list(
      businessId,
    );

    if (current.length >= 15) {
      throw StateError(
        'Puedes subir un maximo de 15 fotografias.',
      );
    }

    final safeExtension = extension.toLowerCase().replaceAll('.', '');

    final fileName = '${DateTime.now().microsecondsSinceEpoch}.$safeExtension';

    final storagePath = '$userId/$businessId/$fileName';

    await client.storage.from(bucket).uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(
            upsert: false,
            contentType: _contentType(
              safeExtension,
            ),
          ),
        );

    final mediaType = current.isEmpty ? 'cover' : 'gallery';

    try {
      await client.from('business_media').insert({
        'business_id': businessId,
        'media_type': mediaType,
        'storage_path': storagePath,
        'sort_order': current.length,
      });
    } catch (_) {
      await client.storage.from(bucket).remove([storagePath]);

      rethrow;
    }
  }

  Future<void> makeCover({
    required String businessId,
    required String mediaId,
  }) async {
    final client = _requireClient;

    final current = await list(
      businessId,
    );

    final selected = current
        .where(
          (item) => item.id == mediaId,
        )
        .firstOrNull;

    if (selected == null) {
      throw StateError(
        'No encontramos la fotografia.',
      );
    }

    for (final item in current) {
      await client.from('business_media').update({
        'media_type': item.id == mediaId ? 'cover' : 'gallery',
      }).eq(
        'id',
        item.id,
      );
    }
  }

  Future<void> delete(
    ProviderMediaItem item,
  ) async {
    final client = _requireClient;

    await client.from('business_media').delete().eq(
          'id',
          item.id,
        );

    await client.storage.from(bucket).remove([
      item.storagePath,
    ]);

    final remaining = await list(
      item.businessId,
    );

    if (remaining.isNotEmpty &&
        !remaining.any(
          (media) => media.isCover,
        )) {
      await makeCover(
        businessId: item.businessId,
        mediaId: remaining.first.id,
      );
    }

    for (var index = 0; index < remaining.length; index++) {
      await client.from('business_media').update({
        'sort_order': index,
      }).eq(
        'id',
        remaining[index].id,
      );
    }
  }

  static String _contentType(
    String extension,
  ) {
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'jpeg' => 'image/jpeg',
      'jpg' => 'image/jpeg',
      _ => 'image/jpeg',
    };
  }
}

extension _FirstWhereOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    if (isEmpty) {
      return null;
    }

    return first;
  }
}
