import 'package:flutter/material.dart';
import 'constants/colors.dart';
import 'constants/strings.dart';
import 'routes/app_routes.dart';
import 'widgets/auth_wrapper.dart';

class SkinbyFizaApp extends StatelessWidget {
  const SkinbyFizaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: AppColors.primary,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.secondary,
        ),
        scaffoldBackgroundColor: AppColors.background,
        useMaterial3: true,
        fontFamily: 'Poppins', 
      ),
      // Set AuthWrapper as the entry point of the app UI.
      home: const AuthWrapper(),
      routes: AppRoutes.routes,
    );
  }
}
