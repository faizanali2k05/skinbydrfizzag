class ChatConversationModel {
  final String id;
  final String userId;
  final String adminId;
  final String lastMessage;
  final String lastSenderId;
  final int unreadCount;
  final DateTime? updatedAt;
  final DateTime? createdAt;
  final String? platform; // 'app' or 'whatsapp'

  ChatConversationModel({
    required this.id,
    required this.userId,
    required this.adminId,
    this.lastMessage = '',
    this.lastSenderId = '',
    this.unreadCount = 0,
    this.updatedAt,
    this.createdAt,
    this.platform,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'adminId': adminId,
      'lastMessage': lastMessage,
      'lastSenderId': lastSenderId,
      'unreadCount': unreadCount,
      'updatedAt': updatedAt ?? DateTime.now(),
      'createdAt': createdAt ?? DateTime.now(),
      'platform': platform,
    };
  }

  factory ChatConversationModel.fromMap(Map<String, dynamic> data, String documentId) {
    return ChatConversationModel(
      id: documentId,
      userId: data['userId'] ?? data['user_id'] ?? '',
      adminId: data['adminId'] ?? data['admin_id'] ?? '',
      lastMessage: data['lastMessage'] ?? data['last_message'] ?? '',
      lastSenderId: data['lastSenderId'] ?? data['last_sender_id'] ?? '',
      unreadCount: data['unreadCount'] ?? data['unread_count'] ?? 0,
      updatedAt: data['updated_at'] != null
          ? DateTime.tryParse(data['updated_at'].toString())
          : data['updatedAt'] != null
              ? DateTime.tryParse(data['updatedAt'].toString())
              : null,
      createdAt: data['created_at'] != null
          ? DateTime.tryParse(data['created_at'].toString())
          : data['createdAt'] != null
              ? DateTime.tryParse(data['createdAt'].toString())
              : null,
      platform: data['platform'] as String?,
    );
  }
}