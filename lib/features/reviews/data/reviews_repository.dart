import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/supabase_auth_repository.dart';
import 'business_review.dart';

final reviewsRepositoryProvider = Provider<ReviewsRepository>((ref) {
  return ReviewsRepository(
    ref.watch(supabaseClientProvider),
  );
});

class ReviewsRepository {
  const ReviewsRepository(
    this._client,
  );

  final SupabaseClient? _client;

  static const _select = '''
id,
business_id,
user_id,
rating,
comment,
status,
created_at,
updated_at
''';

  Future<List<BusinessReview>> listPublished(
    String businessId,
  ) async {
    final client = _client;

    if (client == null) {
      return const [];
    }

    final rows = await client
        .from('reviews')
        .select(_select)
        .eq('business_id', businessId)
        .eq('status', 'published')
        .order(
          'created_at',
          ascending: false,
        );

    return rows
        .map(
          (row) => BusinessReview.fromJson(
            Map<String, dynamic>.from(row),
          ),
        )
        .toList();
  }

  Future<BusinessReview?> myReview(
    String businessId,
  ) async {
    final client = _client;
    final userId = client?.auth.currentUser?.id;

    if (client == null || userId == null) {
      return null;
    }

    final row = await client
        .from('reviews')
        .select(_select)
        .eq('business_id', businessId)
        .eq('user_id', userId)
        .maybeSingle();

    if (row == null) {
      return null;
    }

    return BusinessReview.fromJson(
      Map<String, dynamic>.from(row),
    );
  }

  Future<void> saveReview({
    required String businessId,
    required int rating,
    String? comment,
  }) async {
    final client = _client;
    final userId = client?.auth.currentUser?.id;

    if (client == null || userId == null) {
      throw StateError(
        'Debes ingresar para publicar una resena.',
      );
    }

    if (rating < 1 || rating > 5) {
      throw ArgumentError(
        'La valoracion debe estar entre 1 y 5.',
      );
    }

    final cleanComment = comment?.trim();

    await client.from('reviews').upsert(
      {
        'business_id': businessId,
        'user_id': userId,
        'rating': rating,
        'comment':
            cleanComment == null || cleanComment.isEmpty ? null : cleanComment,
        'status': 'published',
      },
      onConflict: 'business_id,user_id',
    );
  }

  Future<void> deleteReview(
    String reviewId,
  ) async {
    final client = _client;
    final userId = client?.auth.currentUser?.id;

    if (client == null || userId == null) {
      throw StateError(
        'Debes ingresar para eliminar una resena.',
      );
    }

    await client
        .from('reviews')
        .delete()
        .eq('id', reviewId)
        .eq('user_id', userId);
  }
}
