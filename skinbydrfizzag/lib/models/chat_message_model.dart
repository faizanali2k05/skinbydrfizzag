class ChatMessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String senderRole;
  final String text;
  final String messageType; // 'text', 'image', 'audio', 'file'
  final String? fileUrl;
  final DateTime? createdAt;

  ChatMessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.text,
    this.messageType = 'text',
    this.fileUrl,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'sender_id': senderId,
      'sender_name': senderName,
      'sender_role': senderRole,
      'text': text,
      'message_type': messageType,
      'file_url': fileUrl,
      'created_at': createdAt ?? DateTime.now(),
    };
  }

  factory ChatMessageModel.fromMap(
    Map<String, dynamic> data,
    String documentId,
  ) {
    return ChatMessageModel(
      id: documentId,
      senderId: data['sender_id'] ?? data['senderId'] ?? '',
      senderName: data['sender_name'] ?? data['senderName'] ?? '',
      senderRole: data['sender_role'] ?? data['senderRole'] ?? '',
      text: data['text'] ?? '',
      messageType: data['message_type'] ?? data['messageType'] ?? 'text',
      fileUrl: data['file_url'] ?? data['fileUrl'],
      createdAt: data['created_at'] != null
          ? (data['created_at'] is String
                ? DateTime.parse(data['created_at'])
                : data['created_at'] is DateTime
                ? data['created_at'] as DateTime
                : null)
          : null,
    );
  }
}
