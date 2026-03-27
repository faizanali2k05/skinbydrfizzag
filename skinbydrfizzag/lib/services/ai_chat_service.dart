import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat_message_model.dart';

class AiChatService {
  // Python backend hosted on Render
  static const String baseUrl = 'https://skinbydrfizzag.onrender.com';

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
        .insert({
          'user_id': userId,
          'title': 'AI Skin Consultation',
        })
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
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'message': message}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        aiText =
            data['response'] ?? 'I am sorry, I could not understand that.';
      } else {
        aiText = 'Error: Server returned ${response.statusCode}';
      }
    } catch (e) {
      aiText = 'Error: ${e.toString()}';
    }

    // Store AI response
    await _supabase.from('ai_messages').insert({
      'conversation_id': conversationId,
      'sender': 'ai',
      'message': aiText,
    });

    // AI messages are now stored but won't trigger internal notifications

    return (response: aiText, conversationId: conversationId);
  }

  // Backwards-compatible method if you only need the AI response text.
  Future<String> getAiResponse(String message, {required String userId}) async {
    final result = await sendAndStore(userId: userId, message: message);
    return result.response;
  }

  /// Admin: Fetch all AI conversations including user names
  Future<List<Map<String, dynamic>>> getAllAiConversations() async {
    try {
      final List<dynamic> rows = await _supabase
          .from('ai_conversations')
          .select('*, profiles(full_name)')
          .order('updated_at', ascending: false);
      
      return rows.map((row) => row as Map<String, dynamic>).toList();
    } catch (_) {
      return [];
    }
  }

  /// Admin: Fetch messages for a specific AI conversation
  Future<List<ChatMessageModel>> getAiMessages(String conversationId, String userId) async {
    try {
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
          senderName: isUser ? 'User' : 'AI Agent',
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
}


