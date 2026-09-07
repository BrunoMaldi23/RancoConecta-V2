import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../shared/models/service_request.dart';
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

String requestFailureMessage(Object error) {
  if (error is AppFailure) {
    return error.message;
  }
  return 'No pudimos cargar las solicitudes.';
}
