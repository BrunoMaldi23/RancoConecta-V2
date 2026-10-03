import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/business.dart';
import '../../businesses/application/business_hours.dart';
import '../../businesses/data/business_repository.dart';

typedef ExploreFilters = ({
  String? categoryId,
  String? locationId,
  String search,
  bool verifiedOnly,
  bool featuredOnly,
  bool openNowOnly,
});

class ExploreBusinessesState {
  const ExploreBusinessesState({
    required this.items,
    required this.nextOffset,
    required this.hasMore,
    this.loadingMore = false,
    this.loadMoreError = false,
  });

  final List<Business> items;
  final int nextOffset;
  final bool hasMore;
  final bool loadingMore;
  final bool loadMoreError;

  ExploreBusinessesState copyWith({
    List<Business>? items,
    int? nextOffset,
    bool? hasMore,
    bool? loadingMore,
    bool? loadMoreError,
  }) =>
      ExploreBusinessesState(
        items: items ?? this.items,
        nextOffset: nextOffset ?? this.nextOffset,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
        loadMoreError: loadMoreError ?? this.loadMoreError,
      );
}

final exploreBusinessesProvider = StateNotifierProvider.autoDispose.family<
    ExploreBusinessesController,
    AsyncValue<ExploreBusinessesState>,
    ExploreFilters>((ref, filters) {
  return ExploreBusinessesController(
    ref.watch(businessRepositoryProvider),
    filters,
  );
});

class ExploreBusinessesController
    extends StateNotifier<AsyncValue<ExploreBusinessesState>> {
  ExploreBusinessesController(this._repository, this._filters)
      : super(const AsyncLoading()) {
    _loadInitial();
  }

  static const pageSize = 50;

  final BusinessRepository _repository;
  final ExploreFilters _filters;

  Future<BusinessPage> _fetch(int offset) async {
    final result = await _repository.listPublishedBusinessesPage(
      BusinessQuery(
        categoryId: _filters.categoryId,
        locationId: _filters.locationId,
        searchQuery: _filters.search,
        verifiedOnly: _filters.verifiedOnly,
        featuredOnly: _filters.featuredOnly,
        limit: pageSize,
        offset: offset,
      ),
    );
    return result.when(
      success: (page) => page,
      failure: (failure) => throw failure,
    );
  }

  List<Business> _visible(List<Business> items) {
    if (!_filters.openNowOnly) return items;
    final now = DateTime.now();
    return items.where((item) => isOpenNow(item.hours, now)).toList();
  }

  Future<void> _loadInitial() async {
    try {
      final page = await _fetch(0);
      if (!mounted) return;
      state = AsyncData(ExploreBusinessesState(
        items: _visible(page.items),
        nextOffset: page.nextOffset,
        hasMore: page.hasMore,
      ));
    } catch (error, stackTrace) {
      if (mounted) state = AsyncError(error, stackTrace);
    }
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.loadingMore || !current.hasMore) return;

    state = AsyncData(current.copyWith(
      loadingMore: true,
      loadMoreError: false,
    ));
    try {
      final page = await _fetch(current.nextOffset);
      if (!mounted) return;
      final seenIds = current.items.map((item) => item.id).toSet();
      final additions =
          _visible(page.items).where((item) => seenIds.add(item.id)).toList();
      state = AsyncData(current.copyWith(
        items: [...current.items, ...additions],
        nextOffset: page.nextOffset,
        hasMore: page.hasMore,
        loadingMore: false,
      ));
    } catch (_) {
      if (mounted) {
        state = AsyncData(current.copyWith(
          loadingMore: false,
          loadMoreError: true,
        ));
      }
    }
  }
}
