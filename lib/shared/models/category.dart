class Category {
  const Category({
    required this.id,
    required this.name,
    required this.slug,
    required this.iconKey,
    required this.themeKey,
  });

  final String id;
  final String name;
  final String slug;
  final String iconKey;
  final String themeKey;
}

class Subcategory {
  const Subcategory({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.slug,
    required this.description,
    required this.iconKey,
  });

  final String id;
  final String categoryId;
  final String name;
  final String slug;
  final String? description;
  final String iconKey;
}
