import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/gastronomy_repository.dart';

final gastronomyMenuProvider =
    FutureProvider.family<GastronomyMenu, String>((ref, businessId) {
  return ref.watch(gastronomyRepositoryProvider).getMenu(businessId);
});

final gastronomyReservationsProvider =
    FutureProvider.family<List<TableReservation>, String>((ref, businessId) {
  return ref.watch(gastronomyRepositoryProvider).listReservations(businessId);
});
