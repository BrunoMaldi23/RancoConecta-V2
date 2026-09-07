import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../shared/models/location.dart';
import '../data/location_repository.dart';

final locationsProvider =
    FutureProvider<List<Location>>((ref) async {
  final result = await ref
      .watch(locationRepositoryProvider)
      .listActiveLocations();

  return result.when(
    success: (locations) {
      final sorted = [...locations]
        ..sort((a, b) {
          const officialOrder = [
            'lago-ranco',
            'futrono',
            'llifen',
            'rininahue',
            'calcurrupe',
            'maihue',
            'dollinco',
            'caunahue',
            'currine',
            'cerrillos',
            'notuela',
          ];

          final aIndex =
              officialOrder.indexOf(a.slug);

          final bIndex =
              officialOrder.indexOf(b.slug);

          if (aIndex == -1 && bIndex == -1) {
            return a.name.compareTo(b.name);
          }

          if (aIndex == -1) {
            return 1;
          }

          if (bIndex == -1) {
            return -1;
          }

          return aIndex.compareTo(bIndex);
        });

      return sorted;
    },
    failure: (failure) => throw failure,
  );
});

final selectedLocationProvider =
    StateProvider<Location?>((ref) => null);

String locationFailureMessage(Object error) {
  if (error is AppFailure) {
    return error.message;
  }

  return 'No pudimos cargar las localidades.';
}