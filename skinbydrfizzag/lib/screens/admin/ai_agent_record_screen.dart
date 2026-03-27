import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../services/ai_chat_service.dart';

import '../../models/chat_message_model.dart';

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
    _fetchConversations();
  }

  Future<void> _fetchConversations() async {
    final results = await _aiChatService.getAllAiConversations();
    if (mounted) {
      setState(() {
        _conversations = results;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("AI Agent Records", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _conversations.isEmpty
              ? const Center(child: Text("No AI conversations found"))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _conversations.length,
                  itemBuilder: (context, index) {
                    final conv = _conversations[index];
                    final profile = conv['profiles'] as Map<String, dynamic>?;
                    final userName = profile?['full_name'] ?? 'Unknown User';
                    final updatedAt = DateTime.tryParse(conv['updated_at'] ?? '');

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.teal.shade50,
                          child: const Icon(Icons.smart_toy_outlined, color: Colors.teal),
                        ),
                        title: Text(userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("Last active: ${updatedAt?.toString().split('.').first ?? 'N/A'}", style: const TextStyle(fontSize: 12)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _viewMessages(conv['id'], conv['user_id'], userName),
                      ),
                    );
                  },
                ),
    );
  }

  void _viewMessages(String conversationId, String userId, String userName) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("AI Chat with $userName", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<List<ChatMessageModel>>(
                  future: _aiChatService.getAiMessages(conversationId, userId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final messages = snapshot.data ?? [];
                    if (messages.isEmpty) return const Center(child: Text("No messages."));

                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, idx) {
                        final m = messages[idx];
                        final isAi = m.senderRole == 'ai';
                        return Align(
                          alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isAi ? Colors.grey.shade100 : AppColors.primary.withAlpha(50),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: isAi ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                              children: [
                                Text(
                                  isAi ? "AI" : "USER",
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isAi ? Colors.teal : AppColors.primary),
                                ),
                                const SizedBox(height: 4),
                                Text(m.text),
                              ],
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
}
