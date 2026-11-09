import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_tag.dart';
import '../../packages/models/package_entry.dart';
import '../data/membership_plans.dart';

class PlanCard extends StatelessWidget {
  final MembershipPlan plan;
  final VoidCallback onContinue;

  const PlanCard({super.key, required this.plan, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    final period = plan.periodLabel;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(
          color: plan.featured ? AppColors.accent : AppColors.border,
          width: plan.featured ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  plan.name,
                  style: AppTextStyles.heading2.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.sm),
              AppTag(plan.connectsLabel, highlight: true),
            ],
          ),
          if (plan.description.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.sm),
            Text(plan.description, style: AppTextStyles.bodyMedium),
          ],
          const SizedBox(height: AppDimensions.md),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  plan.priceLabel,
                  style: AppTextStyles.heading1.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (period.isNotEmpty) ...[
                  const SizedBox(width: AppDimensions.xs + 2),
                  Text(
                    period,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if ([
            plan.audienceLabel,
            plan.serviceFeeLabel,
          ].any((note) => note != null)) ...[
            const SizedBox(height: AppDimensions.sm),
            Text(
              [
                plan.audienceLabel,
                plan.serviceFeeLabel,
              ].whereType<String>().join(' · '),
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: AppDimensions.md),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: AppDimensions.md),
          for (final feature in plan.features)
            Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.sm + 2),
              child: Row(
                children: [
                  const Icon(
                    Icons.check,
                    size: AppDimensions.iconSm,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppDimensions.sm),
                  Expanded(
                    child: Text(
                      feature,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Keeps the button on the same baseline across cards of different
          // feature counts; collapses to nothing when heights already match.
          const Spacer(),
          AppButton(
            text: plan.actionLabel,
            isOutlined: !plan.featured,
            backgroundColor: AppColors.accent,
            textColor: plan.featured
                ? AppColors.primary
                : AppColors.textPrimary,
            borderRadius: AppDimensions.radiusXl,
            onPressed: onContinue,
          ),
        ],
      ),
    );
  }
}
