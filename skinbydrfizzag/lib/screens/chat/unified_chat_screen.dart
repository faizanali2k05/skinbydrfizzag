import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../constants/colors.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../services/ai_chat_service.dart';
import '../../models/chat_message_model.dart';
import '../../widgets/chat_bubble.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class UnifiedChatScreen extends StatefulWidget {
  final String? otherUserId;
  final String? otherUserName;
  final String? conversationId;
  final String? preFilledMessage;

  const UnifiedChatScreen({
    super.key,
    this.otherUserId,
    this.otherUserName,
    this.conversationId,
    this.preFilledMessage,
  });

  @override
  State<UnifiedChatScreen> createState() => _UnifiedChatScreenState();
}

class _UnifiedChatScreenState extends State<UnifiedChatScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;

  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  final AiChatService _aiChatService = AiChatService();
  final ScrollController _scrollController = ScrollController(); // for admin messages (reverse: true)
  final ScrollController _aiScrollController = ScrollController(); // for AI messages (forward)

  Stream<List<ChatMessageModel>>? _messagesStream;
  double _savedScrollPosition = 0.0;

  String? _conversationId;
  bool _isLoading = true;
  bool _isSending = false;
  String _currentUserId = '';
  String _currentUserName = 'User';
  String _otherUserId = '';
  bool _isAdmin = false;

  // AI Agent States
  bool _isAiMode = false;
  final List<ChatMessageModel> _aiMessages = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeChat();
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

  Future<void> _initializeAiChat() async {
    if (_currentUserId.isEmpty) return;

    try {
      final result = await _aiChatService.loadConversation(_currentUserId);

      setState(() {
        _aiMessages
          ..clear()
          ..addAll(result.messages.isNotEmpty
              ? result.messages
              : [
                  ChatMessageModel(
                    id: 'welcome',
                    senderId: 'ai',
                    senderName: 'AI Consultant',
                    senderRole: 'ai',
                    text:
                        'Hello! I am your AI Skin Consultant. How can I help you today?',
                    createdAt: DateTime.now(),
                  ),
                ]);
      });
    } catch (e) {
      // Fallback: at least show welcome message
      setState(() {
        _aiMessages
          ..clear()
          ..add(
            ChatMessageModel(
              id: 'welcome',
              senderId: 'ai',
              senderName: 'AI Consultant',
              senderRole: 'ai',
              text:
                  'Hello! I am your AI Skin Consultant. How can I help you today?',
              createdAt: DateTime.now(),
            ),
          );
      });
    }
  }

  Future<void> _initializeChat() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    if (currentUser == null) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authentication required. Please sign in.'),
          ),
        );
      }
      return;
    }

    _currentUserId = currentUser.uid;
    _currentUserName = currentUser.name;

    try {
      final isCurrentUserAdmin = await authService.isCurrentUserAdmin();

      String userId, adminId;
      if (isCurrentUserAdmin) {
        _isAdmin = true;
        _otherUserId = widget.otherUserId ?? '';
        if (_otherUserId.isEmpty) {
          if (mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('User information not provided.')),
            );
          }
          return;
        }
        userId = _otherUserId;
        adminId = _currentUserId;
      } else {
        _isAdmin = false;
        userId = _currentUserId;
        // fetch admin ID from backend
        final fetchedAdminId = await authService.getAdminId();
        if (fetchedAdminId == null || fetchedAdminId.isEmpty) {
          throw Exception('No admin user found');
        }
        adminId = fetchedAdminId;
        _otherUserId = adminId;
      }

      String? conversationId = widget.conversationId;
      
      if (conversationId == null) {
        debugPrint('No conversationId provided, fetching/creating "app" conversation for user $userId');
        conversationId = await _chatService.getOrCreateConversation(
          userId,
          adminId,
        );
      } else {
        debugPrint('Using provided conversationId: $conversationId');
      }

      final String validConversationId = conversationId!;

      if (mounted) {
        setState(() {
          _conversationId = validConversationId;
          _messagesStream = _chatService.getConversationMessagesStream(
            validConversationId,
          );
          _isLoading = false;
        });

        await _chatService.markMessagesAsRead(validConversationId);

        // Initialize AI chat history once we know the current user
        await _initializeAiChat();

        if (widget.preFilledMessage != null &&
            widget.preFilledMessage!.isNotEmpty) {
          // In a real app, you might check if this is a new conversation
          await Future.delayed(const Duration(milliseconds: 500));
          _messageController.text = widget.preFilledMessage!;
          await _sendMessage();
        }

        Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load chat: ${e.toString()}')),
        );
      }
    }
  }

  @override
  bool get wantKeepAlive => true;

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getApplicationDocumentsDirectory();
        final path = p.join(
          directory.path,
          'recording_${DateTime.now().millisecondsSinceEpoch}.m4a',
        );

        await _audioRecorder.start(const RecordConfig(), path: path);

        setState(() {
          _isRecording = true;
        });
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
      });

      if (path != null) {
        await _uploadAndSend('audio', File(path));
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      await _uploadAndSend('file', File(result.files.single.path!));
    }
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      await _uploadAndSend('image', File(result.files.single.path!));
    }
  }

  Future<void> _uploadAndSend(String type, File file) async {
    if (_conversationId == null) return;

    setState(() => _isSending = true);

    try {
      final fileName = p.basename(file.path);
      final path = 'chat_files/$_conversationId/$fileName';

      final publicUrl = await _chatService.uploadFile('chat_files', path, file);

      if (publicUrl != null) {
        await _chatService.sendMessage(
          conversationId: _conversationId!,
          text: '',
          senderId: _currentUserId,
          senderName: _currentUserName,
          senderRole: _isAdmin ? 'admin' : 'user',
          messageType: type,
          fileUrl: publicUrl,
        );
      }
    } catch (e) {
      debugPrint('Error in _uploadAndSend: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    // Admin messages list uses reverse: true, so offset 0 is the bottom.
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
    // AI messages list is a normal (non-reversed) list, so we scroll to the end.
    if (_aiScrollController.hasClients) {
      _aiScrollController.animateTo(
        _aiScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;
    if (!_isAiMode && _conversationId == null) return;

    setState(() => _isSending = true);
    _messageController.clear();

    if (_isAiMode) {
      await _sendAiMessage(text);
    } else {
      await _sendAdminMessage(text);
    }
  }

  Future<void> _sendAdminMessage(String text) async {
    try {
      final error = await _chatService.sendMessage(
        conversationId: _conversationId!,
        text: text,
        senderId: _currentUserId,
        senderName: _currentUserName,
        senderRole: _isAdmin ? 'admin' : 'user',
      );

      if (error != null) {
        throw Exception(error);
      }

      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: Could not send message - ${e.toString()}'),
          ),
        );
        _messageController.text = text;
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _sendAiMessage(String text) async {
    try {
      final now = DateTime.now();

      // Optimistically add the user message
      setState(() {
        _aiMessages.add(
          ChatMessageModel(
            id: now.toIso8601String(),
            senderId: _currentUserId,
            senderName: _currentUserName,
            senderRole: 'user',
            text: text,
            createdAt: now,
          ),
        );
      });

      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);

      final result = await _aiChatService.sendAndStore(
        userId: _currentUserId,
        message: text,
      );

      if (!mounted) return;

      setState(() {
        _aiMessages.add(
          ChatMessageModel(
            id: DateTime.now().toIso8601String(),
            senderId: 'ai',
            senderName: 'AI Consultant',
            senderRole: 'ai',
            text: result.response,
            createdAt: DateTime.now(),
          ),
        );
        _isSending = false;
      });
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiMessages.add(
            ChatMessageModel(
              id: DateTime.now().toString(),
              senderId: 'ai',
              senderName: 'AI Consultant',
              senderRole: 'ai',
              text: _baseUrlIsPlaceholder()
                  ? 'AI Skin Consultant is not configured yet. Please contact support.'
                  : 'Sorry, I am having trouble connecting to my brain. Error: ${e.toString()}',
              createdAt: DateTime.now(),
            ),
          );
          _isSending = false;
        });
      }
    }
  }

  bool _baseUrlIsPlaceholder() {
    return AiChatService.baseUrl.contains('YOUR_RENDER_PYTHON_URL_HERE');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _scrollController.dispose();
    _aiScrollController.dispose();
    try {
      _audioRecorder.dispose();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(
            'Chat',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          backgroundColor: Colors.white,
          elevation: 0.5,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 16),
              Text(
                'Loading conversation...',
                style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    if (_conversationId == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(
            'Chat',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          backgroundColor: Colors.white,
          elevation: 0.5,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.chat_bubble_outline,
                  size: 64,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Unable to load chat',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Please check your internet connection and try again.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _initializeChat,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 1,
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white.withAlpha(51),
              child: Icon(
                _isAiMode
                    ? Icons.smart_toy_outlined
                    : (_isAdmin ? Icons.person : Icons.local_hospital),
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isAiMode
                        ? 'AI Consultant'
                        : (_isAdmin
                              ? (widget.otherUserName ?? 'User')
                              : 'Dr. Fizza'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    _isAiMode ? 'AI Agent Enabled' : '',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_isAdmin)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: TextButton(
                onPressed: () {
                  setState(() => _isAiMode = !_isAiMode);
                  Future.delayed(
                    const Duration(milliseconds: 100),
                    _scrollToBottom,
                  );
                },
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withAlpha(51),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  _isAiMode ? 'Talk to Doctor' : 'Talk to AI',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (context) => Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Chat Options',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        leading: const Icon(Icons.info_outline),
                        title: const Text('Conversation Info'),
                        onTap: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isAiMode
                ? _buildAiMessagesList()
                : _buildAdminMessagesList(),
          ),
          _buildInputField(),
        ],
      ),
    );
  }

  Widget _buildAiMessagesList() {
    return ListView.builder(
      controller: _aiScrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _aiMessages.length,
      itemBuilder: (context, index) {
        final message = _aiMessages[index];
        final isMe = message.senderId == _currentUserId;
        final previousMessage = index > 0 ? _aiMessages[index - 1] : null;
        final showTime = _shouldShowTimestamp(message, previousMessage);

        return Column(
          children: [
            if (showTime) _buildTimestamp(message.createdAt),
            Align(
              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
              child: ChatBubble(
                message: message.text,
                isUser: isMe,
                time: _formatTime(message.createdAt),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAdminMessagesList() {
    // Only initialize stream once if not already done
    if (_messagesStream == null && _conversationId != null) {
      _messagesStream = _chatService.getConversationMessagesStream(
        _conversationId!,
      );
    }

    return StreamBuilder<List<ChatMessageModel>>(
      stream: _messagesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        if (snapshot.hasError) {
          return _buildErrorState();
        }

        final messages = (snapshot.data ?? []).reversed.toList();

        // Mark messages as read if new ones arrived
        if (messages.isNotEmpty &&
            messages.first.senderId != _currentUserId &&
            !_isLoading) {
          _chatService.markMessagesAsRead(_conversationId!);
        }

        if (messages.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          controller: _scrollController,
          reverse: true,
          padding: const EdgeInsets.all(16),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            final isMe = message.senderId == _currentUserId;
            final showTime =
                index == messages.length - 1 ||
                _shouldShowTimestamp(message, messages[index + 1]);

            return Column(
              children: [
                if (showTime) _buildTimestamp(message.createdAt),
                Align(
                  alignment: isMe
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: ChatBubble(
                    message: message.text,
                    isUser: isMe,
                    time: _formatTime(message.createdAt),
                    messageType: message.messageType,
                    fileUrl: message.fileUrl,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTimestamp(DateTime? dateTime) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(179),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _formatMessageTime(dateTime),
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Connection Error',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Unable to load messages. Please check your connection.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              _isAdmin
                  ? 'Start a conversation with this patient'
                  : 'Start a conversation with Dr. Fizza',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField() {
    final bool isEmpty = _messageController.text.trim().isEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: const BoxDecoration(color: Colors.transparent),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Text Input Field Container
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(13),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.emoji_emotions_outlined,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () {},
                    ),
                    Expanded(
                      child: _isRecording
                          ? const Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 8,
                              ),
                              child: Text(
                                'Recording...',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          : TextField(
                              controller: _messageController,
                              onChanged: (value) {
                                setState(() {});
                              },
                              maxLines: 5,
                              minLines: 1,
                              textInputAction: TextInputAction.newline,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: const InputDecoration(
                                hintText: 'Type a message...',
                                hintStyle: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 4,
                                ),
                              ),
                            ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.attach_file,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: _pickFile,
                    ),
                    if (isEmpty && !_isRecording)
                      IconButton(
                        icon: const Icon(
                          Icons.camera_alt,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: _pickImage,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
            // Send / Mic Button
            GestureDetector(
              onLongPress: isEmpty ? _startRecording : null,
              onLongPressUp: isEmpty ? _stopRecording : null,
              onTap: () {
                if (_isSending || _isRecording) return;
                if (!isEmpty) {
                  _sendMessage();
                }
              },
              child: Container(
                height: 50,
                width: 50,
                decoration: BoxDecoration(
                  color: _isRecording ? Colors.red : AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(26),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          isEmpty ? Icons.mic : Icons.send,
                          color: Colors.white,
                          size: 24,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _shouldShowTimestamp(
    ChatMessageModel current,
    ChatMessageModel? previous,
  ) {
    if (previous == null) return true;

    final currentDateTime = current.createdAt;
    final previousDateTime = previous.createdAt;

    if (currentDateTime == null || previousDateTime == null) return false;

    return currentDateTime.difference(previousDateTime).inMinutes > 5;
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    return DateFormat('h:mm a').format(dateTime);
  }

  String _formatMessageTime(DateTime? dateTime) {
    if (dateTime == null) return '';

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE').format(dateTime);
    } else {
      return DateFormat('MMM dd, yyyy').format(dateTime);
    }
  }
}
