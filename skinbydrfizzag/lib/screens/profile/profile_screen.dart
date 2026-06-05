import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../constants/styles.dart';
import '../../models/user_model.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/soft_card.dart';
import 'about_us_screen.dart';
import 'edit_profile_screen.dart';
import 'user_profile_screen.dart';

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
        child: FutureBuilder<UserModel?>(
          future: authService.getCurrentUserDocument(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data == null) {
              return EmptyState(
                icon: Icons.person_off_outlined,
                title: 'Profile not found',
                message:
                    'Your profile is being created. Please retry in a moment.',
                actionLabel: 'Retry',
                onAction: () => setState(() {}),
              );
            }

            final user = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                _buildHeader(user),
                const SizedBox(height: 18),
                _buildInfoCard(user),
                const SizedBox(height: 18),
                Text('Account', style: AppStyles.h3),
                const SizedBox(height: 12),
                _buildMenuItem(
                  icon: Icons.edit_outlined,
                  title: 'Edit Profile',
                  subtitle: 'Update your personal information',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EditProfileScreen(),
                    ),
                  ),
                ),
                _buildMenuItem(
                  icon: Icons.account_circle_outlined,
                  title: 'My Profile',
                  subtitle: 'Full profile and visit history',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const UserProfileScreen(),
                    ),
                  ),
                ),
                _buildMenuItem(
                  icon: Icons.calendar_month_outlined,
                  title: 'My Appointments',
                  subtitle: 'View and manage your bookings',
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.appointments),
                ),
                const SizedBox(height: 18),
                Text('Clinic', style: AppStyles.h3),
                const SizedBox(height: 12),
                _buildMenuItem(
                  icon: Icons.info_outline_rounded,
                  title: 'About Us',
                  subtitle: 'Learn about Skin By Dr. Fizza G',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AboutUsScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                _buildLogoutButton(authService),
                const SizedBox(height: 20),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(UserModel user) {
    final initial =
        user.name.trim().isNotEmpty ? user.name.trim()[0].toUpperCase() : '?';
    return Center(
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.primaryGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withAlpha(60),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(3),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surface,
                    image: user.photoUrl.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(user.photoUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: user.photoUrl.isEmpty
                      ? Center(
                          child: Text(
                            initial,
                            style: const TextStyle(
                              fontSize: 36,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      : null,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const EditProfileScreen(),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                  ),
                  child: const Icon(
                    Icons.edit_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            user.name.isEmpty ? 'User' : user.name,
            style: AppStyles.h1,
          ),
          if (user.email.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(user.email, style: AppStyles.bodySmall),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard(UserModel user) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Contact information', style: AppStyles.h3),
          const SizedBox(height: 12),
          _infoRow(
            icon: Icons.email_outlined,
            color: AppColors.primary,
            label: 'Email',
            value: user.email.isEmpty ? 'Not provided' : user.email,
          ),
          if (user.phone.isNotEmpty) ...[
            const Divider(height: 24),
            _infoRow(
              icon: Icons.phone_outlined,
              color: AppColors.success,
              label: 'Phone',
              value: user.phone,
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withAlpha(30),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppStyles.bodySmall),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton(AuthService authService) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton.icon(
        onPressed: () async {
          await authService.signOut();
          if (!mounted) return;
          if (!context.mounted) return;
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.signIn,
            (route) => false,
          );
        },
        icon: const Icon(Icons.logout_rounded, color: AppColors.error),
        label: const Text(
          'Log out',
          style: TextStyle(color: AppColors.error),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: BorderSide(color: AppColors.error.withAlpha(80)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
