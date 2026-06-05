import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../constants/styles.dart';
import '../../models/chat_conversation_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/soft_card.dart';
import '../chat/unified_chat_screen.dart';
import 'ai_agent_record_screen.dart';

class AdminChatManagerScreen extends StatefulWidget {
  const AdminChatManagerScreen({super.key});

  @override
  State<AdminChatManagerScreen> createState() => _AdminChatManagerScreenState();
}

class _AdminChatManagerScreenState extends State<AdminChatManagerScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();
  Stream<List<UserModel>>? _usersStream;
  Stream<List<ChatConversationModel>>? _conversationsStream;
  String? _adminId;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    final authService = Provider.of<AuthService>(context, listen: false);
    _adminId = authService.currentUserId;
    if (_adminId != null) {
      _usersStream = authService.getAllProfilesStream();
      _conversationsStream = _chatService.getAdminConversationsStream(
        _adminId!,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_adminId == null ||
        _usersStream == null ||
        _conversationsStream == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final adminId = _adminId!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Conversations'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (value) =>
                  setState(() => _searchQuery = value.trim().toLowerCase()),
              decoration:
                  AppStyles.inputDecoration(
                    'Search patients by name, phone or email',
                    prefixIcon: Icons.search,
                  ).copyWith(
                    suffixIcon: _searchQuery.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          ),
                  ),
            ),
          ),
        ),
      ),
      // Show all users from the app. For each user, also fetch their conversation
      // with admin (if any) so unread counts can be shown.
      body: StreamBuilder<List<UserModel>>(
        stream: _usersStream,
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
              .where((u) {
                if (_searchQuery.isEmpty) return true;
                final userName = _displayUserName(u).toLowerCase();
                return userName.contains(_searchQuery) ||
                    u.phone.toLowerCase().contains(_searchQuery) ||
                    u.email.toLowerCase().contains(_searchQuery);
              })
              .toList();

          if (allUsers.isEmpty) {
            return const EmptyState(
              icon: Icons.people_outline_rounded,
              title: 'No patients yet',
              message:
                  'Patients will appear here once they sign up '
                  'or message you on WhatsApp.',
            );
          }

          // For unread counts, also stream conversations so the badges update in real-time
          return StreamBuilder<List<ChatConversationModel>>(
            stream: _conversationsStream,
            builder: (context, convSnapshot) {
              final conversations = convSnapshot.data ?? [];

              final Map<String, ChatConversationModel> convByUser = {};
              for (var c in conversations) {
                // Since the stream orders by updated_at descending, the first one we see is the most recent
                if (!convByUser.containsKey(c.userId)) {
                  convByUser[c.userId] = c;
                }
              }

              return Column(
                children: [
                  _buildAiAgentLink(context),
                  const SizedBox(height: 6),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: allUsers.length,
                      itemBuilder: (context, index) {
                        final user = allUsers[index];
                        final conversation = convByUser[user.uid];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildUserChatCard(
                            context,
                            adminId: adminId,
                            user: user,
                            conversation: conversation,
                          ),
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
    final initial = user.name.isNotEmpty ? user.name[0].toUpperCase() : '?';
    final isWhatsApp =
        (conversation?.platform ?? 'app').toLowerCase() == 'whatsapp';

    return SoftCard(
      onTap: () async {
        String? conversationId = conversation?.id;
        conversationId ??= await _chatService.getOrCreateConversation(
          user.uid,
          adminId,
        );
        if (!context.mounted) return;
        if (conversationId != null) {
          await _chatService.markMessagesAsRead(conversationId);
        }
        if (!context.mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UnifiedChatScreen(
              otherUserId: user.uid,
              otherUserName: _displayUserName(user),
              conversationId: conversationId,
            ),
          ),
        );
      },
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.primaryGradient,
                ),
                padding: const EdgeInsets.all(2),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surface,
                    image: user.photoUrl.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(user.photoUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: user.photoUrl.isEmpty
                      ? Text(
                          initial,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        )
                      : null,
                ),
              ),
              if (isWhatsApp)
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface, width: 2),
                    ),
                    child: const Icon(
                      Icons.chat_rounded,
                      size: 9,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _displayUserName(user),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: unreadCount > 0
                              ? FontWeight.w800
                              : FontWeight.w700,
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (conversation?.updatedAt != null)
                      Text(
                        _shortTime(conversation!.updatedAt!),
                        style: AppStyles.bodySmall.copyWith(
                          color: unreadCount > 0
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontWeight: unreadCount > 0
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        hasChat
                            ? lastMessage
                            : (_isUnregisteredUser(user)
                                  ? 'WhatsApp-only patient'
                                  : 'Tap to start a conversation'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: unreadCount > 0
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                          fontWeight: unreadCount > 0
                              ? FontWeight.w600
                              : FontWeight.normal,
                          fontSize: 13,
                          fontStyle: hasChat
                              ? FontStyle.normal
                              : FontStyle.italic,
                        ),
                      ),
                    ),
                    if (unreadCount > 0)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _shortTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) {
      final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final p = dt.hour >= 12 ? 'PM' : 'AM';
      return '$h:${dt.minute.toString().padLeft(2, '0')} $p';
    }
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.day}/${dt.month}';
  }

  Widget _buildAiAgentLink(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.teal, Colors.tealAccent],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withAlpha(51),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.white,
          child: Icon(Icons.smart_toy, color: Colors.teal),
        ),
        title: const Text(
          "AI Agent Conversations",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: const Text(
          "View recordings of all AI chats",
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.white,
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AiAgentRecordScreen(),
            ),
          );
        },
      ),
    );
  }

  bool _isUnregisteredUser(UserModel user) {
    return user.email.trim().isEmpty;
  }

  String _displayUserName(UserModel user) {
    final base = user.name.trim().isNotEmpty
        ? user.name.trim()
        : user.displayName.trim();

    if (base.isEmpty || base.toLowerCase().startsWith('wa user')) {
      if (user.phone.trim().isNotEmpty) return user.phone.trim();
      if (user.email.trim().isNotEmpty) return user.email.split('@').first;
      return 'User';
    }

    if (RegExp(r'^\+?\d+$').hasMatch(base)) {
      if (user.phone.trim().isNotEmpty) return user.phone.trim();
      if (user.email.trim().isNotEmpty) return user.email.split('@').first;
      return 'User';
    }

    return base;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
