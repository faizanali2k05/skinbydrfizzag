import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:skinbydrfizzag/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/colors.dart';
import '../../constants/strings.dart';
import '../../constants/styles.dart';
import '../../routes/app_routes.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/app_logo.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authService = Provider.of<AuthService>(context, listen: false);
    final result = await authService.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );

    if (result == null) {
      // Check role
      final role = await authService.getCurrentUserRole();
      // Persist 'remember me' choice
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('remember_me', _rememberMe);
        if (_rememberMe) {
          await prefs.setString('last_route', role == 'admin' ? AppRoutes.adminPanel : AppRoutes.home);
        }
      } catch (_) {}
      setState(() => _isLoading = false);

      if (mounted) {
        if (role == 'admin') {
          Navigator.pushReplacementNamed(context, AppRoutes.adminPanel);
        } else {
          Navigator.pushReplacementNamed(context, AppRoutes.home);
        }
      }
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                const Center(child: AppLogo(width: 240, height: 90)),
                const SizedBox(height: 40),
                Text(AppStrings.signIn, style: AppStyles.h1),
                const SizedBox(height: 8),
                Text("Please sign in to continue", style: AppStyles.bodyMedium),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _emailController,
                  decoration: AppStyles.inputDecoration("Email / Phone Number", prefixIcon: Icons.email_outlined),
                  validator: (value) => value!.isEmpty ? 'Please enter your email or phone' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: AppStyles.inputDecoration(
                    AppStrings.password,
                    prefixIcon: Icons.lock_outlined,
                  ).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: AppColors.textSecondary),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (value) => value!.isEmpty ? 'Please enter your password' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: _rememberMe,
                          activeColor: AppColors.primary,
                          onChanged: (value) => setState(() => _rememberMe = value ?? false),
                        ),
                        Text(AppStrings.rememberMe, style: AppStyles.bodyMedium),
                      ],
                    ),
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, AppRoutes.passwordRecovery),
                      child: Text(AppStrings.forgotPassword, style: AppStyles.bodyMedium.copyWith(color: AppColors.primary)),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                CustomButton(
                  text: AppStrings.signIn,
                  onPressed: _handleSignIn,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Don't have an account?", style: AppStyles.bodyMedium),
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, AppRoutes.signUp),
                      child: Text("Sign Up", style: AppStyles.bodyMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
