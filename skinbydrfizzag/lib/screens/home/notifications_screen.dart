import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../constants/styles.dart';
import '../../models/notification_model.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/soft_card.dart';
import '../chat/unified_chat_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markAll();
    });
  }

  Future<void> _markAll() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUserId;
    if (userId != null) {
      await _notificationService.markAllAsRead(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUserId;

    if (userId == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in.')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Builder(
            builder: (innerContext) => IconButton(
              icon: const Icon(
                Icons.done_all_rounded,
                color: AppColors.primary,
              ),
              tooltip: 'Mark all as read',
              onPressed: () async {
                await _markAll();
                if (!innerContext.mounted) return;
                ScaffoldMessenger.of(innerContext).showSnackBar(
                  const SnackBar(content: Text('All caught up.')),
                );
              },
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: _notificationService.getUserNotificationsStream(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          // Patients receive doctor messages on WhatsApp, so chat-message
          // notifications are intentionally hidden in the in-app feed.
          final notifications = (snapshot.data ?? [])
              .where((n) => n.type != 'message')
              .toList()
            ..sort((a, b) =>
                (b.createdAt ?? DateTime(0))
                    .compareTo(a.createdAt ?? DateTime(0)));

          if (notifications.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'No notifications yet',
              message:
                  'Appointment updates and chat alerts will appear here.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final n = notifications[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildNotification(n),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildNotification(NotificationModel n) {
    final isUnread = !n.isRead;
    final color = _typeColor(n.type);

    return SoftCard(
      color: isUnread ? AppColors.surface : AppColors.surfaceMuted,
      onTap: () async {
        if (isUnread) {
          await _notificationService.markAsRead(n.id);
        }
        if (!mounted) return;
        if (n.type == 'message') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const UnifiedChatScreen(),
            ),
          );
        }
      },
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(_typeIcon(n.type), color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        n.title,
                        style: TextStyle(
                          fontWeight:
                              isUnread ? FontWeight.w700 : FontWeight.w600,
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (isUnread)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  n.message,
                  style: AppStyles.bodySmall.copyWith(
                    color: isUnread
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _formatRelative(n.createdAt ?? DateTime.now()),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'appointment':
        return Icons.calendar_month_rounded;
      case 'message':
        return Icons.chat_bubble_rounded;
      case 'status_update':
        return Icons.info_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'appointment':
        return AppColors.primary;
      case 'message':
        return AppColors.secondary;
      case 'status_update':
        return AppColors.warning;
      default:
        return AppColors.info;
    }
  }

  String _formatRelative(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 6) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}
