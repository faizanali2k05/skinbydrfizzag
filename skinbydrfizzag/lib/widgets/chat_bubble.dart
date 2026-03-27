import 'package:flutter/material.dart';
import '../constants/colors.dart';
import 'package:audioplayers/audioplayers.dart';

class ChatBubble extends StatefulWidget {
  final String message;
  final bool isUser;
  final String time;
  final String messageType;
  final String? fileUrl;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isUser,
    required this.time,
    this.messageType = 'text',
    this.fileUrl,
  });

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.messageType == 'audio' && widget.fileUrl != null) {
      _audioPlayer.onPlayerStateChanged.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state == PlayerState.playing;
          });
        }
      });
      _audioPlayer.onDurationChanged.listen((newDuration) {
        if (mounted) setState(() => _duration = newDuration);
      });
      _audioPlayer.onPositionChanged.listen((newPosition) {
        if (mounted) setState(() => _position = newPosition);
      });
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: widget.isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (!widget.isUser) ...[
            const Padding(
              padding: EdgeInsets.only(bottom: 4.0, left: 4.0),
              child: Icon(
                Icons.local_hospital,
                size: 16,
                color: AppColors.primary,
              ),
            ),
          ],
          Container(
            constraints: const BoxConstraints(maxWidth: 280),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: widget.isUser ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(widget.isUser ? 18 : 4),
                bottomRight: Radius.circular(widget.isUser ? 4 : 18),
              ),
              border: widget.isUser
                  ? null
                  : Border.all(color: Colors.grey.shade200, width: 0.5),
              boxShadow: widget.isUser
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withAlpha(8),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMessageContent(),
                const SizedBox(height: 4),
                Text(
                  widget.time,
                  style: TextStyle(
                    fontSize: 11,
                    color: widget.isUser
                        ? Colors.white70
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent() {
    switch (widget.messageType) {
      case 'image':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.fileUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  widget.fileUrl!,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  },
                ),
              ),
            if (widget.message.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                widget.message,
                style: TextStyle(
                  color: widget.isUser ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ],
        );
      case 'audio':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: widget.isUser ? Colors.white : AppColors.primary,
              ),
              onPressed: () async {
                if (_isPlaying) {
                  await _audioPlayer.pause();
                } else if (widget.fileUrl != null) {
                  await _audioPlayer.play(UrlSource(widget.fileUrl!));
                }
              },
            ),
            Expanded(
              child: Slider(
                activeColor: widget.isUser ? Colors.white : AppColors.primary,
                inactiveColor: widget.isUser
                    ? Colors.white30
                    : Colors.grey[300],
                value: _position.inSeconds.toDouble(),
                max: _duration.inSeconds.toDouble() > 0
                    ? _duration.inSeconds.toDouble()
                    : 1.0,
                onChanged: (value) async {
                  await _audioPlayer.seek(Duration(seconds: value.toInt()));
                },
              ),
            ),
          ],
        );
      case 'file':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.insert_drive_file,
              color: widget.isUser ? Colors.white : AppColors.primary,
            ),
            const SizedBox(width: 8),
            const Text(
              'Document',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        );
      default:
        return Text(
          widget.message,
          style: TextStyle(
            color: widget.isUser ? Colors.white : AppColors.textPrimary,
            fontSize: 15,
            height: 1.4,
            fontWeight: widget.isUser ? FontWeight.normal : FontWeight.w500,
          ),
        );
    }
  }
}
