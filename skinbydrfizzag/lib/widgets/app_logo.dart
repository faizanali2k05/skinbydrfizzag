import 'package:flutter/material.dart';
import '../constants/colors.dart';

/// The brand logo for "Skin by Dr. Fizza G".
///
/// Two variants:
///  * [AppLogo] (default) — the horizontal wordmark, best on light surfaces.
///  * [AppLogo.badge] — the transparent square lockup, for compact spots
///    (app bars, avatars, nav). Optionally wrapped in a soft rounded card.
///
/// Both fall back to a tasteful gold monogram badge if the asset ever fails to
/// load, so the UI never shows a broken-image box.
class AppLogo extends StatelessWidget {
  final double width;
  final double height;
  final String _asset;
  final bool _framed;

  const AppLogo({super.key, this.width = 220, this.height = 96})
    : _asset = 'lib/assets/logo.png',
      _framed = false;

  /// Compact transparent square mark. Set [framed] to sit it inside a soft
  /// rounded white card (nice on tinted backgrounds).
  const AppLogo.badge({super.key, double size = 56, bool framed = false})
    : width = size,
      height = size,
      _asset = 'lib/assets/logo_square.png',
      _framed = framed;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      _asset,
      width: width,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) =>
          _MonogramFallback(size: height),
    );

    final logo = Semantics(label: 'Skin by Dr. Fizza G', image: true, child: image);

    if (!_framed) return logo;

    return Container(
      padding: EdgeInsets.all(width * 0.12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(width * 0.26),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: logo,
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
