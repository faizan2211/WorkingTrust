import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_tag.dart';
import '../models/project_model.dart';

/// One project on the board: what it is, who posted it, what it pays, and
/// whether this device has already saved or applied to it.
class ProjectCard extends StatelessWidget {
  final ProjectModel project;
  final VoidCallback? onTap;
  final VoidCallback? onSave;

  const ProjectCard({
    super.key,
    required this.project,
    this.onTap,
    this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimensions.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: AppDimensions.sm,
                        runSpacing: AppDimensions.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          AppTag(project.postedIn, highlight: true),
                          AppTag(project.level),
                          Text(
                            'Proposals: ${project.proposals}',
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppDimensions.sm),
                    IconButton(
                      onPressed: onSave,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        project.saved
                            ? Icons.bookmark_added
                            : Icons.bookmark_add_outlined,
                        size: 20,
                        color: project.saved
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.md),
                Text(
                  project.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: AppDimensions.xs + 2),
                Text(
                  project.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.copyWith(height: 1.6),
                ),
                const SizedBox(height: AppDimensions.md),
                Wrap(
                  spacing: AppDimensions.sm,
                  runSpacing: AppDimensions.sm,
                  children: [
                    for (final skill in project.skills) AppTag(skill),
                    AppTag(project.duration, icon: Icons.schedule_outlined),
                  ],
                ),
                const SizedBox(height: AppDimensions.lg),
                // Budget carries the card, so it gets the accent block rather
                // than a footnote at the bottom.
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.md,
                        vertical: AppDimensions.sm,
                      ),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radius,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.attach_money,
                            size: AppDimensions.iconSm,
                            color: AppColors.textOnPrimary,
                          ),
                          const SizedBox(width: AppDimensions.xs),
                          Flexible(
                            child: Text(
                              project.price,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.labelLarge.copyWith(
                                color: AppColors.textOnPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppDimensions.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              for (int star = 0; star < 5; star++)
                                Icon(
                                  star < project.clientRating
                                      ? Icons.star_rounded
                                      : Icons.star_outline_rounded,
                                  size: 14,
                                  color: const Color(0xFFFFB800),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            project.spentLabel == null
                                ? 'No client spend recorded'
                                : '${project.spentLabel} spent',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.md,
              vertical: AppDimensions.sm + 2,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(AppDimensions.radiusLg),
              ),
            ),
            child: Row(
              children: [
                AppAvatar(
                  name: project.clientName,
                  imageUrl: project.clientAvatar,
                  radius: 14,
                ),
                const SizedBox(width: AppDimensions.sm),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          project.clientName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.labelMedium,
                        ),
                      ),
                      if (project.paymentVerified) ...[
                        const SizedBox(width: AppDimensions.xs),
                        const Icon(
                          Icons.verified,
                          size: 14,
                          color: AppColors.success,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppDimensions.sm),
                // Both the name and the country are free text on the client's
                // own profile, so each gets the remaining width and wraps
                // there rather than pushing past the card.
                Flexible(
                  child: Text(
                    project.clientLocation,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: AppTextStyles.caption,
                  ),
                ),
                if (project.applied) ...[
                  const SizedBox(width: AppDimensions.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusXl,
                      ),
                    ),
                    child: const Text(
                      'Applied',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
