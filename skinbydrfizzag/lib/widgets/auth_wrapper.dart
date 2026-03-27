import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:skinbydrfizzag/models/user_model.dart';
import 'package:skinbydrfizzag/screens/auth/welcome_screen.dart';
import 'package:skinbydrfizzag/screens/home/home_screen.dart';
import 'package:skinbydrfizzag/screens/admin/simple_admin_screen.dart';
import 'package:skinbydrfizzag/services/auth_service.dart';
import 'package:skinbydrfizzag/constants/colors.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final cachedUser = authService.currentUser;

    return StreamBuilder<UserModel?>(
      stream: authService.authStateChanges,
      initialData: cachedUser,
      builder: (context, snapshot) {
        final user = snapshot.data ?? cachedUser;

        if (user != null) {
          // If we already have the role loaded, just go to the screen
          if (user.role.isNotEmpty) {
            return user.role == 'admin'
                ? const SimpleAdminScreen()
                : const HomeScreen();
          }

          // Otherwise, fetch role but don't block indefinitely
          return FutureBuilder<String>(
            future: authService.getCurrentUserRole(),
            builder: (context, roleSnapshot) {
              if (roleSnapshot.hasData) {
                return roleSnapshot.data == 'admin'
                    ? const SimpleAdminScreen()
                    : const HomeScreen();
              }
              // Transient loading state
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              );
            },
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting && cachedUser == null) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        return const WelcomeScreen();
      },
    );
  }
}
