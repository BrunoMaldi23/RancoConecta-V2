class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.entityType,
    this.entityId,
    this.deepLink,
    this.readAt,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final String? entityType;
  final String? entityId;
  final String? deepLink;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isUnread => readAt == null;
}
