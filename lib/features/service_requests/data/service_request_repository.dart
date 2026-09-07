import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_mapper.dart';
import '../../../core/result/result.dart';
import '../../../features/auth/data/supabase_auth_repository.dart';
import '../../../shared/models/service_request.dart';
import 'service_request_dto.dart';

final serviceRequestRepositoryProvider =
    Provider<ServiceRequestRepository>((ref) {
  return SupabaseServiceRequestRepository(ref.watch(supabaseClientProvider));
});

class CreateServiceRequestInput {
  const CreateServiceRequestInput({
    required this.businessId,
    required this.categoryId,
    required this.subcategoryId,
    required this.description,
    required this.addressText,
    required this.urgency,
    required this.desiredDate,
  });

  final String businessId;
  final String categoryId;
  final String subcategoryId;
  final String description;
  final String addressText;
  final RequestUrgency urgency;
  final DateTime? desiredDate;
}

abstract interface class ServiceRequestRepository {
  Future<Result<ServiceRequest>> createDirectRequest(
      CreateServiceRequestInput input);
  Future<Result<List<ServiceRequest>>> listMyRequests();
  Future<Result<ServiceRequest>> getRequestById(String id);
}

class SupabaseServiceRequestRepository implements ServiceRequestRepository {
  const SupabaseServiceRequestRepository(this._client);

  final SupabaseClient? _client;

  static const _select = '''
id, public_code, business_id, category_id, subcategory_id, description, address_text, urgency, desired_date, status, created_at,
businesses(name),
subcategories(name)
''';

  @override
  Future<Result<ServiceRequest>> createDirectRequest(
      CreateServiceRequestInput input) async {
    final client = _client;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) {
      return const Failure(
        AppFailure(
            type: AppFailureType.auth,
            message: 'Debes ingresar para solicitar un servicio.'),
      );
    }
    try {
      final row = await client
          .from('service_requests')
          .insert({
            'customer_id': userId,
            'business_id': input.businessId,
            'category_id': input.categoryId,
            'subcategory_id': input.subcategoryId,
            'description': input.description.trim(),
            'address_text': input.addressText.trim(),
            'urgency': input.urgency.name,
            'desired_date':
                input.desiredDate?.toIso8601String().split('T').first,
            'status': 'submitted',
          })
          .select(_select)
          .single();
      return Success(ServiceRequestDto.fromJson(row).toDomain());
    } catch (error) {
      return Failure(mapSupabaseFailure(error,
          fallbackMessage: 'No pudimos crear la solicitud.'));
    }
  }

  @override
  Future<Result<List<ServiceRequest>>> listMyRequests() async {
    final client = _client;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) {
      return const Success([]);
    }
    try {
      final rows = await client
          .from('service_requests')
          .select(_select)
          .eq('customer_id', userId)
          .order('created_at', ascending: false);
      return Success(rows
          .map((row) => ServiceRequestDto.fromJson(row).toDomain())
          .toList());
    } catch (error) {
      return Failure(mapSupabaseFailure(error,
          fallbackMessage: 'No pudimos cargar tus solicitudes.'));
    }
  }

  @override
  Future<Result<ServiceRequest>> getRequestById(String id) async {
    final client = _client;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) {
      return const Failure(
        AppFailure(
            type: AppFailureType.auth,
            message: 'Debes ingresar para ver esta solicitud.'),
      );
    }
    try {
      final row = await client
          .from('service_requests')
          .select(_select)
          .eq('id', id)
          .single();
      return Success(ServiceRequestDto.fromJson(row).toDomain());
    } catch (error) {
      return Failure(mapSupabaseFailure(error,
          fallbackMessage: 'No pudimos cargar la solicitud.'));
    }
  }
}
