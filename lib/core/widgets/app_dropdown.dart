import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimensions.dart';

/// Compact dropdown used by the profile section filters. [filled] renders the
/// borderless tinted variant used inside labelled filter forms.
class AppDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final ValueChanged<String>? onChanged;
  final IconData? icon;
  final double? width;
  final bool filled;

  const AppDropdown({
    super.key,
    required this.value,
    required this.items,
    this.onChanged,
    this.icon = Icons.calendar_today_outlined,
    this.width,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final onSelect = onChanged;
    final menu = [
      for (final item in items)
        DropdownMenuItem(
          value: item,
          child: Text(item, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
    ];
    final tone = filled ? AppColors.surfaceVariant : AppColors.surface;

    return Container(
      width: width,
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
      decoration: BoxDecoration(
        color: tone,
        borderRadius: BorderRadius.circular(
          filled ? AppDimensions.radius : AppDimensions.radiusXl,
        ),
        border: Border.all(
          color: filled ? AppColors.surfaceVariant : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: AppDimensions.iconSm,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppDimensions.sm),
          ],
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                items: menu,
                icon: const Icon(
                  Icons.keyboard_arrow_down,
                  color: AppColors.textSecondary,
                ),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                onChanged: onSelect == null
                    ? null
                    : (choice) {
                        if (choice != null) onSelect(choice);
                      },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
