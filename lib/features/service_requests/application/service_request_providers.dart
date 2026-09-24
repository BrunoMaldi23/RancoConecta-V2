import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../shared/models/request_attachment.dart';
import '../../../shared/models/quote.dart';
import '../../../shared/models/service_request.dart';
import '../../provider_dashboard/application/provider_dashboard_providers.dart';
import '../data/provider_request_repository.dart';
import '../data/quote_repository.dart';
import '../data/request_attachment_repository.dart';
import '../data/service_request_repository.dart';

final myRequestsProvider = FutureProvider<List<ServiceRequest>>((ref) async {
  final result =
      await ref.watch(serviceRequestRepositoryProvider).listMyRequests();
  return result.when(
    success: (requests) => requests,
    failure: (failure) => throw failure,
  );
});

final requestDetailProvider =
    FutureProvider.family<ServiceRequest, String>((ref, id) async {
  final result =
      await ref.watch(serviceRequestRepositoryProvider).getRequestById(id);
  return result.when(
    success: (request) => request,
    failure: (failure) => throw failure,
  );
});

final requestQuotesProvider =
    FutureProvider.family<List<Quote>, String>((ref, requestId) async {
  final result =
      await ref.watch(quoteRepositoryProvider).listQuotesForRequest(requestId);

  return result.when(
    success: (quotes) => quotes,
    failure: (failure) => throw failure,
  );
});

final requestAttachmentsProvider =
    FutureProvider.family<List<RequestAttachment>, String>(
        (ref, requestId) async {
  final result =
      await ref.watch(requestAttachmentRepositoryProvider).list(requestId);

  return result.when(
    success: (attachments) => attachments,
    failure: (failure) => throw failure,
  );
});

final providerRequestQueueProvider =
    FutureProvider<List<ProviderRequestItem>>((ref) async {
  final business = await ref.watch(activeProviderBusinessProvider.future);

  if (business == null) {
    return const [];
  }

  final result = await ref
      .watch(providerRequestRepositoryProvider)
      .listForBusiness(business.id);

  return result.when(
    success: (items) => items,
    failure: (failure) => throw failure,
  );
});

String requestFailureMessage(Object error) {
  if (error is AppFailure) {
    return error.message;
  }
  return 'No pudimos cargar las solicitudes.';
}
