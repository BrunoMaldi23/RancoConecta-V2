import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failure_mapper.dart';
import '../../../core/result/result.dart';
import '../../../features/auth/data/supabase_auth_repository.dart';
import '../../../shared/models/category.dart';
import 'category_dto.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return SupabaseCategoryRepository(ref.watch(supabaseClientProvider));
});

abstract interface class CategoryRepository {
  Future<Result<List<Category>>> listActiveCategories();
  Future<Result<List<Subcategory>>> listActiveSubcategories(
      {String? categoryId});
}

class SupabaseCategoryRepository implements CategoryRepository {
  const SupabaseCategoryRepository(this._client);

  final SupabaseClient? _client;

  @override
  Future<Result<List<Category>>> listActiveCategories() async {
    final client = _client;
    if (client == null) {
      return const Success([]);
    }
    try {
      final rows = await client
          .from('categories')
          .select()
          .eq('active', true)
          .order('sort_order');
      return Success(
          rows.map((row) => CategoryDto.fromJson(row).toDomain()).toList());
    } catch (error) {
      return Failure(mapSupabaseFailure(error,
          fallbackMessage: 'No pudimos cargar las categorías.'));
    }
  }

  @override
  Future<Result<List<Subcategory>>> listActiveSubcategories(
      {String? categoryId}) async {
    final client = _client;
    if (client == null) {
      return const Success([]);
    }
    try {
      var query = client.from('subcategories').select().eq('active', true);
      if (categoryId != null) {
        query = query.eq('category_id', categoryId);
      }
      final rows = await query.order('sort_order');
      return Success(
          rows.map((row) => SubcategoryDto.fromJson(row).toDomain()).toList());
    } catch (error) {
      return Failure(mapSupabaseFailure(error,
          fallbackMessage: 'No pudimos cargar los servicios.'));
    }
  }
}
