import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_mapper.dart';
import '../../../core/result/result.dart';
import '../../../shared/models/business.dart';
import '../../auth/data/supabase_auth_repository.dart';
import '../../provider_registration/data/business_onboarding_repository.dart';
import 'provider_business_repository.dart';

final serviceBusinessManagementRepositoryProvider =
    Provider<ServiceBusinessManagementRepository>((ref) {
  return ServiceBusinessManagementRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(providerBusinessRepositoryProvider),
  );
});

class ServiceBusinessManagementRepository {
  const ServiceBusinessManagementRepository(
    this._client,
    this._providerBusinessRepository,
  );

  final SupabaseClient? _client;
  final ProviderBusinessRepository _providerBusinessRepository;

  static const _businessSelect = '''
id,
business_type,
publication_status,
name,
description,
phone,
whatsapp,
email,
website,
primary_category_id,
address_text,
onboarding_metadata,
submitted_at,
changes_requested_note,
business_coverage(
  location_id,
  locations(name, slug)
),
business_services(
  subcategory_id,
  description,
  price_from,
  subcategories(
    id,
    category_id,
    name,
    slug,
    description,
    icon_key
  )
),
business_hours(
  day_of_week,
  open_time,
  close_time,
  is_closed
)
''';

  Future<Result<ServiceBusinessManagementState>> load(String businessId) async {
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
      final manageable =
          await _providerBusinessRepository.getBusinessByIdForCurrentUser(
        businessId,
      );

      if (manageable == null) {
        return const Failure(
          AppFailure(
            type: AppFailureType.permission,
            message: 'No tienes permisos para administrar este negocio.',
          ),
        );
      }

      final row = await client
          .from('businesses')
          .select(_businessSelect)
          .eq('id', businessId)
          .single();

      return Success(
        ServiceBusinessManagementState(
          summary: manageable,
          draft: BusinessDraft.fromJson(
            Map<String, dynamic>.from(row),
          ),
        ),
      );
    } catch (error) {
      return Failure(
        mapSupabaseFailure(
          error,
          fallbackMessage: 'No pudimos cargar la gestión del negocio.',
        ),
      );
    }
  }

  Future<Result<void>> updateProfile({
    required String businessId,
    required String name,
    required String description,
    required String phone,
    required String whatsapp,
    required String email,
    required String website,
    required String addressText,
  }) {
    return _run(
      rpc: 'update_manageable_business_profile',
      fallback: 'No pudimos actualizar el perfil.',
      params: {
        'p_business_id': businessId,
        'p_name': name,
        'p_description': description,
        'p_phone': phone,
        'p_whatsapp': whatsapp,
        'p_email': email,
        'p_website': website,
        'p_address_text': addressText,
      },
    );
  }

  Future<Result<void>> replaceServices({
    required String businessId,
    required List<ServiceDraftInput> services,
  }) {
    return _run(
      rpc: 'replace_manageable_business_services',
      fallback: 'No pudimos guardar los servicios.',
      params: {
        'p_business_id': businessId,
        'p_service_items': services.map((item) => item.toJson()).toList(),
      },
    );
  }

  Future<Result<void>> replaceCoverage({
    required String businessId,
    required List<String> locationIds,
  }) {
    return _run(
      rpc: 'replace_manageable_business_coverage',
      fallback: 'No pudimos actualizar la cobertura.',
      params: {
        'p_business_id': businessId,
        'p_location_ids': locationIds,
      },
    );
  }

  Future<Result<void>> replaceHours({
    required String businessId,
    required List<BusinessHourInput> hours,
  }) {
    return _run(
      rpc: 'replace_manageable_business_hours',
      fallback: 'No pudimos guardar los horarios.',
      params: {
        'p_business_id': businessId,
        'p_hours': hours.map((item) => item.toJson()).toList(),
      },
    );
  }

  Future<Result<void>> _run({
    required String rpc,
    required String fallback,
    required Map<String, Object?> params,
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
      await client.rpc<void>(rpc, params: params);
      return const Success(null);
    } catch (error) {
      return Failure(
        mapSupabaseFailure(
          error,
          fallbackMessage: fallback,
        ),
      );
    }
  }
}

class ServiceBusinessManagementState {
  const ServiceBusinessManagementState({
    required this.summary,
    required this.draft,
  });

  final ProviderBusinessSummary summary;
  final BusinessDraft draft;

  bool get isService => summary.businessType == BusinessType.service;
}

class BusinessHourInput {
  const BusinessHourInput({
    required this.dayOfWeek,
    required this.isClosed,
    this.openTime,
    this.closeTime,
  });

  final int dayOfWeek;
  final bool isClosed;
  final String? openTime;
  final String? closeTime;

  Map<String, Object?> toJson() {
    return {
      'day_of_week': dayOfWeek,
      'is_closed': isClosed,
      'open_time': openTime,
      'close_time': closeTime,
    };
  }
}
