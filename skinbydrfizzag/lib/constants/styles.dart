import 'package:flutter/material.dart';
import 'colors.dart';

class AppStyles {
  // ==================== Typography ====================
  static const TextStyle displayLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: AppColors.textPrimary,
    height: 1.15,
  );

  static const TextStyle h1 = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.2,
    letterSpacing: -0.2,
  );

  static const TextStyle h2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.25,
  );

  static const TextStyle h3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    color: AppColors.textSecondary,
    height: 1.45,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  static const TextStyle overline = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.6,
    color: AppColors.primary,
  );

  static const TextStyle buttonText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    letterSpacing: 0.2,
  );

  // ==================== Spacing ====================
  static const double gapXS = 4;
  static const double gapS = 8;
  static const double gapM = 12;
  static const double gapL = 16;
  static const double gapXL = 24;
  static const double gapXXL = 32;

  static const EdgeInsets screenPadding = EdgeInsets.symmetric(
    horizontal: 20,
    vertical: 16,
  );

  static const EdgeInsets screenPaddingTight = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 12,
  );

  // ==================== Card decorations ====================
  static final BoxDecoration cardDecoration = BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(18),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withAlpha(12),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  );

  static final BoxDecoration cardSoftDecoration = BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: AppColors.divider, width: 1),
  );

  static final BoxDecoration tintedCardDecoration = BoxDecoration(
    color: AppColors.primarySoft,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: AppColors.primary.withAlpha(40)),
  );

  // ==================== Inputs ====================
  static InputDecoration inputDecoration(String hintText, {IconData? prefixIcon}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: AppColors.textLight),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: AppColors.textSecondary, size: 20)
          : null,
      filled: true,
      fillColor: AppColors.surfaceMuted,
      contentPadding:
          const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error, width: 1.4),
      ),
    );
  }

  // ==================== Status colours ====================
  static Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'booked':
        return AppColors.info;
      case 'pending':
        return AppColors.warning;
      case 'cancelled':
      case 'missed':
        return AppColors.error;
      case 'completed':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }

  // ==================== Global ThemeData ====================
  static ThemeData themeData() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'Poppins',
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        error: AppColors.error,
        brightness: Brightness.light,
      ),
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 18,
          fontFamily: 'Poppins',
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceMuted,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
        hintStyle: const TextStyle(color: AppColors.textLight),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding:
              const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: 'Poppins',
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.2),
          padding:
              const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: 'Poppins',
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontFamily: 'Poppins',
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: AppColors.divider),
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: AppColors.surfaceMuted,
        labelStyle: TextStyle(color: AppColors.textPrimary, fontSize: 12),
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontFamily: 'Poppins',
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}
