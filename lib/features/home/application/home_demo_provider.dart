import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/category_preview.dart';

final homeCategoriesProvider = Provider<List<CategoryPreview>>((ref) {
  return const [
    CategoryPreview(
      name: 'Servicios hogar',
      slug: 'home-services',
      iconKey: 'tools',
      themeKey: 'forest',
    ),
    CategoryPreview(
      name: 'Comercios',
      slug: 'commerce',
      iconKey: 'store',
      themeKey: 'lake',
    ),
    CategoryPreview(
      name: 'Gastronomía',
      slug: 'gastronomy',
      iconKey: 'restaurant',
      themeKey: 'clay',
    ),
    CategoryPreview(
      name: 'Alojamientos',
      slug: 'lodging',
      iconKey: 'lodging',
      themeKey: 'moss',
    ),
  ];
});
