class RequestAttachment {
  const RequestAttachment({
    required this.id,
    required this.requestId,
    required this.storagePath,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.createdAt,
  });

  final String id;
  final String requestId;
  final String storagePath;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final DateTime createdAt;

  bool get isImage => mimeType.startsWith('image/');
  bool get isPdf => mimeType == 'application/pdf';
}
