import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../constants/styles.dart';
import '../../widgets/custom_button.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';

import 'dart:io';
import 'package:image_picker/image_picker.dart';

class EditProfileScreen extends StatefulWidget {
  final String? userId; // Optional userId for admin to edit other users

  const EditProfileScreen({super.key, this.userId});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
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
    if (user != null) {
      setState(() {
        _nameController.text = user.name;
        _emailController.text = user.email;
        _phoneController.text = user.phone;
        _currentImageUrl = user.photoUrl;
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
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
        title: const Text("Edit Profile"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary, width: 2),
                      color: Colors.white,
                      image: _imageFile != null
                          ? DecorationImage(image: FileImage(_imageFile!), fit: BoxFit.cover)
                          : (_currentImageUrl != null
                              ? DecorationImage(image: NetworkImage(_currentImageUrl!), fit: BoxFit.cover)
                              : null),
                    ),
                    child: (_imageFile == null && _currentImageUrl == null)
                        ? const Center(
                            child: Icon(Icons.person, size: 60, color: Colors.grey),
                          )
                        : null,
                  ),
                ),
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _nameController,
              decoration: AppStyles.inputDecoration(
                "Full Name",
                prefixIcon: Icons.person_outline,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              enabled: widget.userId == null,
              controller: _emailController,
              decoration: AppStyles.inputDecoration(
                "Email",
                prefixIcon: Icons.email_outlined,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _phoneController,
              decoration: AppStyles.inputDecoration(
                "Phone Number",
                prefixIcon: Icons.phone_outlined,
              ),
            ),
            const SizedBox(height: 40),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : CustomButton(
                    text: "Save Changes",
                    onPressed: () async {
                      if (_nameController.text.isEmpty) return;

                      setState(() => _isLoading = true);
                      try {
                        final authService = Provider.of<AuthService>(context, listen: false);
                        final error = await authService.updateUserProfile(
                          name: _nameController.text.trim(),
                          phone: _phoneController.text.trim(),
                          // photo upload logic could go here
                        );
                        if (error != null) {
                          throw Exception(error);
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Profile Updated Successfully!')),
                          );
                          Navigator.pop(context);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _isLoading = false);
                      }
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
