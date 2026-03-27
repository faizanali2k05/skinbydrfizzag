class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String type;
  final String appointmentId;
  final String conversationId;
  final bool isRead;
  final DateTime? createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    this.appointmentId = '',
    this.conversationId = '',
    this.isRead = false,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'title': title,
      'message': message,
      'type': type,
      'appointment_id': appointmentId,
      'conversation_id': conversationId,
      'is_read': isRead,
      'created_at': createdAt ?? DateTime.now(),
    };
  }

  factory NotificationModel.fromMap(Map<String, dynamic> data, String documentId) {
    return NotificationModel(
      id: documentId,
      userId: data['user_id'] ?? data['userId'] ?? '',
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      type: data['type'] ?? 'appointment',
      appointmentId: data['appointment_id'] ?? data['appointmentId'] ?? '',
      conversationId: data['conversation_id'] ?? data['conversationId'] ?? '',
      isRead: data['is_read'] ?? data['isRead'] ?? false,
      createdAt: data['created_at'] != null
          ? DateTime.parse(data['created_at'].toString())
          : null,
    );
  }
}