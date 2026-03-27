import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../constants/styles.dart';
import '../../services/auth_service.dart';
import '../../services/about_us_service.dart';

class ManageAboutUsScreen extends StatefulWidget {
  const ManageAboutUsScreen({super.key});

  @override
  State<ManageAboutUsScreen> createState() => _ManageAboutUsScreenState();
}

class _ManageAboutUsScreenState extends State<ManageAboutUsScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _instagramController = TextEditingController();
  final TextEditingController _facebookController = TextEditingController();
  bool _isLoading = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminAndFetchData();
  }

  Future<void> _checkAdminAndFetchData() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    _isAdmin = await authService.isCurrentUserAdmin();

    if (!_isAdmin) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Access denied. Admin privileges required.")),
        );
        Navigator.pop(context); // Go back if not admin
      }
      return;
    }

    // Fetch from database
    final aboutUs = await AboutUsService().getAboutUs();
    if (aboutUs != null) {
      _descriptionController.text = aboutUs['description'] ?? '';
      _emailController.text = aboutUs['email'] ?? '';
      _phoneController.text = aboutUs['phone'] ?? '';
      _instagramController.text = aboutUs['instagram_url'] ?? '';
      _facebookController.text = aboutUs['facebook_url'] ?? '';
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveData() async {
    if (!_isAdmin) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Access denied. Admin privileges required.")),
        );
      }
      return;
    }

    setState(() => _isLoading = true);
    final error = await AboutUsService().upsertAboutUs(
      description: _descriptionController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      instagramUrl: _instagramController.text.trim(),
      facebookUrl: _facebookController.text.trim(),
    );
    setState(() => _isLoading = false);

    if (mounted) {
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $error')));
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("About Us updated successfully!")));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin && !_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text("Manage About Us"),
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.block, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text(
                "Access Denied",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                "Admin privileges required to access this page.",
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Manage About Us"),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save, color: AppColors.primary),
            onPressed: _isLoading ? null : _saveData,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Description", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 5,
                    decoration: AppStyles.inputDecoration("Enter company description..."),
                  ),
                  const SizedBox(height: 20),
                  const Text("Contact Information", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _emailController,
                    decoration: AppStyles.inputDecoration("Contact Email", prefixIcon: Icons.email),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phoneController,
                    decoration: AppStyles.inputDecoration("Phone Number", prefixIcon: Icons.phone),
                  ),
                  const SizedBox(height: 20),
                  const Text("Social Media Links", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _instagramController,
                    decoration: AppStyles.inputDecoration("Instagram URL", prefixIcon: Icons.camera_alt),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _facebookController,
                    decoration: AppStyles.inputDecoration("Facebook URL", prefixIcon: Icons.facebook),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _saveData,
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                      child: const Text("Save Changes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
