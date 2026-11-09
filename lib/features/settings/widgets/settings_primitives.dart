import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/icon_badge.dart';

/// Card with a heading, used for every block on the Settings screen.
class SectionCard extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget? trailing;
  final List<Widget> children;

  const SectionCard({
    super.key,
    required this.title,
    required this.children,
    this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                IconBadge(icon!),
                const SizedBox(width: AppDimensions.sm),
              ],
              Expanded(child: Text(title, style: AppTextStyles.heading4)),
              ?trailing,
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          ...children,
        ],
      ),
    );
  }
}

/// Label stacked above a control, matching the form rhythm in the mock.
class FieldBlock extends StatelessWidget {
  final String label;
  final Widget child;

  const FieldBlock({super.key, required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppTextStyles.labelMedium),
        const SizedBox(height: AppDimensions.xs),
        child,
      ],
    );
  }
}

/// Selectable card with a radio marker, used for the experience levels.
class ChoiceCard extends StatelessWidget {
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  const ChoiceCard({
    super.key,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.accent : AppColors.surface,
      borderRadius: BorderRadius.circular(AppDimensions.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radius),
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radius),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.border,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.labelLarge),
                    const SizedBox(height: AppDimensions.xs),
                    Text(
                      description,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppDimensions.sm),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                size: AppDimensions.iconSm + 2,
                color: selected ? AppColors.primary : AppColors.textHint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Title, caption and a switch inside a bordered row.
class ToggleRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const ToggleRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(
        left: AppDimensions.md,
        right: AppDimensions.xs,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.radius),
        border: Border.all(color: AppColors.border),
      ),
      child: SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: Text(title, style: AppTextStyles.labelMedium),
        subtitle: Text(
          subtitle,
          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
        ),
        value: value,
        activeThumbColor: AppColors.primary,
        onChanged: onChanged,
      ),
    );
  }
}

/// Small pill action used inside sections ("Save", "Update Password",
/// "Withdrawal now", "+ Add a Method").
class PillButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final IconData? icon;

  const PillButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: TextButton.icon(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
          ),
        ),
        icon: icon == null
            ? const SizedBox()
            : Icon(icon, size: AppDimensions.iconSm),
        label: Text(text, style: AppTextStyles.labelMedium),
      ),
    );
  }
}

/// Full-width accent CTA at the foot of a tab.
class SaveChangesButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;

  const SaveChangesButton({
    super.key,
    required this.onPressed,
    this.text = 'Save Changes',
  });

  @override
  Widget build(BuildContext context) {
    return AppButton(
      text: text,
      backgroundColor: AppColors.accent,
      textColor: AppColors.primary,
      borderRadius: AppDimensions.radiusXl,
      onPressed: onPressed,
    );
  }
}

/// Circular outline icon button, used for the pencil affordances.
class GhostIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  const GhostIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        backgroundColor: AppColors.surfaceVariant,
        foregroundColor: AppColors.textSecondary,
      ),
      icon: Icon(icon, size: AppDimensions.iconSm),
    );
  }
}
