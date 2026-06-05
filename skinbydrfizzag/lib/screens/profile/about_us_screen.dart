import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/colors.dart';
import '../../constants/styles.dart';
import '../../models/clinic_location_model.dart';
import '../../services/about_us_service.dart';
import '../../services/clinic_location_service.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/soft_card.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('About Us'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: AboutUsService().getAboutUs(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data ?? <String, dynamic>{};
          final description = (data['description'] as String? ?? '').trim();
          final email = (data['email'] as String? ?? '').trim();
          final phone = (data['phone'] as String? ?? '').trim();
          final instagram = (data['instagram_url'] as String? ?? '').trim();
          final facebook = (data['facebook_url'] as String? ?? '').trim();

          if (description.isEmpty &&
              email.isEmpty &&
              phone.isEmpty &&
              instagram.isEmpty &&
              facebook.isEmpty) {
            return const EmptyState(
              icon: Icons.info_outline_rounded,
              title: 'No clinic information yet',
              message:
                  'The admin can add the clinic\'s details from the admin panel.',
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHero(),
                const SizedBox(height: 22),
                if (description.isNotEmpty) ...[
                  Text('Who we are', style: AppStyles.h3),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: AppStyles.bodyLarge.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 22),
                ],
                if (email.isNotEmpty || phone.isNotEmpty) ...[
                  Text('Contact', style: AppStyles.h3),
                  const SizedBox(height: 10),
                  SoftCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        if (email.isNotEmpty)
                          _contactRow(
                            icon: Icons.email_outlined,
                            label: 'Email',
                            value: email,
                            onTap: () => _launchEmail(email),
                          ),
                        if (email.isNotEmpty && phone.isNotEmpty)
                          const Divider(height: 1, indent: 60),
                        if (phone.isNotEmpty)
                          _contactRow(
                            icon: Icons.phone_outlined,
                            label: 'Phone',
                            value: phone,
                            onTap: () => _launchPhone(phone),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                ],
                StreamBuilder<List<ClinicLocationModel>>(
                  stream: ClinicLocationService().getLocationsStream(
                    activeOnly: true,
                  ),
                  builder: (context, locationSnapshot) {
                    final locations = locationSnapshot.data ?? [];
                    if (locations.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Locations', style: AppStyles.h3),
                        const SizedBox(height: 10),
                        ...locations.map(
                          (location) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: SoftCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    location.name,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  _plainInfoRow(
                                    Icons.location_on_outlined,
                                    location.address,
                                  ),
                                  if (location.phone.isNotEmpty)
                                    _plainInfoRow(
                                      Icons.phone_outlined,
                                      location.phone,
                                    ),
                                  if (location.mapUrl.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: TextButton.icon(
                                        onPressed: () =>
                                            _launchUrl(location.mapUrl),
                                        icon: const Icon(Icons.map_outlined),
                                        label: const Text('Open map'),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    );
                  },
                ),
                if (instagram.isNotEmpty || facebook.isNotEmpty) ...[
                  Text('Follow us', style: AppStyles.h3),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (instagram.isNotEmpty)
                        Expanded(
                          child: _socialButton(
                            label: 'Instagram',
                            icon: Icons.camera_alt_rounded,
                            color: AppColors.accent,
                            onTap: () => _launchUrl(instagram),
                          ),
                        ),
                      if (instagram.isNotEmpty && facebook.isNotEmpty)
                        const SizedBox(width: 12),
                      if (facebook.isNotEmpty)
                        Expanded(
                          child: _socialButton(
                            label: 'Facebook',
                            icon: Icons.facebook_rounded,
                            color: AppColors.info,
                            onTap: () => _launchUrl(facebook),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primarySoft, AppColors.surface],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withAlpha(40)),
      ),
      child: Column(
        children: [
          const AppLogo(width: 200, height: 80),
          const SizedBox(height: 12),
          const Text(
            'Skin By Dr. Fizza G',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Aesthetic care, made personal.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _contactRow({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary, size: 18),
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
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _socialButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withAlpha(60)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _plainInfoRow(IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: AppStyles.bodySmall.copyWith(height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.tryParse(urlString);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchEmail(String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
}
