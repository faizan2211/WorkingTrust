import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Circular service badge: the brand mark in white on the app's primary teal.
/// [asset] is a rasterised brand logo (used for identification only) and is
/// flattened to a single colour so every badge reads the same; [icon] is the
/// glyph used when a service has no artwork or the file fails to load.
class BrandBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? asset;
  final double size;

  const BrandBadge({
    super.key,
    required this.icon,
    required this.label,
    this.asset,
    this.size = 28,
  });

  @override
  Widget build(BuildContext context) {
    final glyph = Icon(icon, size: size * 0.6, color: AppColors.textOnPrimary);
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
      child: asset == null
          ? Center(child: glyph)
          : Padding(
              padding: EdgeInsets.all(size * 0.18),
              child: Image.asset(
                asset!,
                fit: BoxFit.contain,
                color: AppColors.textOnPrimary,
                semanticLabel: label,
                errorBuilder: (context, error, stack) => Center(child: glyph),
              ),
            ),
    );
  }
}
