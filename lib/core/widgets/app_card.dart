import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimensions.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? borderColor;
  final Color? background;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppDimensions.md),
    this.radius = AppDimensions.radiusLg,
    this.borderColor,
    this.background,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    return Material(
      color: background ?? AppColors.surface,
      borderRadius: shape,
      child: InkWell(
        onTap: onTap,
        borderRadius: shape,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: shape,
            border: Border.all(color: borderColor ?? AppColors.border),
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
