import 'package:flutter/material.dart';

/// Premium rose-gold palette, tuned to the brand logo
/// ("Skin by Dr. Fizza G" — coppery rose-gold lockup with blush botanicals).
///
/// Rose-gold is paired with a champagne-gold accent (a classic luxe pairing)
/// and a whisper of muted sage for the medical/clinical surfaces. Every screen
/// reads its colours from here, so this file is the single source of truth for
/// the app's look.
class AppColors {
  // Brand — rose-gold / coppery blush taken from the logo.
  static const Color primary = Color(0xFFB76E79); // Rose gold
  static const Color primaryDark = Color(0xFF8E4E58); // Deep rose (gradient end)
  static const Color primaryLight = Color(0xFFF3D9D4); // Soft blush
  static const Color primarySoft = Color(0xFFFBF1EE); // Rose wash background

  static const Color secondary = Color(0xFFA9B7A0); // Muted sage — clinical calm
  static const Color accent = Color(0xFFCBA36B); // Champagne gold — luxe accent
  static const Color accentDark = Color(0xFF8E4E58); // Deep rose for gradients

  // Surfaces & backgrounds
  static const Color background = Color(0xFFFBF7F4); // Warm rosy off-white
  static const Color surface = Colors.white;
  static const Color surfaceMuted = Color(0xFFF5EDEA); // Rose-tinted muted
  static const Color divider = Color(0xFFECDFDA);

  // Text
  static const Color textPrimary = Color(0xFF2A2226); // Warm near-black
  static const Color textSecondary = Color(0xFF7A6B6E);
  static const Color textLight = Color(0xFFB3A3A5);

  // Semantic
  static const Color success = Color(0xFF5AA06B);
  static const Color error = Color(0xFFC84B5A); // Rose-red
  static const Color warning = Color(0xFFD79A4A);
  static const Color info = Color(0xFF6E8CB0);

  // Tinted card backgrounds (used by quick-access tiles)
  static const Color cardProcedures = Color(0xFFFBE7DF); // Blush
  static const Color cardShop = Color(0xFFF6E3EC); // Pink
  static const Color cardAiChat = Color(0xFFEFE6EE); // Soft mauve
  static const Color cardMedical = Color(0xFFE7EFE8); // Sage

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
