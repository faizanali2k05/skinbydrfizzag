import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'constants/colors.dart';
import 'constants/strings.dart';
import 'constants/styles.dart';
import 'routes/app_routes.dart';
import 'widgets/auth_wrapper.dart';

class SkinbyFizaApp extends StatelessWidget {
  const SkinbyFizaApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.surface,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppStyles.themeData(),
      home: const AuthWrapper(),
      routes: AppRoutes.routes,
      builder: (context, child) {
        // Clamp font scale so layouts don't break on extreme accessibility settings.
        final mq = MediaQuery.of(context);
        final scale = mq.textScaler.clamp(
          minScaleFactor: 0.9,
          maxScaleFactor: 1.2,
        );
        return MediaQuery(
          data: mq.copyWith(textScaler: scale),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
