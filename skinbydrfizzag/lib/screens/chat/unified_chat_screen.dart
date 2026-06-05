import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../constants/colors.dart';
import '../../constants/styles.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../services/ai_chat_service.dart';
import '../../models/chat_message_model.dart';
import '../../widgets/chat_bubble.dart';
import '../profile/user_profile_screen.dart';
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
  DateTime? _recordingStartedAt;

  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  final AiChatService _aiChatService = AiChatService();
  final ScrollController _scrollController =
      ScrollController(); // for admin messages (reverse: true)
  final ScrollController _aiScrollController =
      ScrollController(); // for AI messages (forward)

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
  int _aiLocalIdCounter = 0;

  // True when the screen is being used by a non-admin user. In that case we
  // hide the doctor (admin) chat path entirely and only show the AI agent.
  bool _isAiOnlyMode = false;

  // Guards against re-sending the prefilled message if _initializeChat runs
  // more than once (e.g. when the user taps "Retry" after an error).
  bool _prefillSent = false;

  String _nextAiLocalId(String prefix) {
    _aiLocalIdCounter += 1;
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch}_$_aiLocalIdCounter';
  }

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
          ..addAll(
            result.messages.isNotEmpty
                ? result.messages
                : [
                    ChatMessageModel(
                      id: _nextAiLocalId('welcome'),
                      senderId: 'ai',
                      senderName: 'AI Consultant',
                      senderRole: 'ai',
                      text:
                          'Hello! I am your AI Skin Consultant. How can I help you today?',
                      createdAt: DateTime.now(),
                    ),
                  ],
          );
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

      // Non-admin users only get the AI agent. Doctor chat stays admin-only;
      // patients reach the doctor through WhatsApp instead.
      if (!isCurrentUserAdmin) {
        _isAdmin = false;
        _isAiOnlyMode = true;
        _isAiMode = true;

        if (mounted) {
          setState(() => _isLoading = false);
          await _initializeAiChat();

          if (!_prefillSent &&
              widget.preFilledMessage != null &&
              widget.preFilledMessage!.isNotEmpty) {
            _prefillSent = true;
            await Future.delayed(const Duration(milliseconds: 500));
            _messageController.text = widget.preFilledMessage!;
            await _sendMessage();
          }

          Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
        }
        return;
      }

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
      final userId = _otherUserId;
      final adminId = _currentUserId;

      String? conversationId = widget.conversationId;

      if (conversationId == null) {
        debugPrint(
          'No conversationId provided, fetching/creating "app" conversation for user $userId',
        );
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

        if (!_prefillSent &&
            widget.preFilledMessage != null &&
            widget.preFilledMessage!.isNotEmpty) {
          _prefillSent = true;
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
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        _showSnackBar('Microphone permission is required for voice messages.');
        return;
      }

      final directory = await getApplicationDocumentsDirectory();
      final path = p.join(
        directory.path,
        'recording_${DateTime.now().millisecondsSinceEpoch}.m4a',
      );

      await _audioRecorder.start(const RecordConfig(), path: path);

      setState(() {
        _isRecording = true;
        _recordingStartedAt = DateTime.now();
      });
    } catch (e) {
      debugPrint('Error starting recording: $e');
      _showSnackBar('Could not start recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      if (!_isRecording) return;
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _recordingStartedAt = null;
      });

      if (path != null) {
        await _uploadAndSend('audio', File(path));
      } else {
        _showSnackBar('No recording was captured.');
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      if (mounted) {
        setState(() {
          _isRecording = false;
          _recordingStartedAt = null;
        });
      }
      _showSnackBar('Could not send voice message: $e');
    }
  }

  Future<void> _toggleRecording() async {
    if (_isSending) return;
    if (_isRecording) {
      final startedAt = _recordingStartedAt;
      if (startedAt != null &&
          DateTime.now().difference(startedAt).inMilliseconds < 500) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
      await _stopRecording();
      return;
    }
    await _startRecording();
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result != null) {
      await _uploadPickedFile('file', result.files.single);
    }
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result != null) {
      await _uploadPickedFile('image', result.files.single);
    }
  }

  Future<void> _uploadPickedFile(String type, PlatformFile pickedFile) async {
    final fileName = pickedFile.name;
    final bytes = pickedFile.bytes;
    if (bytes != null) {
      await _uploadAndSend(type, bytes, fileName: fileName);
      return;
    }
    final path = pickedFile.path;
    if (path != null) {
      await _uploadAndSend(type, File(path), fileName: fileName);
    }
  }

  Future<void> _uploadAndSend(
    String type,
    Object file, {
    String? fileName,
  }) async {
    if (_conversationId == null) return;

    setState(() => _isSending = true);

    try {
      final resolvedFileName =
          fileName ??
          (file is File
              ? p.basename(file.path)
              : 'attachment_${DateTime.now().millisecondsSinceEpoch}');
      final safeFileName = resolvedFileName.replaceAll(RegExp(r'[\\/]'), '_');
      final path =
          '$_currentUserId/$_conversationId/${DateTime.now().millisecondsSinceEpoch}_$safeFileName';

      final publicUrl = await _chatService.uploadFile('chat_files', path, file);

      if (publicUrl != null) {
        final error = await _chatService.sendMessage(
          conversationId: _conversationId!,
          text: type == 'file' ? safeFileName : '',
          senderId: _currentUserId,
          senderName: _currentUserName,
          senderRole: _isAdmin ? 'admin' : 'user',
          messageType: type,
          fileUrl: publicUrl,
        );
        if (error != null) {
          throw Exception(error);
        }
      } else {
        throw Exception('File upload failed');
      }
    } catch (e) {
      debugPrint('Error in _uploadAndSend: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send attachment: ${e.toString()}')),
        );
      }
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
            id: _nextAiLocalId('user'),
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
            id: _nextAiLocalId('ai'),
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
              id: _nextAiLocalId('ai_err'),
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
    // Stop any active recording before disposing the recorder so the underlying
    // platform session is released and the temp file is finalised.
    () async {
      try {
        if (_isRecording) {
          await _audioRecorder.stop();
        }
      } catch (_) {}
      try {
        await _audioRecorder.dispose();
      } catch (_) {}
    }();
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

    if (_conversationId == null && !_isAiOnlyMode) {
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
                  GestureDetector(
                    onTap: (_isAdmin && !_isAiMode && _otherUserId.isNotEmpty)
                        ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    UserProfileScreen(userId: _otherUserId),
                              ),
                            );
                          }
                        : null,
                    child: Text(
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
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: _isRecording
                          ? Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 16,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: AppColors.error,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Recording…',
                                    style: TextStyle(
                                      color: AppColors.error,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '(tap mic to send)',
                                    style: AppStyles.bodySmall,
                                  ),
                                ],
                              ),
                            )
                          : Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              child: TextField(
                                controller: _messageController,
                                onChanged: (_) => setState(() {}),
                                maxLines: 5,
                                minLines: 1,
                                textInputAction: TextInputAction.newline,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 15,
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'Type a message…',
                                  hintStyle: TextStyle(
                                    color: AppColors.textLight,
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  filled: false,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                    ),
                    if (!_isAiMode) ...[
                      IconButton(
                        icon: const Icon(
                          Icons.attach_file_rounded,
                          color: AppColors.textSecondary,
                          size: 22,
                        ),
                        onPressed: _isRecording ? null : _pickFile,
                      ),
                      if (isEmpty && !_isRecording)
                        IconButton(
                          icon: const Icon(
                            Icons.image_outlined,
                            color: AppColors.textSecondary,
                            size: 22,
                          ),
                          onPressed: _pickImage,
                        ),
                    ],
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onLongPress: (isEmpty && !_isAiMode) ? _toggleRecording : null,
              onTap: () {
                if (_isSending) return;
                if (!isEmpty) {
                  _sendMessage();
                } else if (!_isAiMode) {
                  _toggleRecording();
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  gradient: _isRecording ? null : AppColors.primaryGradient,
                  color: _isRecording ? AppColors.error : null,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color:
                          (_isRecording ? AppColors.error : AppColors.primary)
                              .withAlpha(60),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          _isRecording
                              ? Icons.mic_rounded
                              : (isEmpty
                                    ? (_isAiMode
                                          ? Icons.send_rounded
                                          : Icons.mic_none_rounded)
                                    : Icons.send_rounded),
                          color: Colors.white,
                          size: 22,
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
