import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../constants/styles.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import 'edit_profile_screen.dart';
import 'about_us_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);


    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: FutureBuilder<UserModel?>(
            future: authService.getCurrentUserDocument(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data == null) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Profile not found or still being created."),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => setState(() {}),
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                );
              }

              final user = snapshot.data!;
              final displayName = user.name;
              final email = user.email;
              final phone = user.phone;

              return Column(
                children: [
                  const SizedBox(height: 20),
                  // Profile Picture with Camera Icon
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primary, width: 3),
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withAlpha(51),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                          image: user.photoUrl.isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(user.photoUrl),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: user.photoUrl.isEmpty
                            ? const Center(
                                child: Icon(Icons.person, size: 60, color: Colors.grey),
                              )
                            : null,
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withAlpha(76),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // User Info with Better Layout
                  Column(
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const SizedBox(height: 20),

                      // Contact Information Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: AppStyles.cardDecoration.copyWith(
                          color: Colors.white,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Contact Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildInfoRow(
                              icon: Icons.email_outlined,
                              label: 'Email',
                              value: email,
                              color: AppColors.primary,
                            ),
                            if (phone.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              _buildInfoRow(
                                icon: Icons.phone_outlined,
                                label: 'Phone',
                                value: phone,
                                color: Colors.green,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Menu Items with Better Styling
                  _buildMenuItem(
                    context,
                    icon: Icons.edit_outlined,
                    title: "Edit Profile",
                    subtitle: "Update your personal information",
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildMenuItem(
                    context,
                    icon: Icons.calendar_month_outlined,
                    title: "My Appointments",
                    subtitle: "View and manage your bookings",
                    onTap: () => Navigator.pushNamed(context, AppRoutes.appointments),
                  ),
                  const SizedBox(height: 16),
                  _buildMenuItem(
                    context,
                    icon: Icons.info_outline,
                    title: "About Us",
                    subtitle: "Learn about our clinic",
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AboutUsScreen()),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Logout Button with Better Styling
                  Container(
                    width: double.infinity,
                    height: 55,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.error, AppColors.error.withAlpha(204)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.error.withAlpha(76),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextButton(
                      onPressed: () async {
                        await authService.signOut();
                        if (context.mounted) {
                          Navigator.pushNamedAndRemoveUntil(context, AppRoutes.signIn, (route) => false);
                        }
                      },
                      child: const Text(
                        "Log Out",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMenuItem(BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppStyles.cardDecoration.copyWith(
          color: Colors.white,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 24),
          ],
        ),
      ),
    );
  }
}
