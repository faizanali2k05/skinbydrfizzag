import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/user_model.dart';
import '../../models/chat_conversation_model.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../chat/unified_chat_screen.dart';
import 'ai_agent_record_screen.dart';


class AdminChatManagerScreen extends StatefulWidget {
  const AdminChatManagerScreen({super.key});

  @override
  State<AdminChatManagerScreen> createState() => _AdminChatManagerScreenState();
}

class _AdminChatManagerScreenState extends State<AdminChatManagerScreen> {
  final ChatService _chatService = ChatService();

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final adminId = authService.currentUserId ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Chat',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),

        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      // Show all users from the app. For each user, also fetch their conversation
      // with admin (if any) so unread counts can be shown.
      body: StreamBuilder<List<UserModel>>(
        stream: authService.getAllProfilesStream(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (userSnapshot.hasError) {
            return Center(child: Text('Error: ${userSnapshot.error}'));
          }

          // Exclude the admin themselves
          final allUsers = (userSnapshot.data ?? [])
              .where((u) => u.uid != adminId && u.role != 'admin')
              .toList();

          if (allUsers.isEmpty) {
            return const Center(child: Text('No users found.'));
          }

          // For unread counts, also stream conversations so the badges update in real-time
          return StreamBuilder<List<ChatConversationModel>>(
            stream: _chatService.getAdminConversationsStream(adminId),
            builder: (context, convSnapshot) {
              final conversations = convSnapshot.data ?? [];

              // Build a map of userId -> conversation preferring app conversations over WhatsApp
              // This allows same user to have both types but app takes precedence in the display
              final Map<String, ChatConversationModel> convByUser = {};
              for (var c in conversations) {
                final existing = convByUser[c.userId];
                // If no existing entry, add this conversation
                // If existing is WhatsApp and current is app, replace (app takes priority)
                // If existing is app and current is WhatsApp, keep existing (app takes priority)
                if (existing == null) {
                  convByUser[c.userId] = c;
                } else if (existing.platform == 'whatsapp' && (c.platform == null || c.platform == 'app')) {
                  convByUser[c.userId] = c;
                }
              }

              return Column(
                children: [
                  _buildAiAgentLink(context),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: allUsers.length,
                      itemBuilder: (context, index) {
                        final user = allUsers[index];
                        final conversation = convByUser[user.uid];
                        return _buildUserChatCard(
                          context,
                          adminId: adminId,
                          user: user,
                          conversation: conversation,
                        );
                      },
                    ),
                  ),
                ],
              );

            },
          );
        },
      ),
    );
  }

  Widget _buildUserChatCard(
    BuildContext context, {
    required String adminId,
    required UserModel user,
    ChatConversationModel? conversation,
  }) {
    final unreadCount = conversation?.unreadCount ?? 0;
    final lastMessage = conversation?.lastMessage ?? '';
    final hasChat = lastMessage.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary.withAlpha(26),
              radius: 25,
              child: Text(
                (user.name.isNotEmpty ? user.name[0] : '?').toUpperCase(),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          user.name.isNotEmpty ? user.name : user.email,
          style: TextStyle(
            fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Row(
          children: [
            Expanded(
              child: Text(
                hasChat ? lastMessage : 'Tap to start a conversation',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: unreadCount > 0 ? Colors.black87 : Colors.grey,
                  fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                  fontStyle: hasChat ? FontStyle.normal : FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
        trailing: unreadCount > 0
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
        onTap: () async {
          // If no conversation exists yet, create one when admin taps
          String? conversationId = conversation?.id;
          conversationId ??= await _chatService.getOrCreateConversation(
            user.uid,
            adminId,
          );

          if (!context.mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UnifiedChatScreen(
                otherUserId: user.uid,
                otherUserName: user.name.isNotEmpty ? user.name : user.email,
                conversationId: conversationId,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAiAgentLink(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Colors.teal, Colors.tealAccent]),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.teal.withAlpha(51), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: ListTile(
        leading: const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.smart_toy, color: Colors.teal)),
        title: const Text("AI Agent Conversations", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: const Text("View recordings of all AI chats", style: TextStyle(color: Colors.white70, fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const AiAgentRecordScreen()));
        },
      ),
    );
  }
}

