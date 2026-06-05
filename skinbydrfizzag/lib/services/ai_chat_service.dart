import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

import '../models/chat_message_model.dart';
import '../constants/config.dart';

class AiChatService {
  // Python backend hosted on Render
  static const String baseUrl = AppConfig.backendBaseUrl;

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Load the latest AI conversation and messages for a given user.
  /// Returns a record with optional conversationId and a list of ChatMessageModel.
  Future<({String? conversationId, List<ChatMessageModel> messages})>
  loadConversation(String userId) async {
    try {
      final convRes = await _supabase
          .from('ai_conversations')
          .select('id')
          .eq('user_id', userId)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (convRes == null || convRes['id'] == null) {
        return (conversationId: null, messages: <ChatMessageModel>[]);
      }

      final conversationId = convRes['id'] as String;

      final List<dynamic> rows = await _supabase
          .from('ai_messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);

      final messages = rows.map((row) {
        final sender = row['sender'] as String? ?? 'ai';
        final isUser = sender == 'user';
        return ChatMessageModel(
          id: row['id'] as String,
          senderId: isUser ? userId : 'ai',
          senderName: isUser ? 'You' : 'AI Consultant',
          senderRole: sender,
          text: row['message'] as String? ?? '',
          createdAt: row['created_at'] != null
              ? DateTime.parse(row['created_at'] as String)
              : null,
        );
      }).toList();

      return (conversationId: conversationId, messages: messages);
    } catch (_) {
      return (conversationId: null, messages: <ChatMessageModel>[]);
    }
  }

  Future<String> _ensureConversation(String userId) async {
    final existing = await _supabase
        .from('ai_conversations')
        .select('id')
        .eq('user_id', userId)
        .order('updated_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (existing != null && existing['id'] != null) {
      return existing['id'] as String;
    }

    final List<dynamic> inserted = await _supabase
        .from('ai_conversations')
        .insert({'user_id': userId, 'title': 'AI Skin Consultation'})
        .select();

    return inserted.first['id'] as String;
  }

  /// Sends a message to the AI backend, and persists both user + AI messages
  /// to Supabase. Returns the AI response text and conversation id.
  Future<({String response, String conversationId})> sendAndStore({
    required String userId,
    required String message,
  }) async {
    final conversationId = await _ensureConversation(userId);

    // Store user message
    await _supabase.from('ai_messages').insert({
      'conversation_id': conversationId,
      'sender': 'user',
      'message': message,
    });

    String aiText;
    bool aiCallSucceeded = false;
    try {
      final profile = await _supabase
          .from('profiles')
          .select('full_name, email, phone')
          .eq('id', userId)
          .maybeSingle();
      final userName = _profileDisplayName(profile, fallback: 'User');
      final response = await http.post(
        Uri.parse('$baseUrl/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message': message,
          'user_id': userId,
          'user_name': userName,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        aiText = data['response'] ?? 'I am sorry, I could not understand that.';
        aiCallSucceeded = true;
      } else {
        aiText = 'Error: Server returned ${response.statusCode}';
      }
    } catch (e) {
      aiText = 'Error: ${e.toString()}';
    }

    // Only persist the AI reply when the model actually responded — otherwise
    // we'd pollute history with transient connectivity errors that re-appear
    // every time the conversation is re-opened.
    if (aiCallSucceeded) {
      await _supabase.from('ai_messages').insert({
        'conversation_id': conversationId,
        'sender': 'ai',
        'message': aiText,
      });
    }

    // Bump the conversation's updated_at so the admin's AI-conversations list
    // (which is ordered by updated_at) reflects recent activity.
    try {
      await _supabase
          .from('ai_conversations')
          .update({'updated_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', conversationId);
    } catch (e) {
      debugPrint('AiChatService: Failed to bump conversation updated_at: $e');
    }

    return (response: aiText, conversationId: conversationId);
  }

  // Backwards-compatible method if you only need the AI response text.
  Future<String> getAiResponse(String message, {required String userId}) async {
    final result = await sendAndStore(userId: userId, message: message);
    return result.response;
  }

  Future<List<Map<String, dynamic>>> getAllAiConversations() async {
    try {
      final List<dynamic> rows = await _supabase
          .from('ai_conversations')
          .select('*, profiles:user_id(full_name, email, phone)')
          .order('updated_at', ascending: false);

      debugPrint(
        'AiChatService: Successfully fetched ${rows.length} conversations.',
      );
      return rows.map((row) => row as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('AiChatService: Error in getAllAiConversations: $e');

      // Fallback: try fetching without profiles relation
      try {
        final List<dynamic> rows = await _supabase
            .from('ai_conversations')
            .select('*')
            .order('updated_at', ascending: false);
        debugPrint(
          'AiChatService: Fallback fetched ${rows.length} conversations.',
        );
        return rows.map((row) => row as Map<String, dynamic>).toList();
      } catch (e2) {
        debugPrint('AiChatService: Fallback also failed: $e2');
        return [];
      }
    }
  }

  /// Admin: Fetch messages for a specific AI conversation
  Future<List<ChatMessageModel>> getAiMessages(
    String conversationId,
    String userId,
  ) async {
    try {
      String userName = 'User';
      final profile = await _supabase
          .from('profiles')
          .select('full_name, email, phone')
          .eq('id', userId)
          .maybeSingle();
      userName = _profileDisplayName(profile, fallback: 'User');

      final List<dynamic> rows = await _supabase
          .from('ai_messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);

      return rows.map((row) {
        final sender = row['sender'] as String? ?? 'ai';
        final isUser = sender == 'user';
        return ChatMessageModel(
          id: row['id'] as String,
          senderId: isUser ? userId : 'ai',
          senderName: isUser ? userName : 'AI Agent',
          senderRole: sender,
          text: row['message'] as String? ?? '',
          createdAt: row['created_at'] != null
              ? DateTime.parse(row['created_at'] as String)
              : null,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  String _profileDisplayName(
    Map<String, dynamic>? profile, {
    required String fallback,
  }) {
    final fullName = (profile?['full_name'] as String? ?? '').trim();
    if (fullName.isNotEmpty && !fullName.toLowerCase().startsWith('wa user')) {
      return fullName;
    }
    final email = (profile?['email'] as String? ?? '').trim();
    if (email.isNotEmpty) return email.split('@').first;
    final phone = (profile?['phone'] as String? ?? '').trim();
    if (phone.isNotEmpty) return phone;
    return fallback;
  }
}
