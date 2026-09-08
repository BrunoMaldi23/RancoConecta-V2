class BusinessReview {
  const BusinessReview({
    required this.id,
    required this.businessId,
    required this.userId,
    required this.rating,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.comment,
  });

  factory BusinessReview.fromJson(
    Map<String, dynamic> json,
  ) {
    return BusinessReview(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      userId: json['user_id'] as String,
      rating: (json['rating'] as num).toInt(),
      comment: json['comment'] as String?,
      status: json['status'] as String? ?? 'published',
      createdAt: DateTime.parse(
        json['created_at'] as String,
      ),
      updatedAt: DateTime.parse(
        json['updated_at'] as String,
      ),
    );
  }

  final String id;
  final String businessId;
  final String userId;
  final int rating;
  final String? comment;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
}
