import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/colors.dart';

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

  bool get _isAudio =>
      widget.messageType == 'audio' || widget.messageType == 'voice';

  @override
  void initState() {
    super.initState();
    if (_isAudio && widget.fileUrl != null) {
      _audioPlayer.onPlayerStateChanged.listen((state) {
        if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
      });
      _audioPlayer.onDurationChanged.listen((d) {
        if (mounted) setState(() => _duration = d);
      });
      _audioPlayer.onPositionChanged.listen((p) {
        if (mounted) setState(() => _position = p);
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
    final bgColor =
        widget.isUser ? AppColors.primary : AppColors.surface;
    final textColor =
        widget.isUser ? Colors.white : AppColors.textPrimary;
    final timeColor =
        widget.isUser ? Colors.white70 : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: widget.isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (!widget.isUser)
            const Padding(
              padding: EdgeInsets.only(left: 6, bottom: 4),
              child: Icon(
                Icons.local_hospital_rounded,
                size: 14,
                color: AppColors.primary,
              ),
            ),
          Container(
            constraints: const BoxConstraints(maxWidth: 280),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(widget.isUser ? 18 : 4),
                bottomRight: Radius.circular(widget.isUser ? 4 : 18),
              ),
              border: widget.isUser
                  ? null
                  : Border.all(color: AppColors.divider),
              boxShadow: widget.isUser
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withAlpha(40),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withAlpha(8),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildContent(textColor),
                const SizedBox(height: 4),
                Text(
                  widget.time,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: timeColor,
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

  Widget _buildContent(Color textColor) {
    switch (widget.messageType) {
      case 'image':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.fileUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: GestureDetector(
                  onTap: () => _openUrl(widget.fileUrl),
                  child: Image.network(
                    widget.fileUrl!,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return SizedBox(
                        height: 180,
                        width: 220,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: widget.isUser
                                ? Colors.white
                                : AppColors.primary,
                            strokeWidth: 2,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stack) => Container(
                      height: 180,
                      width: 220,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              ),
            if (widget.message.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                widget.message,
                style: TextStyle(color: textColor, fontSize: 14),
              ),
            ],
          ],
        );
      case 'audio':
      case 'voice':
        return _buildAudio();
      case 'file':
        return _buildFilePill(textColor);
      default:
        return Text(
          widget.message,
          style: TextStyle(
            color: textColor,
            fontSize: 15,
            height: 1.4,
          ),
        );
    }
  }

  Widget _buildAudio() {
    final maxSeconds = _duration.inSeconds.toDouble() > 0
        ? _duration.inSeconds.toDouble()
        : 1.0;
    final value =
        _position.inSeconds.toDouble().clamp(0.0, maxSeconds).toDouble();
    final iconColor = widget.isUser ? Colors.white : AppColors.primary;

    return SizedBox(
      width: 240,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: widget.isUser
                  ? Colors.white.withAlpha(48)
                  : AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(
                _isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: iconColor,
                size: 22,
              ),
              onPressed: () async {
                if (widget.fileUrl == null) return;
                if (_isPlaying) {
                  await _audioPlayer.pause();
                } else {
                  await _audioPlayer.play(UrlSource(widget.fileUrl!));
                }
              },
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 6,
                ),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                activeColor:
                    widget.isUser ? Colors.white : AppColors.primary,
                inactiveColor: widget.isUser
                    ? Colors.white.withAlpha(80)
                    : AppColors.divider,
                value: value,
                max: maxSeconds,
                onChanged: (v) async =>
                    _audioPlayer.seek(Duration(seconds: v.toInt())),
              ),
            ),
          ),
          Text(
            _formatDuration(_position),
            style: TextStyle(
              color: widget.isUser ? Colors.white70 : AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilePill(Color textColor) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _openUrl(widget.fileUrl),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: widget.isUser
                  ? Colors.white.withAlpha(48)
                  : AppColors.primarySoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.insert_drive_file_outlined,
              color: widget.isUser ? Colors.white : AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              widget.message.isNotEmpty ? widget.message : 'Open document',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: textColor,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openUrl(String? url) async {
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
