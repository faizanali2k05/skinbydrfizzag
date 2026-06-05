import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../constants/styles.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../models/user_model.dart';
import 'admin_chat_manager_screen.dart';
import 'manage_about_us_screen.dart';
import 'manage_appointments_screen.dart';
import 'manage_procedures_screen.dart';
import 'manage_users_screen.dart';

class SimpleAdminScreen extends StatefulWidget {
  const SimpleAdminScreen({super.key});

  @override
  State<SimpleAdminScreen> createState() => _SimpleAdminScreenState();
}

class _SimpleAdminScreenState extends State<SimpleAdminScreen> {
  final ChatService _chatService = ChatService();

  late final List<_AdminTile> _tiles = [
    _AdminTile(
      title: 'Chats',
      subtitle: 'Reply to patients across app & WhatsApp',
      icon: Icons.chat_rounded,
      color: AppColors.info,
      builder: () => const AdminChatManagerScreen(),
      showsUnread: true,
    ),
    _AdminTile(
      title: 'Appointments',
      subtitle: 'Track, confirm and assign visits',
      icon: Icons.calendar_month_rounded,
      color: AppColors.secondary,
      builder: () => const ManageAppointmentsScreen(),
    ),
    _AdminTile(
      title: 'Users',
      subtitle: 'Patients, profiles, password resets',
      icon: Icons.people_alt_rounded,
      color: AppColors.warning,
      builder: () => const ManageUsersScreen(),
    ),
    _AdminTile(
      title: 'Procedures',
      subtitle: 'Catalogue, pricing and details',
      icon: Icons.medical_services_rounded,
      color: AppColors.accentDark,
      builder: () => const ManageProceduresScreen(),
    ),
    _AdminTile(
      title: 'About the clinic',
      subtitle: 'Edit clinic info, contact and socials',
      icon: Icons.info_rounded,
      color: AppColors.primary,
      builder: () => const ManageAboutUsScreen(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final adminId = authService.currentUserId ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded,
                color: AppColors.textPrimary),
            onPressed: () async {
              await authService.signOut();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.signIn,
                  (route) => false,
                );
              }
            },
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            _buildAdminHero(authService),
            const SizedBox(height: 20),
            ..._tiles.map((tile) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildTile(adminId, tile),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminHero(AuthService authService) {
    return FutureBuilder<UserModel?>(
      future: authService.getCurrentUserDocument(),
      builder: (context, snapshot) {
        final name = snapshot.data?.name ?? 'Admin';
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withAlpha(60),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white.withAlpha(48),
                child: const Icon(Icons.shield_rounded,
                    color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Welcome back',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Skin By Dr. Fizza · Admin console',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTile(String adminId, _AdminTile tile) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => tile.builder()),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.divider),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(8),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: tile.color.withAlpha(30),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(tile.icon, color: tile.color, size: 24),
                  ),
                  if (tile.showsUnread && adminId.isNotEmpty)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: StreamBuilder<int>(
                        stream:
                            _chatService.getAdminTotalUnreadStream(adminId),
                        builder: (context, snapshot) {
                          final count = snapshot.data ?? 0;
                          if (count <= 0) return const SizedBox.shrink();
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: AppColors.surface,
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              count > 99 ? '99+' : '$count',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tile.title, style: AppStyles.h3),
                    const SizedBox(height: 2),
                    Text(
                      tile.subtitle,
                      style: AppStyles.bodySmall,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminTile {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget Function() builder;
  final bool showsUnread;

  _AdminTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.builder,
    this.showsUnread = false,
  });
}
