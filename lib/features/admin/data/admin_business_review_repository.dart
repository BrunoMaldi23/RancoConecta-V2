import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_mapper.dart';
import '../../../core/result/result.dart';
import '../../../features/auth/data/supabase_auth_repository.dart';
import '../../../shared/models/business.dart';

final adminBusinessReviewRepositoryProvider =
    Provider<AdminBusinessReviewRepository>((ref) {
  return AdminBusinessReviewRepository(
    ref.watch(supabaseClientProvider),
  );
});

class AdminBusinessReviewSummary {
  const AdminBusinessReviewSummary({
    required this.id,
    required this.name,
    required this.businessType,
    required this.publicationStatus,
    required this.verificationStatus,
    required this.categoryName,
    required this.ownerName,
    required this.ownerEmail,
    required this.submittedAt,
    required this.createdAt,
    required this.totalCount,
  });

  factory AdminBusinessReviewSummary.fromJson(Map<String, dynamic> json) {
    return AdminBusinessReviewSummary(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Negocio',
      businessType: BusinessType.parseOrDefault(
        json['business_type'] as String?,
      ),
      publicationStatus: BusinessPublicationStatus.parseOrDefault(
        json['publication_status'] as String?,
      ),
      verificationStatus: json['verification_status'] as String? ?? '',
      categoryName: json['category_name'] as String?,
      ownerName: json['owner_name'] as String?,
      ownerEmail: json['owner_email'] as String?,
      submittedAt: DateTime.tryParse(json['submitted_at']?.toString() ?? ''),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      totalCount: (json['total_count'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String name;
  final BusinessType businessType;
  final BusinessPublicationStatus publicationStatus;
  final String verificationStatus;
  final String? categoryName;
  final String? ownerName;
  final String? ownerEmail;
  final DateTime? submittedAt;
  final DateTime? createdAt;
  final int totalCount;
}

class AdminBusinessReviewDetail {
  const AdminBusinessReviewDetail({
    required this.business,
    required this.category,
    required this.owner,
    required this.coverage,
    required this.services,
    required this.lodgingDetails,
    required this.media,
    required this.requirements,
    required this.events,
  });

  factory AdminBusinessReviewDetail.fromJson(Map<String, dynamic> json) {
    return AdminBusinessReviewDetail(
      business: Map<String, dynamic>.from(json['business'] as Map? ?? const {}),
      category: Map<String, dynamic>.from(json['category'] as Map? ?? const {}),
      owner: Map<String, dynamic>.from(json['owner'] as Map? ?? const {}),
      coverage: _list(json['coverage']),
      services: _list(json['services']),
      lodgingDetails: Map<String, dynamic>.from(
        json['lodging_details'] as Map? ?? const {},
      ),
      media: _list(json['media']),
      requirements: _list(json['requirements']),
      events: _list(json['events']),
    );
  }

  final Map<String, dynamic> business;
  final Map<String, dynamic> category;
  final Map<String, dynamic> owner;
  final List<Map<String, dynamic>> coverage;
  final List<Map<String, dynamic>> services;
  final Map<String, dynamic> lodgingDetails;
  final List<Map<String, dynamic>> media;
  final List<Map<String, dynamic>> requirements;
  final List<Map<String, dynamic>> events;

  String get id => business['id'] as String;
  String get name => business['name'] as String? ?? 'Negocio';
  BusinessType get businessType => BusinessType.parseOrDefault(
        business['business_type'] as String?,
      );
  BusinessPublicationStatus get publicationStatus =>
      BusinessPublicationStatus.parseOrDefault(
        business['publication_status'] as String?,
      );
}

class AdminBusinessReviewPage {
  const AdminBusinessReviewPage({
    required this.items,
    required this.totalCount,
  });

  final List<AdminBusinessReviewSummary> items;
  final int totalCount;
}

class AdminBusinessReviewRepository {
  const AdminBusinessReviewRepository(this._client);

  final SupabaseClient? _client;

  Future<Result<Map<String, int>>> stats() async {
    final client = _client;

    if (client == null) {
      return const Success({});
    }

    try {
      final row = await client.rpc<Map<String, dynamic>>(
        'admin_business_review_stats',
      );

      return Success(
        row.map(
          (key, value) => MapEntry(
            key,
            (value as num?)?.toInt() ?? 0,
          ),
        ),
      );
    } catch (error) {
      return Failure(
        mapSupabaseFailure(
          error,
          fallbackMessage: 'No pudimos cargar el resumen admin.',
        ),
      );
    }
  }

  Future<Result<AdminBusinessReviewPage>> list({
    required BusinessPublicationStatus status,
    BusinessType? businessType,
    String? search,
    int limit = 20,
    int offset = 0,
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
      final rows = await client.rpc<List<dynamic>>(
        'admin_list_business_reviews',
        params: {
          'p_status': status.value,
          'p_business_type': businessType?.value,
          'p_search': search?.trim().isEmpty ?? true ? null : search!.trim(),
          'p_limit': limit,
          'p_offset': offset,
        },
      );
      final items = rows
          .whereType<Map>()
          .map(
            (row) => AdminBusinessReviewSummary.fromJson(
              Map<String, dynamic>.from(row),
            ),
          )
          .toList();

      return Success(
        AdminBusinessReviewPage(
          items: items,
          totalCount: items.isEmpty ? 0 : items.first.totalCount,
        ),
      );
    } catch (error) {
      return Failure(
        mapSupabaseFailure(
          error,
          fallbackMessage: 'No pudimos cargar negocios para revisión.',
        ),
      );
    }
  }

  Future<Result<AdminBusinessReviewDetail>> detail(String businessId) async {
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
        'admin_get_business_review',
        params: {'p_business_id': businessId},
      );

      return Success(AdminBusinessReviewDetail.fromJson(row));
    } catch (error) {
      return Failure(
        mapSupabaseFailure(
          error,
          fallbackMessage: 'No pudimos cargar el detalle del negocio.',
        ),
      );
    }
  }

  Future<Result<void>> requestChanges({
    required String businessId,
    required String message,
  }) {
    return _action(
      'admin_request_business_changes',
      {
        'p_business_id': businessId,
        'p_message': message,
      },
      'No pudimos solicitar cambios.',
    );
  }

  Future<Result<void>> reject({
    required String businessId,
    required String reason,
    bool canResubmit = false,
  }) {
    return _action(
      'admin_reject_business',
      {
        'p_business_id': businessId,
        'p_reason': reason,
        'p_can_resubmit': canResubmit,
      },
      'No pudimos rechazar el negocio.',
    );
  }

  Future<Result<void>> publish(String businessId) {
    return _action(
      'admin_publish_business',
      {'p_business_id': businessId},
      'No pudimos publicar el negocio.',
    );
  }

  Future<Result<void>> suspend({
    required String businessId,
    required String reason,
  }) {
    return _action(
      'admin_suspend_business',
      {
        'p_business_id': businessId,
        'p_reason': reason,
      },
      'No pudimos suspender el negocio.',
    );
  }

  Future<Result<void>> restore(String businessId) {
    return _action(
      'admin_restore_business',
      {'p_business_id': businessId},
      'No pudimos restaurar el negocio.',
    );
  }

  Future<Result<void>> _action(
    String rpc,
    Map<String, Object?> params,
    String fallbackMessage,
  ) async {
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
      await client.rpc(rpc, params: params);
      return const Success(null);
    } catch (error) {
      return Failure(
        mapSupabaseFailure(
          error,
          fallbackMessage: fallbackMessage,
        ),
      );
    }
  }
}

List<Map<String, dynamic>> _list(Object? value) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  return const [];
}
