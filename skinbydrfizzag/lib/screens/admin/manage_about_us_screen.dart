import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../constants/styles.dart';
import '../../models/clinic_location_model.dart';
import '../../services/about_us_service.dart';
import '../../services/auth_service.dart';
import '../../services/clinic_location_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/empty_state.dart';

class ManageAboutUsScreen extends StatefulWidget {
  const ManageAboutUsScreen({super.key});

  @override
  State<ManageAboutUsScreen> createState() => _ManageAboutUsScreenState();
}

class _ManageAboutUsScreenState extends State<ManageAboutUsScreen> {
  final ClinicLocationService _locationService = ClinicLocationService();
  final _descriptionController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _instagramController = TextEditingController();
  final _facebookController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isAdmin = false;

  Future<void> _showLocationDialog({ClinicLocationModel? location}) async {
    final nameController = TextEditingController(text: location?.name ?? '');
    final addressController = TextEditingController(
      text: location?.address ?? '',
    );
    final phoneController = TextEditingController(text: location?.phone ?? '');
    final emailController = TextEditingController(text: location?.email ?? '');
    final mapUrlController = TextEditingController(
      text: location?.mapUrl ?? '',
    );
    final sortController = TextEditingController(
      text: (location?.sortOrder ?? 0).toString(),
    );
    bool isActive = location?.isActive ?? true;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(location == null ? 'Add location' : 'Edit location'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: AppStyles.inputDecoration('Location name'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: addressController,
                  maxLines: 2,
                  decoration: AppStyles.inputDecoration('Address'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: AppStyles.inputDecoration('Phone'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: AppStyles.inputDecoration('Email'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: mapUrlController,
                  keyboardType: TextInputType.url,
                  decoration: AppStyles.inputDecoration('Map URL'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: sortController,
                  keyboardType: TextInputType.number,
                  decoration: AppStyles.inputDecoration('Sort order'),
                ),
                const SizedBox(height: 4),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: isActive,
                  title: const Text('Active'),
                  onChanged: (value) => setDialogState(() => isActive = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final newLocation = ClinicLocationModel(
                  id: location?.id ?? '',
                  name: nameController.text,
                  address: addressController.text,
                  phone: phoneController.text,
                  email: emailController.text,
                  mapUrl: mapUrlController.text,
                  sortOrder: int.tryParse(sortController.text) ?? 0,
                  isActive: isActive,
                );
                final error = await _locationService.upsertLocation(
                  newLocation,
                );
                if (!dialogContext.mounted) return;
                if (error != null) {
                  ScaffoldMessenger.of(
                    dialogContext,
                  ).showSnackBar(SnackBar(content: Text('Error: $error')));
                  return;
                }
                Navigator.pop(dialogContext);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
    addressController.dispose();
    phoneController.dispose();
    emailController.dispose();
    mapUrlController.dispose();
    sortController.dispose();
  }

  Future<void> _deleteLocation(ClinicLocationModel location) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete location'),
        content: Text('Remove ${location.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final error = await _locationService.deleteLocation(location.id);
    if (!mounted || error == null) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Error: $error')));
  }

  @override
  void initState() {
    super.initState();
    _checkAdminAndFetch();
  }

  Future<void> _checkAdminAndFetch() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    _isAdmin = await authService.isCurrentUserAdmin();

    if (!_isAdmin) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      return;
    }

    final aboutUs = await AboutUsService().getAboutUs();
    if (aboutUs != null) {
      _descriptionController.text = aboutUs['description'] ?? '';
      _emailController.text = aboutUs['email'] ?? '';
      _phoneController.text = aboutUs['phone'] ?? '';
      _instagramController.text = aboutUs['instagram_url'] ?? '';
      _facebookController.text = aboutUs['facebook_url'] ?? '';
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final error = await AboutUsService().upsertAboutUs(
      description: _descriptionController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      instagramUrl: _instagramController.text.trim(),
      facebookUrl: _facebookController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $error'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('About Us updated successfully'),
        backgroundColor: AppColors.success,
      ),
    );
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _instagramController.dispose();
    _facebookController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Manage About Us'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isAdmin) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Manage About Us'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const EmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Access denied',
          message: 'Admin privileges required to access this page.',
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Manage About Us'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_rounded, color: AppColors.primary),
            tooltip: 'Save',
            onPressed: _isSaving ? null : _save,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Description', style: AppStyles.h3),
              const SizedBox(height: 10),
              TextField(
                controller: _descriptionController,
                maxLines: 5,
                decoration: AppStyles.inputDecoration(
                  'Tell patients about Skin By Dr. Fizza...',
                ),
              ),
              const SizedBox(height: 22),
              Text('Contact', style: AppStyles.h3),
              const SizedBox(height: 10),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: AppStyles.inputDecoration(
                  'Contact email',
                  prefixIcon: Icons.email_outlined,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: AppStyles.inputDecoration(
                  'Phone number',
                  prefixIcon: Icons.phone_outlined,
                ),
              ),
              const SizedBox(height: 22),
              Text('Social media', style: AppStyles.h3),
              const SizedBox(height: 10),
              TextField(
                controller: _instagramController,
                keyboardType: TextInputType.url,
                decoration: AppStyles.inputDecoration(
                  'Instagram URL',
                  prefixIcon: Icons.camera_alt_rounded,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _facebookController,
                keyboardType: TextInputType.url,
                decoration: AppStyles.inputDecoration(
                  'Facebook URL',
                  prefixIcon: Icons.facebook_rounded,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: Text('Clinic locations', style: AppStyles.h3),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_location_alt_rounded),
                    tooltip: 'Add location',
                    color: AppColors.primary,
                    onPressed: () => _showLocationDialog(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              StreamBuilder<List<ClinicLocationModel>>(
                stream: _locationService.getLocationsStream(),
                builder: (context, snapshot) {
                  final locations = snapshot.data ?? [];
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (locations.isEmpty) {
                    return OutlinedButton.icon(
                      onPressed: () => _showLocationDialog(),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add clinic location'),
                    );
                  }
                  return Column(
                    children: locations.map((location) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          collapsedShape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(color: AppColors.divider),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(color: AppColors.divider),
                          ),
                          title: Text(
                            location.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            location.address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!location.isActive)
                                const Icon(
                                  Icons.visibility_off_outlined,
                                  size: 18,
                                  color: AppColors.warning,
                                ),
                              const Icon(Icons.expand_more_rounded),
                            ],
                          ),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            12,
                            0,
                            12,
                            12,
                          ),
                          children: [
                            if (location.phone.isNotEmpty)
                              _locationDetail(
                                Icons.phone_outlined,
                                location.phone,
                              ),
                            if (location.email.isNotEmpty)
                              _locationDetail(
                                Icons.email_outlined,
                                location.email,
                              ),
                            if (location.mapUrl.isNotEmpty)
                              _locationDetail(
                                Icons.map_outlined,
                                location.mapUrl,
                              ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () =>
                                      _showLocationDialog(location: location),
                                  icon: const Icon(Icons.edit_rounded),
                                  label: const Text('Edit'),
                                ),
                                TextButton.icon(
                                  onPressed: () => _deleteLocation(location),
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text('Delete'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.error,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 32),
              CustomButton(
                text: 'Save changes',
                onPressed: _save,
                isLoading: _isSaving,
                icon: Icons.check_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _locationDetail(IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: AppStyles.bodySmall)),
        ],
      ),
    );
  }
}
