import '../../../shared/models/category.dart';

class CategoryDto {
  const CategoryDto({
    required this.id,
    required this.name,
    required this.slug,
    required this.iconKey,
    required this.themeKey,
  });

  factory CategoryDto.fromJson(Map<String, dynamic> json) {
    return CategoryDto(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      iconKey: json['icon_key'] as String,
      themeKey: json['theme_key'] as String,
    );
  }

  final String id;
  final String name;
  final String slug;
  final String iconKey;
  final String themeKey;

  Category toDomain() {
    return Category(
      id: id,
      name: name,
      slug: slug,
      iconKey: iconKey,
      themeKey: themeKey,
    );
  }
}

class SubcategoryDto {
  const SubcategoryDto({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.slug,
    required this.description,
    required this.iconKey,
  });

  factory SubcategoryDto.fromJson(Map<String, dynamic> json) {
    return SubcategoryDto(
      id: json['id'] as String,
      categoryId: json['category_id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      description: json['description'] as String?,
      iconKey: json['icon_key'] as String,
    );
  }

  final String id;
  final String categoryId;
  final String name;
  final String slug;
  final String? description;
  final String iconKey;

  Subcategory toDomain() {
    return Subcategory(
      id: id,
      categoryId: categoryId,
      name: name,
      slug: slug,
      description: description,
      iconKey: iconKey,
    );
  }
}
