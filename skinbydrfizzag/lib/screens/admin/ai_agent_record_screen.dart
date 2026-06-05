import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../constants/colors.dart';
import '../../constants/styles.dart';
import '../../models/chat_message_model.dart';
import '../../services/ai_chat_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/soft_card.dart';

class AiAgentRecordScreen extends StatefulWidget {
  const AiAgentRecordScreen({super.key});

  @override
  State<AiAgentRecordScreen> createState() => _AiAgentRecordScreenState();
}

class _AiAgentRecordScreenState extends State<AiAgentRecordScreen> {
  final AiChatService _aiChatService = AiChatService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _conversations = [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final results = await _aiChatService.getAllAiConversations();
    if (mounted) {
      setState(() {
        _conversations = results;
        _isLoading = false;
      });
    }
  }

  String _initial(String name) =>
      name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('AI Agent Records'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: () {
              setState(() => _isLoading = true);
              _fetch();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _conversations.isEmpty
          ? const EmptyState(
              icon: Icons.smart_toy_outlined,
              title: 'No AI conversations yet',
              message:
                  'Once patients chat with the AI consultant, '
                  'their sessions will appear here for review.',
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: _conversations.length,
              itemBuilder: (context, index) {
                final conv = _conversations[index];
                final profile = conv['profiles'] as Map<String, dynamic>?;
                final userName = _profileName(profile);
                final updatedAt = DateTime.tryParse(conv['updated_at'] ?? '');
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SoftCard(
                    onTap: () => _viewMessages(
                      conv['id'].toString(),
                      (conv['user_id'] as String?) ?? '',
                      userName,
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.cardAiChat,
                            border: Border.all(
                              color: AppColors.secondary.withAlpha(60),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.smart_toy_rounded,
                            color: AppColors.secondary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                updatedAt != null
                                    ? 'Last active · ${_formatRelative(updatedAt)}'
                                    : 'Last active · —',
                                style: AppStyles.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _viewMessages(String conversationId, String userId, String userName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.cardAiChat,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _initial(userName),
                        style: const TextStyle(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            style: AppStyles.h3.copyWith(fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'AI consultation history',
                            style: AppStyles.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: FutureBuilder<List<ChatMessageModel>>(
                  future: _aiChatService.getAiMessages(conversationId, userId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final messages = snapshot.data ?? [];
                    if (messages.isEmpty) {
                      return const EmptyState(
                        icon: Icons.chat_bubble_outline_rounded,
                        title: 'No messages',
                      );
                    }
                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, idx) {
                        final m = messages[idx];
                        final isAi = m.senderRole == 'ai';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Align(
                            alignment: isAi
                                ? Alignment.centerLeft
                                : Alignment.centerRight,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 280),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isAi
                                    ? AppColors.cardAiChat
                                    : AppColors.primarySoft,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: Radius.circular(isAi ? 4 : 16),
                                  bottomRight: Radius.circular(isAi ? 16 : 4),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: isAi
                                    ? CrossAxisAlignment.start
                                    : CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    isAi
                                        ? 'AI CONSULTANT'
                                        : userName.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.6,
                                      color: isAi
                                          ? AppColors.secondary
                                          : AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    m.text,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatRelative(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 6) {
      return DateFormat('MMM d, y').format(date);
    }
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  String _profileName(Map<String, dynamic>? profile) {
    final fullName = (profile?['full_name'] as String? ?? '').trim();
    if (fullName.isNotEmpty && !fullName.toLowerCase().startsWith('wa user')) {
      return fullName;
    }
    final email = (profile?['email'] as String? ?? '').trim();
    if (email.isNotEmpty) return email.split('@').first;
    final phone = (profile?['phone'] as String? ?? '').trim();
    if (phone.isNotEmpty) return phone;
    return 'Registered user';
  }
}
