class ConversationSummary {
  const ConversationSummary({
    required this.id,
    required this.contextType,
    required this.contextId,
    required this.title,
    required this.preview,
    required this.lastMessageAt,
    required this.unreadCount,
    this.requestId,
  });

  final String id;
  final String contextType;
  final String contextId;
  final String? requestId;
  final String title;
  final String preview;
  final DateTime lastMessageAt;
  final int unreadCount;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.messageType,
    required this.body,
    required this.createdAt,
    required this.isMine,
    this.attachmentPath,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String messageType;
  final String? body;
  final String? attachmentPath;
  final DateTime createdAt;
  final bool isMine;
}
