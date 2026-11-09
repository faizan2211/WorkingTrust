import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimensions.dart';
import '../../app/theme/app_text_styles.dart';

/// The tinted header a profile module is pushed under: the shell's teal strip,
/// with the module's title and the one-line description that names what the
/// screen holds. Deliberately carries no brand mark — that belongs to the
/// shell alone, and repeating it on a page reached from the shell is noise.
class ModuleAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  const ModuleAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.bottom,
  });

  /// Tab labels have to be re-picked for a tinted bar: the app's usual teal
  /// would disappear into it.
  static const Color tabBarLabel = AppColors.textOnPrimary;
  static const Color tabBarUnselected = AppColors.accent;
  static const Color tabBarIndicator = AppColors.accent;

  @override
  Size get preferredSize => Size.fromHeight(
    AppDimensions.appBarHeight + (bottom?.preferredSize.height ?? 0),
  );

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.textOnPrimary,
      // The bar is dark, so the clock and battery have to be light.
      systemOverlayStyle: SystemUiOverlayStyle.light,
      // Without this the bar takes on the theme's scroll tint as soon as the
      // module's list moves under it.
      scrolledUnderElevation: 0,
      centerTitle: false,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.heading4.copyWith(
              color: AppColors.textOnPrimary,
            ),
          ),
          if (subtitle != null)
            // The line that tells the user what this screen is for, so the
            // header answers the question a bare title leaves open.
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.accent),
            ),
        ],
      ),
      actions: actions,
      bottom: bottom,
    );
  }
}
