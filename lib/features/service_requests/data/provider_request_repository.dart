import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_mapper.dart';
import '../../../core/result/result.dart';
import '../../../features/auth/data/supabase_auth_repository.dart';
import '../../../shared/models/operation.dart';
import '../../../shared/models/quote.dart';
import 'quote_repository.dart';

final providerRequestRepositoryProvider =
    Provider<ProviderRequestRepository>((ref) {
  return ProviderRequestRepository(ref.watch(supabaseClientProvider));
});

class ProviderRequestRepository {
  const ProviderRequestRepository(this._client);

  final SupabaseClient? _client;

  Future<Result<List<ProviderRequestItem>>> listForBusiness(
    String businessId,
  ) async {
    final client = _client;

    if (client == null) {
      return const Success([]);
    }

    try {
      final rows = await client.rpc<List<dynamic>>(
        'provider_service_request_queue',
        params: {
          'p_business_id': businessId,
          'p_status': null,
        },
      );

      return Success(
        rows
            .whereType<Map>()
            .map((row) => _providerRequestFromJson(
                  Map<String, dynamic>.from(row),
                ))
            .toList(),
      );
    } catch (error) {
      return Failure(
        mapSupabaseFailure(
          error,
          fallbackMessage: 'No pudimos cargar las solicitudes del negocio.',
        ),
      );
    }
  }

  Future<Result<Operation>> startOperation(String operationId) {
    return _operationAction(
      rpc: 'provider_start_operation',
      operationId: operationId,
      fallback: 'No pudimos iniciar la operación.',
    );
  }

  Future<Result<Operation>> completeOperation(String operationId) {
    return _operationAction(
      rpc: 'provider_complete_operation',
      operationId: operationId,
      fallback: 'No pudimos finalizar la operación.',
    );
  }

  Future<Result<Operation>> _operationAction({
    required String rpc,
    required String operationId,
    required String fallback,
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
        rpc,
        params: {'p_operation_id': operationId},
      );

      return Success(OperationDto.fromJson(row));
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

ProviderRequestItem _providerRequestFromJson(Map<String, dynamic> json) {
  return ProviderRequestItem(
    requestId: json['request_id'] as String,
    publicCode: json['public_code'] as String? ?? 'Solicitud',
    businessId: json['business_id'] as String,
    subcategoryId: json['subcategory_id'] as String,
    subcategoryName: json['subcategory_name'] as String? ?? 'Servicio',
    locationId: json['location_id'] as String?,
    locationName: json['location_name'] as String?,
    description: json['description'] as String? ?? '',
    addressText: json['address_text'] as String?,
    urgency: json['urgency'] as String? ?? 'normal',
    desiredDate: DateTime.tryParse(json['desired_date']?.toString() ?? ''),
    requestStatus: json['request_status'] as String? ?? 'submitted',
    attachmentCount: (json['attachment_count'] as num?)?.toInt() ?? 0,
    quoteId: json['quote_id'] as String?,
    quoteStatus: json['quote_status'] == null
        ? null
        : QuoteStatus.parse(json['quote_status'] as String?),
    quoteTotal: (json['quote_total'] as num?)?.toInt(),
    operationId: json['operation_id'] as String?,
    operationStatus: json['operation_status'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}
