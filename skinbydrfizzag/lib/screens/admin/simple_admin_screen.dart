import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../constants/colors.dart';
import '../../routes/app_routes.dart';
import 'manage_users_screen.dart';
import 'manage_procedures_screen.dart';
import 'manage_appointments_screen.dart';
import 'admin_chat_manager_screen.dart';
import 'manage_about_us_screen.dart';

import '../../services/chat_service.dart';

class SimpleAdminScreen extends StatefulWidget {
  const SimpleAdminScreen({super.key});

  @override
  State<SimpleAdminScreen> createState() => _SimpleAdminScreenState();
}

class _SimpleAdminScreenState extends State<SimpleAdminScreen> {
  final ChatService _chatService = ChatService();
  final List<Map<String, dynamic>> _adminOptions = [
    {
      'title': 'Chats',
      'subtitle': 'Manage chats between admin and users',
      'icon': Icons.chat_outlined,
      'screen': const AdminChatManagerScreen(),
      'color': Colors.blue,
    },
    {
      'title': 'Manage Appointments',
      'subtitle': 'Manage appointments of various users',
      'icon': Icons.calendar_month_outlined,
      'screen': const ManageAppointmentsScreen(),
      'color': Colors.green,
    },
    {
      'title': 'Manage Users',
      'subtitle': 'View and manage application users',
      'icon': Icons.people_alt_outlined,
      'screen': const ManageUsersScreen(),
      'color': Colors.orange,
    },
    {
      'title': 'Manage Procedures',
      'subtitle': 'Add and manage medical procedures',
      'icon': Icons.medical_services_outlined,
      'screen': const ManageProceduresScreen(),
      'color': Colors.purple,
    },
    {
      'title': 'Manage About Us',
      'subtitle': 'Edit information about the clinic',
      'icon': Icons.info_outline,
      'screen': const ManageAboutUsScreen(),
      'color': Colors.teal,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.textPrimary),
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
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView.builder(
          itemCount: _adminOptions.length,
          itemBuilder: (context, index) {
            final option = _adminOptions[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => option['screen']),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(13),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: option['color'].withAlpha(26),
                          shape: BoxShape.circle,
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(
                              option['icon'],
                              size: 30,
                              color: option['color'],
                            ),
                            if (option['title'] == 'Chats')
                              StreamBuilder<int>(
                                stream: _chatService.getAdminTotalUnreadStream(
                                  authService.currentUserId ?? '',
                                ),
                                builder: (context, snapshot) {
                                  final totalUnread = snapshot.data ?? 0;
                                  if (totalUnread <= 0) {
                                    return const SizedBox.shrink();
                                  }

                                  return Positioned(
                                    right: -8,
                                    top: -8,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        totalUnread > 99
                                            ? '99+'
                                            : totalUnread.toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              option['title'],
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              option['subtitle'],
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
