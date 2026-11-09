import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

class IconBadge extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color color;
  final Color background;

  const IconBadge(
    this.icon, {
    super.key,
    this.size = 34,
    this.color = AppColors.primary,
    this.background = AppColors.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(icon, size: size * 0.5, color: color),
    );
  }
}
