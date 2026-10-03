import '../../../shared/models/category.dart';

// Presentation order for Explore and the complete category directory.
const editorialCategorySlugs = <String>[
  'alojamiento',
  'gastronomia',
  'turismo-aventura',
  'emergencias',
  'hogar-y-mantenimiento',
  'gasfiteria',
  'electricidad',
  'mecanica',
  'computacion',
  'aseo',
  'jardineria',
  'albanileria',
  'calefaccion',
  'carpinteria',
  'cerrajeria',
  'energia-solar',
  'fletes',
  'inspeccion-visual',
  'pintura',
  'retiro-de-chatarra',
  'retiro-de-escombros',
  'servicios-de-fosas',
  'soldadura',
  'techumbre',
  'propiedades-terrenos',
  'servicios-profesionales',
  'otros-servicios',
];

// Accesos rápidos de Explorar. El catálogo completo queda en "Más".
const quickAccessCategorySlugs = <String>[
  'alojamiento',
  'gastronomia',
  'turismo-aventura',
  'emergencias',
  'hogar-y-mantenimiento',
];

const _quickAccessLabels = <String, String>{
  'turismo-aventura': 'Turismo',
  'hogar-y-mantenimiento': 'Servicios',
};

/// Etiqueta corta para chips de acceso rápido.
String quickAccessLabel(Category category) =>
    _quickAccessLabels[_editorialSlug(category)] ?? category.name;

// Existing installations can still have the original English slugs.
const _legacySlugs = <String, String>{
  'emergencies': 'emergencias',
  'home-maintenance': 'hogar-y-mantenimiento',
  'transport': 'fletes',
  'lodging': 'alojamiento',
  'gastronomy': 'gastronomia',
  'tourism': 'turismo-aventura',
};

String _editorialSlug(Category category) =>
    _legacySlugs[category.slug] ?? category.slug;

List<Category> sortCategoriesForPresentation(List<Category> categories) {
  final order = {
    for (var index = 0; index < editorialCategorySlugs.length; index++)
      editorialCategorySlugs[index]: index,
  };

  return [...categories]..sort((left, right) {
      final leftRank =
          order[_editorialSlug(left)] ?? editorialCategorySlugs.length;
      final rightRank =
          order[_editorialSlug(right)] ?? editorialCategorySlugs.length;
      final rankComparison = leftRank.compareTo(rightRank);
      if (rankComparison != 0) return rankComparison;
      return left.name.toLowerCase().compareTo(right.name.toLowerCase());
    });
}

List<Category> quickAccessCategories(List<Category> categories) {
  final bySlug = <String, Category>{};
  for (final category in categories) {
    bySlug.putIfAbsent(_editorialSlug(category), () => category);
  }
  for (final category in categories) {
    if (category.slug == _editorialSlug(category)) {
      bySlug[category.slug] = category;
    }
  }

  return [
    for (final slug in quickAccessCategorySlugs)
      if (bySlug[slug] case final Category category) category,
  ];
}
