import 'package:flutter/material.dart';

class AppColors {
  // Brand — refined rose-gold built around the existing #D4AF37 mustard tone.
  static const Color primary = Color(0xFFC9A24B); // Warm gold
  static const Color primaryDark = Color(0xFF9A7A2D); // Deeper gold for gradient ends
  static const Color primaryLight = Color(0xFFF5E5B0); // Cream/vanilla
  static const Color primarySoft = Color(0xFFFBF4E1); // Wash for tinted backgrounds

  static const Color secondary = Color(0xFF6FB7A0); // Sage teal — medical/health
  static const Color accent = Color(0xFFE48BA1); // Soft rose — beauty
  static const Color accentDark = Color(0xFFB7536F);

  // Surfaces & backgrounds
  static const Color background = Color(0xFFFAF7F2); // Warm off-white
  static const Color surface = Colors.white;
  static const Color surfaceMuted = Color(0xFFF3EFE7);
  static const Color divider = Color(0xFFEDE6D6);

  // Text
  static const Color textPrimary = Color(0xFF1F1B16);
  static const Color textSecondary = Color(0xFF6B6457);
  static const Color textLight = Color(0xFFA9A294);

  // Semantic
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFD64545);
  static const Color warning = Color(0xFFE0A02C);
  static const Color info = Color(0xFF4A90E2);

  // Tinted card backgrounds (used by quick-access tiles)
  static const Color cardProcedures = Color(0xFFFFF3D6);
  static const Color cardShop = Color(0xFFFCE4EC);
  static const Color cardAiChat = Color(0xFFDDF1EC);
  static const Color cardMedical = Color(0xFFEAF3E5);

  // Convenience gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient subtlePrimaryGradient = LinearGradient(
    colors: [primarySoft, surface],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient errorGradient = LinearGradient(
    colors: [error, accentDark],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}
