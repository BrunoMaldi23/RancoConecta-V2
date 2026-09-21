import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_mapper.dart';
import '../../../core/result/result.dart';
import '../../../features/auth/data/supabase_auth_repository.dart';
import '../../../shared/models/business.dart';
import '../../../shared/models/category.dart';
import '../../../shared/models/location.dart';

final businessOnboardingRepositoryProvider =
    Provider<BusinessOnboardingRepository>((ref) {
  return BusinessOnboardingRepository(
    ref.watch(supabaseClientProvider),
  );
});

class BusinessDraft {
  const BusinessDraft({
    required this.id,
    required this.businessType,
    required this.publicationStatus,
    required this.name,
    required this.description,
    required this.phone,
    required this.whatsapp,
    required this.email,
    required this.website,
    required this.primaryCategoryId,
    required this.addressText,
    required this.coverage,
    required this.services,
    required this.onboardingMetadata,
    required this.submittedAt,
    required this.changesRequestedNote,
  });

  factory BusinessDraft.fromJson(Map<String, dynamic> json) {
    return BusinessDraft(
      id: json['id'] as String,
      businessType: BusinessType.parseOrDefault(
        json['business_type'] as String?,
      ),
      publicationStatus: BusinessPublicationStatus.parseOrDefault(
        json['publication_status'] as String?,
      ),
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      phone: json['phone'] as String?,
      whatsapp: json['whatsapp'] as String?,
      email: json['email'] as String?,
      website: json['website'] as String?,
      primaryCategoryId: json['primary_category_id'] as String?,
      addressText: json['address_text'] as String?,
      coverage: _list(json['business_coverage'])
          .map(
            (item) => Location(
              id: item['location_id'] as String,
              communeId: '',
              name: (item['locations'] as Map?)?['name']?.toString() ??
                  'Localidad',
              slug: (item['locations'] as Map?)?['slug']?.toString() ?? '',
            ),
          )
          .toList(),
      services: _list(json['business_services'])
          .map(
            (item) => BusinessDraftService(
              subcategory: Subcategory(
                id: item['subcategory_id'] as String,
                categoryId: (item['subcategories'] as Map?)?['category_id']
                        ?.toString() ??
                    '',
                name: (item['subcategories'] as Map?)?['name']?.toString() ??
                    'Servicio',
                slug:
                    (item['subcategories'] as Map?)?['slug']?.toString() ?? '',
                description:
                    (item['subcategories'] as Map?)?['description']?.toString(),
                iconKey:
                    (item['subcategories'] as Map?)?['icon_key']?.toString() ??
                        'tools',
              ),
              description: item['description'] as String?,
              priceFrom: (item['price_from'] as num?)?.toInt(),
            ),
          )
          .toList(),
      onboardingMetadata: Map<String, dynamic>.from(
        json['onboarding_metadata'] as Map? ?? const {},
      ),
      submittedAt: DateTime.tryParse(json['submitted_at']?.toString() ?? ''),
      changesRequestedNote: json['changes_requested_note'] as String?,
    );
  }

  final String id;
  final BusinessType businessType;
  final BusinessPublicationStatus publicationStatus;
  final String name;
  final String? description;
  final String? phone;
  final String? whatsapp;
  final String? email;
  final String? website;
  final String? primaryCategoryId;
  final String? addressText;
  final List<Location> coverage;
  final List<BusinessDraftService> services;
  final Map<String, dynamic> onboardingMetadata;
  final DateTime? submittedAt;
  final String? changesRequestedNote;

  bool get canContinueOnboarding {
    return publicationStatus == BusinessPublicationStatus.draft ||
        publicationStatus == BusinessPublicationStatus.changesRequested;
  }
}

class BusinessDraftService {
  const BusinessDraftService({
    required this.subcategory,
    required this.description,
    required this.priceFrom,
  });

  final Subcategory subcategory;
  final String? description;
  final int? priceFrom;
}

class BusinessDraftInput {
  const BusinessDraftInput({
    required this.businessId,
    required this.name,
    required this.description,
    required this.phone,
    required this.whatsapp,
    required this.email,
    required this.website,
    required this.primaryCategoryId,
    required this.addressText,
    required this.coverageLocationIds,
    required this.serviceItems,
    required this.onboardingMetadata,
  });

  final String businessId;
  final String name;
  final String description;
  final String phone;
  final String whatsapp;
  final String email;
  final String website;
  final String? primaryCategoryId;
  final String addressText;
  final List<String> coverageLocationIds;
  final List<ServiceDraftInput> serviceItems;
  final Map<String, Object?> onboardingMetadata;
}

class ServiceDraftInput {
  const ServiceDraftInput({
    required this.subcategoryId,
    this.description,
    this.priceFrom,
  });

  final String subcategoryId;
  final String? description;
  final int? priceFrom;

  Map<String, Object?> toJson() {
    return {
      'subcategory_id': subcategoryId,
      'description': description,
      'price_from': priceFrom,
    };
  }
}

class ReviewRequirement {
  const ReviewRequirement({
    required this.key,
    required this.satisfied,
    required this.message,
  });

  factory ReviewRequirement.fromJson(Map<String, dynamic> json) {
    return ReviewRequirement(
      key: json['requirement_key'] as String? ?? '',
      satisfied: json['satisfied'] as bool? ?? false,
      message: json['message'] as String? ?? '',
    );
  }

  final String key;
  final bool satisfied;
  final String message;
}

class BusinessOnboardingRepository {
  const BusinessOnboardingRepository(this._client);

  final SupabaseClient? _client;

  static const _draftSelect = '''
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
)
''';

  Future<Result<String>> createBusinessDraft({
    required BusinessType businessType,
    required String name,
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
        'create_business_draft',
        params: {
          'p_business_type': businessType.value,
          'p_name': name,
        },
      );

      return Success(id);
    } catch (error) {
      return Failure(
        mapSupabaseFailure(
          error,
          fallbackMessage: 'No pudimos crear el borrador del negocio.',
        ),
      );
    }
  }

  Future<Result<BusinessDraft>> getBusinessDraft(String businessId) async {
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
      final row = await client
          .from('businesses')
          .select(_draftSelect)
          .eq('id', businessId)
          .single();

      return Success(
        BusinessDraft.fromJson(
          Map<String, dynamic>.from(row),
        ),
      );
    } catch (error) {
      return Failure(
        mapSupabaseFailure(
          error,
          fallbackMessage: 'No pudimos cargar el borrador del negocio.',
        ),
      );
    }
  }

  Future<Result<BusinessDraft?>> getLatestEditableDraft() async {
    final client = _client;
    final userId = client?.auth.currentUser?.id;

    if (client == null || userId == null) {
      return const Success(null);
    }

    try {
      final rows = await client
          .from('business_members')
          .select(
            '''
            businesses($_draftSelect)
            ''',
          )
          .eq('user_id', userId)
          .eq('status', 'active')
          .order('created_at', ascending: false);

      for (final row in rows) {
        final business = row['businesses'];

        if (business is! Map) {
          continue;
        }

        final draft = BusinessDraft.fromJson(
          Map<String, dynamic>.from(business),
        );

        if (draft.canContinueOnboarding) {
          return Success(draft);
        }
      }

      return const Success(null);
    } catch (error) {
      return Failure(
        mapSupabaseFailure(
          error,
          fallbackMessage: 'No pudimos buscar tus borradores.',
        ),
      );
    }
  }

  Future<Result<List<BusinessDraft>>> getMyBusinesses() async {
    final client = _client;
    final userId = client?.auth.currentUser?.id;

    if (client == null || userId == null) {
      return const Success([]);
    }

    try {
      final rows = await client
          .from('business_members')
          .select(
            '''
            businesses($_draftSelect)
            ''',
          )
          .eq('user_id', userId)
          .eq('status', 'active')
          .order('created_at', ascending: false);

      return Success(
        rows
            .map((row) => row['businesses'])
            .whereType<Map>()
            .map(
              (row) => BusinessDraft.fromJson(
                Map<String, dynamic>.from(row),
              ),
            )
            .toList(),
      );
    } catch (error) {
      return Failure(
        mapSupabaseFailure(
          error,
          fallbackMessage: 'No pudimos cargar tus negocios.',
        ),
      );
    }
  }

  Future<Result<BusinessDraft>> updateBusinessDraft(
    BusinessDraftInput input,
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
      await client.rpc(
        'update_business_draft',
        params: {
          'p_business_id': input.businessId,
          'p_name': input.name,
          'p_description': input.description,
          'p_phone': input.phone,
          'p_whatsapp': input.whatsapp,
          'p_email': input.email,
          'p_website': input.website,
          'p_primary_category_id': input.primaryCategoryId,
          'p_address_text': input.addressText,
          'p_coverage_location_ids': input.coverageLocationIds,
          'p_service_items':
              input.serviceItems.map((item) => item.toJson()).toList(),
          'p_onboarding_metadata': input.onboardingMetadata,
        },
      );

      return getBusinessDraft(input.businessId);
    } catch (error) {
      return Failure(
        mapSupabaseFailure(
          error,
          fallbackMessage: 'No pudimos guardar el borrador.',
        ),
      );
    }
  }

  Future<Result<List<ReviewRequirement>>> getReviewRequirements(
    String businessId,
  ) async {
    final client = _client;

    if (client == null) {
      return const Success([]);
    }

    try {
      final rows = await client.rpc<List<dynamic>>(
        'business_review_requirements',
        params: {
          'p_business_id': businessId,
        },
      );

      return Success(
        rows
            .whereType<Map>()
            .map(
              (row) => ReviewRequirement.fromJson(
                Map<String, dynamic>.from(row),
              ),
            )
            .toList(),
      );
    } catch (error) {
      return Failure(
        mapSupabaseFailure(
          error,
          fallbackMessage: 'No pudimos validar el negocio.',
        ),
      );
    }
  }

  Future<Result<BusinessDraft>> submitBusinessForReview(
    String businessId,
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
      await client.rpc(
        'submit_business_for_review',
        params: {
          'p_business_id': businessId,
        },
      );

      return getBusinessDraft(businessId);
    } catch (error) {
      return Failure(
        mapSupabaseFailure(
          error,
          fallbackMessage: 'No pudimos enviar el negocio a revisión.',
        ),
      );
    }
  }
}

List<Map<String, dynamic>> _list(Object? value) {
  if (value is List) {
    return value.whereType<Map<String, dynamic>>().toList();
  }

  return const [];
}
