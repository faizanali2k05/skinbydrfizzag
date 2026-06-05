import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../models/chat_message_model.dart';
import '../../widgets/chat_bubble.dart';

class AdminChatScreen extends StatefulWidget {
  final String? userId;
  final String? userName;

  const AdminChatScreen({super.key, this.userId, this.userName});

  @override
  State<AdminChatScreen> createState() => _AdminChatScreenState();
}

class _AdminChatScreenState extends State<AdminChatScreen>
    with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  final ScrollController _scrollController = ScrollController();
  String? _conversationId;
  bool _isLoading = true;
  String _targetUserId = '';
  double _savedScrollPosition = 0.0;
  Stream<List<ChatMessageModel>>? _messagesStream;
  // Tracks how many messages we last rendered so we only auto-scroll to the
  // bottom when a new message actually arrives — not on every rebuild (which
  // would yank the admin away while they scroll up to read history).
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _targetUserId = widget.userId ?? '';
    _initializeConversation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App is resumed, restore scroll position
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && _scrollController.hasClients) {
            _scrollController.jumpTo(_savedScrollPosition);
          }
        });
      }
    } else if (state == AppLifecycleState.paused) {
      // App is paused, save scroll position
      if (_scrollController.hasClients) {
        _savedScrollPosition = _scrollController.offset;
      }
    }
  }

  Future<void> _initializeConversation() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    if (currentUser == null) {
      debugPrint('AdminChatScreen: No current user');
      return;
    }

    if (_targetUserId.isEmpty) {
      _targetUserId = currentUser.uid;
    }

    debugPrint(
      'AdminChatScreen: Initializing conversation for user: $_targetUserId with admin: ${currentUser.uid}',
    );
    try {
      final conversationId = await _chatService.getOrCreateConversation(
        _targetUserId, // userId (the user being chatted with)
        currentUser.uid, // doctorId (the admin)
      );

      debugPrint('AdminChatScreen: Got conversation ID: $conversationId');
      if (mounted && conversationId != null) {
        setState(() {
          _conversationId = conversationId;
          _messagesStream = _chatService.getConversationMessagesStream(
            conversationId,
          );
          _isLoading = false;
        });

        // Mark messages as read when opening the chat
        debugPrint('AdminChatScreen: Marking messages as read for conversation: $conversationId');
        await _chatService.markMessagesAsRead(conversationId);

        // Auto-scroll after a small delay
        Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
      }
    } catch (e) {
      debugPrint('AdminChatScreen: Chat initialization error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _conversationId == null) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    if (currentUser == null) return;

    _messageController.clear();

    try {
      await _chatService.sendMessage(
        conversationId: _conversationId!,
        text: text,
        senderId: currentUser.uid,
        senderName: currentUser.name,
        senderRole: 'admin',
      );
    } catch (e) {
      debugPrint('Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Error sending message")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);

    if (_isLoading || _conversationId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text(
          widget.userName ?? "User Chat",
          style: const TextStyle(color: Colors.black),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessageModel>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  debugPrint('AdminChatScreen stream error: ${snapshot.error}');
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: AppColors.error,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Connection Error',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Unable to load messages. Check your connection.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => setState(() {}),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: Text('No messages yet'));
                }

                final messages = snapshot.data ?? [];
                debugPrint('AdminChatScreen: Received ${messages.length} messages for conversation $_conversationId');
                
                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'Start a conversation with the user',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                // Only auto-scroll when new messages arrive (or on first load),
                // so the admin isn't pulled back down while reading history.
                if (messages.length != _lastMessageCount) {
                  _lastMessageCount = messages.length;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!_scrollController.hasClients) return;
                    try {
                      _scrollController.jumpTo(
                        _scrollController.position.maxScrollExtent,
                      );
                    } catch (_) {}
                  });
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse:
                      false, // Don't reverse - show messages chronologically
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == authService.currentUserId;
                    return _buildMessageBubble(message, isMe);
                  },
                );
              },
            ),
          ),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: "Type a message...",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.send, color: AppColors.primary),
              onPressed: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessageModel message, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ChatBubble(
          message: message.text,
          isUser: isMe,
          time: '',
          messageType: message.messageType,
          fileUrl: message.fileUrl,
        ),
      ),
    );
  }
}
