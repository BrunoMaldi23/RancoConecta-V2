import '../../../shared/models/location.dart';

class LocationDto {
  const LocationDto({
    required this.id,
    required this.communeId,
    required this.name,
    required this.slug,
  });

  factory LocationDto.fromJson(Map<String, dynamic> json) {
    return LocationDto(
      id: json['id'] as String,
      communeId: json['commune_id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
    );
  }

  final String id;
  final String communeId;
  final String name;
  final String slug;

  Location toDomain() {
    return Location(id: id, communeId: communeId, name: name, slug: slug);
  }
}
