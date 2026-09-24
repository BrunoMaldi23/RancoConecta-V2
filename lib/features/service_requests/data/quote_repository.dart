import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_mapper.dart';
import '../../../core/result/result.dart';
import '../../../features/auth/data/supabase_auth_repository.dart';
import '../../../shared/models/operation.dart';
import '../../../shared/models/quote.dart';

final quoteRepositoryProvider = Provider<QuoteRepository>((ref) {
  return QuoteRepository(ref.watch(supabaseClientProvider));
});

class SendQuoteInput {
  const SendQuoteInput({
    required this.requestId,
    required this.businessId,
    required this.description,
    required this.totalAmount,
    this.expiresAt,
  });

  final String requestId;
  final String businessId;
  final String description;
  final int totalAmount;
  final DateTime? expiresAt;
}

class QuoteRepository {
  const QuoteRepository(this._client);

  final SupabaseClient? _client;

  Future<Result<List<Quote>>> listQuotesForRequest(String requestId) async {
    final client = _client;

    if (client == null) {
      return const Success([]);
    }

    try {
      final rows = await client
          .from('quotes')
          .select(
            '''
            id,
            request_id,
            business_id,
            total_amount,
            description,
            expires_at,
            status,
            created_at,
            businesses(name)
            ''',
          )
          .eq('request_id', requestId)
          .order('created_at', ascending: false);

      return Success(
        rows
            .map((row) => QuoteDto.fromJson(Map<String, dynamic>.from(row)))
            .toList(),
      );
    } catch (error) {
      return Failure(
        mapSupabaseFailure(
          error,
          fallbackMessage: 'No pudimos cargar las cotizaciones.',
        ),
      );
    }
  }

  Future<Result<Quote>> sendQuote(SendQuoteInput input) async {
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
        'provider_send_quote',
        params: {
          'p_request_id': input.requestId,
          'p_business_id': input.businessId,
          'p_description': input.description.trim(),
          'p_total_amount': input.totalAmount,
          'p_expires_at': input.expiresAt?.toIso8601String(),
        },
      );

      return Success(
        QuoteDto.fromJson(row),
      );
    } catch (error) {
      return Failure(
        mapSupabaseFailure(
          error,
          fallbackMessage: 'No pudimos enviar la cotización.',
        ),
      );
    }
  }

  Future<Result<Operation>> acceptQuote(String quoteId) async {
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
        'accept_quote',
        params: {'p_quote_id': quoteId},
      );

      return Success(OperationDto.fromJson(row));
    } catch (error) {
      return Failure(
        mapSupabaseFailure(
          error,
          fallbackMessage: 'No pudimos aceptar la cotización.',
        ),
      );
    }
  }

  Future<Result<Quote>> rejectQuote(String quoteId) async {
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
        'reject_quote',
        params: {'p_quote_id': quoteId},
      );

      return Success(QuoteDto.fromJson(row));
    } catch (error) {
      return Failure(
        mapSupabaseFailure(
          error,
          fallbackMessage: 'No pudimos rechazar la cotización.',
        ),
      );
    }
  }
}

class QuoteDto {
  const QuoteDto._();

  static Quote fromJson(Map<String, dynamic> json) {
    final business = json['businesses'] as Map?;

    return Quote(
      id: json['id'] as String,
      requestId: json['request_id'] as String,
      businessId: json['business_id'] as String,
      businessName: business?['name']?.toString() ?? 'Prestador',
      totalAmount: (json['total_amount'] as num?)?.toInt() ?? 0,
      description: json['description'] as String?,
      expiresAt: DateTime.tryParse(json['expires_at']?.toString() ?? ''),
      status: QuoteStatus.parse(json['status'] as String?),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class OperationDto {
  const OperationDto._();

  static Operation fromJson(Map<String, dynamic> json) {
    return Operation(
      id: json['id'] as String,
      type: OperationType.parse(json['type'] as String? ?? 'service'),
      customerId: json['customer_id'] as String,
      businessId: json['business_id'] as String?,
      status: OperationStatus.parse(json['status'] as String? ?? 'draft'),
      currency: json['currency'] as String? ?? 'CLP',
      subtotal: (json['subtotal'] as num?)?.toInt() ?? 0,
      platformFee: (json['platform_fee'] as num?)?.toInt() ?? 0,
      discount: (json['discount'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
      paymentStatus: OperationPaymentStatus.parse(
        json['payment_status'] as String? ?? 'not_required',
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
