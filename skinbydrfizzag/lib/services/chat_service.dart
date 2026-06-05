import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import '../models/chat_message_model.dart';
import '../models/chat_conversation_model.dart';
import '../constants/config.dart';

/// Chat Service backed by Supabase tables `conversations` and `messages`.
class ChatService {
  final _supabase = Supabase.instance.client;

  // Backend base URL (same as AI backend)
  static const String _backendBaseUrl = AppConfig.backendBaseUrl;

  String? get currentUserId => _supabase.auth.currentUser?.id;

  // ==================== Conversation Management ======================

  Future<String?> getOrCreateConversation(String userId, String adminId) async {
    try {
      // Find any existing human conversation for this user.
      // This prevents duplicate app/whatsapp threads for the same person.
      final data = await _supabase
          .from('conversations')
          .select('id')
          .eq('user_id', userId)
          .neq('platform', 'ai_agent')
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (data != null) {
        return data['id'] as String;
      }

      final List<dynamic> insert = await _supabase.from('conversations').insert(
        {'user_id': userId, 'admin_id': adminId, 'platform': 'app'},
      ).select();

      if (insert.isEmpty) {
        throw Exception('Conversation creation returned empty result');
      }
      return insert.first['id'] as String;
    } catch (e) {
      debugPrint('Error in getOrCreateConversation: $e');
      return null;
    }
  }

  Stream<List<ChatConversationModel>> getUserConversationsStream(
    String userId,
  ) {
    // Filter server-side by user_id so each user only subscribes to their own
    // conversations (avoids streaming the entire table and filtering client-side).
    return _supabase
        .from('conversations')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('updated_at', ascending: false)
        .map((event) {
          return event
              .map((e) => ChatConversationModel.fromMap(e, e['id'] as String))
              .toList();
        });
  }

  Stream<List<ChatConversationModel>> getAdminConversationsStream(
    String adminId,
  ) {
    return _supabase
        .from('conversations')
        .stream(primaryKey: ['id'])
        .order('updated_at', ascending: false)
        .map((event) {
          debugPrint(
            'ChatService: Admin conversations stream received ${event.length} conversations for admin: $adminId',
          );
          return event
              .map((e) => ChatConversationModel.fromMap(e, e['id'] as String))
              .where((c) => c.platform != 'ai_agent')
              .toList();
        });
  }

  Future<ChatConversationModel?> getConversationById(
    String conversationId,
  ) async {
    try {
      final data = await _supabase
          .from('conversations')
          .select()
          .eq('id', conversationId)
          .single();
      return ChatConversationModel.fromMap(data, data['id'] as String);
    } catch (e) {
      return null;
    }
  }

  // ==================== Messages (Real-time) ======================

  Stream<List<ChatMessageModel>> getConversationMessagesStream(
    String conversationId,
  ) {
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true)
        .map((event) {
          debugPrint(
            'ChatService: Messages stream received ${event.length} messages for conversation: $conversationId',
          );
          return event
              .map((e) => ChatMessageModel.fromMap(e, e['id'] as String))
              .toList();
        });
  }

  Future<ChatMessageModel?> getMessageById(
    String conversationId,
    String messageId,
  ) async {
    try {
      final data = await _supabase
          .from('messages')
          .select()
          .eq('id', messageId)
          .eq('conversation_id', conversationId)
          .single();
      return ChatMessageModel.fromMap(data, data['id'] as String);
    } catch (e) {
      return null;
    }
  }

  // ==================== Send Message ======================

  Future<String?> sendMessage({
    required String conversationId,
    required String text,
    required String senderId,
    required String senderName,
    required String senderRole,
    String messageType = 'text',
    String? fileUrl,
  }) async {
    if (text.trim().isEmpty && fileUrl == null) {
      return 'Message cannot be empty.';
    }

    try {
      // Detect if this conversation is a WhatsApp conversation
      final conv = await _supabase
          .from('conversations')
          .select('platform, user_id')
          .eq('id', conversationId)
          .maybeSingle();

      final platform = conv != null
          ? (conv['platform'] as String? ?? 'app')
          : 'app';
      final userIdForConv = conv != null ? conv['user_id'] as String? : null;

      // For WhatsApp conversations, admin replies must go via backend so that
      // the user receives messages on WhatsApp and messages are stored server-side.
      if (platform == 'whatsapp' && senderRole == 'admin') {
        if (userIdForConv == null) {
          return 'Conversation is missing user information.';
        }

        // Get recipient phone
        final userProfile = await _supabase
            .from('profiles')
            .select('phone')
            .eq('id', userIdForConv)
            .maybeSingle();

        final phone = userProfile != null
            ? userProfile['phone'] as String?
            : null;
        if (phone == null || phone.isEmpty) {
          return 'User does not have a WhatsApp phone number on file.';
        }

        try {
          final resolvedFileName = fileUrl != null
              ? p.basename(Uri.tryParse(fileUrl)?.path ?? fileUrl)
              : null;
          final accessToken =
              _supabase.auth.currentSession?.accessToken;
          if (accessToken == null) {
            return 'Admin session expired. Please sign in again.';
          }
          final resp = await http.post(
            Uri.parse('$_backendBaseUrl/send-message'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $accessToken',
            },
            body: jsonEncode({
              'conversation_id': conversationId,
              'message': text.trim(),
              'message_type': messageType,
              'file_url': fileUrl,
              'file_name': resolvedFileName,
              'phone': phone,
            }),
          );

          if (resp.statusCode != 200) {
            // Surface the backend's real reason instead of a bare status code.
            String reason = 'status ${resp.statusCode}';
            String? hint;
            try {
              final body = jsonDecode(resp.body) as Map<String, dynamic>;
              if (body['error'] != null) reason = body['error'].toString();
              if (body['hint'] != null &&
                  body['hint'].toString().isNotEmpty) {
                hint = body['hint'].toString();
              }
            } catch (_) {}

            if (resp.statusCode == 401) {
              return 'Your admin session has expired. Please sign out and sign in again.';
            }
            return hint != null ? '$reason\n\n$hint' : 'Send failed: $reason';
          }
        } catch (e) {
          return 'Failed to send WhatsApp message: $e';
        }

        // Message will be inserted by the backend; no local insert here.
        return null;
      }

      await _supabase.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': senderId,
        'sender_name': senderName,
        'sender_role': senderRole,
        'text': text.trim(),
        'message_type': messageType,
        'file_url': fileUrl,
      }).select();

      debugPrint(
        'ChatService: Message sent successfully from $senderId to conversation $conversationId',
      );

      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> uploadFile(String bucket, String path, dynamic file) async {
    try {
      Uint8List bytes;
      if (file is Uint8List) {
        bytes = file;
      } else if (file is List<int>) {
        bytes = Uint8List.fromList(file);
      } else {
        final reader = file as dynamic;
        final dynamic raw = await reader.readAsBytes();
        bytes = raw is Uint8List ? raw : Uint8List.fromList(raw as List<int>);
      }

      final contentType = _guessContentType(path);

      await _supabase.storage
          .from(bucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              cacheControl: '3600',
              upsert: true,
              contentType: contentType,
            ),
          );

      final String publicUrl = _supabase.storage
          .from(bucket)
          .getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading file: $e');
      return null;
    }
  }

  String _guessContentType(String path) {
    final ext = p.extension(path).toLowerCase().replaceFirst('.', '');
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'mp3':
        return 'audio/mpeg';
      case 'm4a':
        return 'audio/mp4';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'ogg':
        return 'audio/ogg';
      case 'wav':
        return 'audio/wav';
      case 'webm':
        return 'audio/webm';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  // ==================== Delete Message ======================

  Future<String?> deleteMessage(String conversationId, String messageId) async {
    try {
      await _supabase
          .from('messages')
          .delete()
          .eq('id', messageId)
          .eq('conversation_id', conversationId);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // ==================== Unread Count (Optional) ======================

  Future<int> getUnreadCountForConversation(
    String conversationId,
    String userId,
  ) async {
    try {
      final response = await _supabase
          .from('messages')
          .select('id')
          .eq('conversation_id', conversationId)
          .eq('is_read', false)
          .neq('sender_id', userId);
      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }

  Stream<List<ChatConversationModel>> getDoctorConversationsStream(
    String doctorId,
  ) {
    return getAdminConversationsStream(doctorId);
  }

  Future<List<ChatConversationModel>> getDoctorConversations(
    String doctorId,
  ) async {
    try {
      final List<dynamic> data = await _supabase
          .from('conversations')
          .select()
          .eq('admin_id', doctorId)
          .order('updated_at', ascending: false);
      return data
          .map((e) => ChatConversationModel.fromMap(e, e['id'] as String))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> markMessagesAsRead(String conversationId) async {
    final uid = currentUserId;
    if (uid == null || uid.isEmpty) {
      // Without a signed-in user we cannot scope the update; skipping the
      // call avoids accidentally marking the sender's own messages as read
      // on behalf of an empty UID.
      return;
    }
    try {
      // 1. Mark all messages from other senders as read
      await _supabase
          .from('messages')
          .update({'is_read': true})
          .eq('conversation_id', conversationId)
          .neq('sender_id', uid);

      // 2. Reset unread count for the conversation
      await _supabase
          .from('conversations')
          .update({'unread_count': 0})
          .eq('id', conversationId);

      // 3. Clear chat notification badges for this opened conversation.
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', uid)
          .eq('conversation_id', conversationId)
          .eq('type', 'message');
    } catch (e) {
      debugPrint('Error in markMessagesAsRead: $e');
    }
  }

  Stream<List<ChatMessageModel>> getMessagesStream(String conversationId) {
    return getConversationMessagesStream(conversationId);
  }

  Future<List<ChatMessageModel>> getMessages(String conversationId) async {
    try {
      final List<dynamic> data = await _supabase
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);
      return data
          .map((e) => ChatMessageModel.fromMap(e, e['id'] as String))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<int> getTotalUnreadCount(String userId) async {
    try {
      final conversations = await getUserConversationsStream(userId).first;
      int total = 0;
      for (var conversation in conversations) {
        total += await getUnreadCountForConversation(conversation.id, userId);
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  Stream<int> getUserUnreadCountStream(String userId) {
    return getUserConversationsStream(userId).map((conversations) {
      return conversations.fold<int>(0, (sum, c) {
        // Only count as unread if the last sender is NOT the user
        if (c.lastSenderId.isNotEmpty && c.lastSenderId != userId) {
          return sum + c.unreadCount;
        }
        return sum;
      });
    });
  }

  /// Streams the total number of unread messages across all conversations
  /// where the admin is the recipient (i.e., user sent the last message).
  Stream<int> getAdminTotalUnreadStream(String adminId) {
    return getAdminConversationsStream(adminId).map((conversations) {
      return conversations.fold<int>(0, (sum, c) {
        // Only count as unread if the last sender is NOT the admin
        if (c.lastSenderId.isNotEmpty && c.lastSenderId != adminId) {
          return sum + c.unreadCount;
        }
        return sum;
      });
    });
  }

  Future<void> updateConversationUserProfile(
    String conversationId,
    String userName,
  ) async {
    // There is no username/display_name column in conversations table.
    // User names are fetched from the profiles table.
    try {
      // This method was trying to update a UUID field with a String name.
      // We'll leave it empty or update something valid if needed.
    } catch (_) {}
  }

  Future<void> forceRefreshConversation(String conversationId) async {
    try {
      await _supabase
          .from('conversations')
          .update({'updated_at': DateTime.now().toIso8601String()})
          .eq('id', conversationId);
    } catch (_) {}
  }
}
