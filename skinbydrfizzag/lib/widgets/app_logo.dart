import 'package:flutter/material.dart';
import '../constants/colors.dart';

/// The brand wordmark ("Skin by Dr. Fizza G"). Falls back to a tasteful
/// gold monogram badge if the image asset ever fails to load, so the UI never
/// shows a broken-image box.
class AppLogo extends StatelessWidget {
  final double width;
  final double height;

  const AppLogo({super.key, this.width = 200, this.height = 80});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Skin by Dr. Fizza G',
      image: true,
      child: Image.asset(
        'lib/assets/logo.png',
        width: width,
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _MonogramFallback(
          size: height,
        ),
      ),
    );
  }
}

class _MonogramFallback extends StatelessWidget {
  final double size;
  const _MonogramFallback({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(size * 0.22),
      ),
      alignment: Alignment.center,
      child: Text(
        'SF',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.42,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
