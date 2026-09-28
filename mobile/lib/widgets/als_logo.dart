import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Renders the ALS logo from `assets/logo/als_logo.png`.
///
/// If the asset is missing, the app falls back to a clean built-in vector badge
/// so the UI always renders.
class ALSLogo extends StatelessWidget {
  const ALSLogo({
    super.key,
    this.width,
    this.height,
    this.onSurface = false,
  });

  /// Target width for the logo. The image scales to fit while preserving its
  /// aspect ratio.
  final double? width;

  /// Optional target height. If omitted, the image is sized by [width].
  final double? height;

  /// When true, render tuned for a colored (green) background — used by the
  /// vector fallback badge so it shows as a white badge.
  final bool onSurface;

  @override
  Widget build(BuildContext context) {
    final double fallbackSize = height ?? width ?? 160;
    return Image.asset(
      'assets/logo/als_logo.png',
      width: width,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stack) =>
          _VectorBadge(size: fallbackSize, onSurface: onSurface),
    );
  }
}

/// Fallback "ALS" emblem drawn with widgets.
class _VectorBadge extends StatelessWidget {
  const _VectorBadge({required this.size, required this.onSurface});

  final double size;
  final bool onSurface;

  @override
  Widget build(BuildContext context) {
    final Color green = AppTheme.alsGreen;
    final Color badgeColor = onSurface ? Colors.white : green;
    final Color inkColor = onSurface ? green : Colors.white;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: badgeColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: onSurface ? green.withValues(alpha: 0.15) : Colors.white24,
          width: size * 0.02,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: size * 0.08,
            offset: Offset(0, size * 0.03),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'ALS',
            style: TextStyle(
              color: inkColor,
              fontSize: size * 0.40,
              fontWeight: FontWeight.w800,
              letterSpacing: size * 0.01,
              height: 1.0,
            ),
          ),
          SizedBox(height: size * 0.04),
          Container(
            width: size * 0.46,
            height: size * 0.012,
            color: inkColor.withValues(alpha: 0.85),
          ),
          SizedBox(height: size * 0.05),
          Text(
            'LISTEN',
            style: TextStyle(
              color: inkColor,
              fontSize: size * 0.105,
              fontWeight: FontWeight.w700,
              letterSpacing: size * 0.03,
            ),
          ),
        ],
      ),
    );
  }
}
