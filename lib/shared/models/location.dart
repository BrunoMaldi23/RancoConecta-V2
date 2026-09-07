class Location {
  const Location({
    required this.id,
    required this.communeId,
    required this.name,
    required this.slug,
    this.communeName,
    this.providerCount = 0,
  });

  final String id;
  final String communeId;
  final String name;
  final String slug;

  final String? communeName;
  final int providerCount;

  Location copyWith({
    String? id,
    String? communeId,
    String? name,
    String? slug,
    String? communeName,
    int? providerCount,
  }) {
    return Location(
      id: id ?? this.id,
      communeId: communeId ?? this.communeId,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      communeName: communeName ?? this.communeName,
      providerCount: providerCount ?? this.providerCount,
    );
  }
}