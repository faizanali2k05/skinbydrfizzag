import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../constants/styles.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_button.dart';

class EditProfileScreen extends StatefulWidget {
  final String? userId; // optional userId for admin to edit other users
  const EditProfileScreen({super.key, this.userId});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  bool _initializing = true;
  File? _imageFile;
  String? _currentImageUrl;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = await authService.getCurrentUserDocument();
    if (!mounted) return;
    if (user != null) {
      _nameController.text = user.name;
      _emailController.text = user.email;
      _phoneController.text = user.phone;
      _currentImageUrl = user.photoUrl;
    }
    setState(() => _initializing = false);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      String? photoUrl = _currentImageUrl;
      if (_imageFile != null) {
        final uid = authService.currentUserId;
        final fileName =
            'profile_${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final uploadedUrl = await authService.uploadImage(
          'profile_photos',
          '$uid/$fileName',
          _imageFile!,
        );
        if (uploadedUrl != null) photoUrl = uploadedUrl;
      }

      final error = await authService.updateUserProfile(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        photoUrl: photoUrl,
      );
      if (error != null) throw Exception(error);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Edit Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _initializing
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      _buildAvatar(),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.photo_library_outlined,
                            size: 18),
                        label: const Text('Change photo'),
                      ),
                      const SizedBox(height: 16),
                      _label('Full name'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: AppStyles.inputDecoration(
                          'Your name',
                          prefixIcon: Icons.person_outline,
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Name is required'
                                : null,
                      ),
                      const SizedBox(height: 14),
                      _label('Email'),
                      const SizedBox(height: 6),
                      TextFormField(
                        enabled: widget.userId == null,
                        controller: _emailController,
                        decoration: AppStyles.inputDecoration(
                          'Email',
                          prefixIcon: Icons.email_outlined,
                        ).copyWith(
                          helperText: widget.userId == null
                              ? 'Email cannot be changed once set'
                              : null,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _label('Phone'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: AppStyles.inputDecoration(
                          'Phone number',
                          prefixIcon: Icons.phone_outlined,
                        ),
                      ),
                      const SizedBox(height: 32),
                      CustomButton(
                        text: 'Save changes',
                        onPressed: _save,
                        isLoading: _isLoading,
                        icon: Icons.check_rounded,
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _label(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Center(
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            width: 120,
            height: 120,
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
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface,
                  image: _imageFile != null
                      ? DecorationImage(
                          image: FileImage(_imageFile!),
                          fit: BoxFit.cover,
                        )
                      : (_currentImageUrl != null &&
                              _currentImageUrl!.isNotEmpty)
                          ? DecorationImage(
                              image: NetworkImage(_currentImageUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                ),
                child:
                    (_imageFile == null &&
                            (_currentImageUrl == null ||
                                _currentImageUrl!.isEmpty))
                        ? const Center(
                            child: Icon(
                              Icons.person,
                              size: 60,
                              color: AppColors.textLight,
                            ),
                          )
                        : null,
              ),
            ),
          ),
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
