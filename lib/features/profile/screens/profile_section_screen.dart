import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/icon_badge.dart';

/// Stand-in for a profile section whose UI reference has not been supplied yet.
/// Each entry keeps its own route so the real screen can replace it in place.
class ProfileSectionScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const ProfileSectionScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconBadge(icon, size: AppDimensions.iconXl + 16),
                const SizedBox(height: AppDimensions.md),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.heading3,
                ),
                const SizedBox(height: AppDimensions.xs),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppDimensions.md),
                Text(
                  'Design reference for this screen has not been provided yet.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
