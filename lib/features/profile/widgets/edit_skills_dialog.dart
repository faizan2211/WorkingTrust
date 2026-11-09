import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../controller/profile_controller.dart';

/// Opens the "Edit Skills" dialog from the mock. The list is only written back
/// to [ProfileController] when the user saves.
Future<void> showEditSkillsDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => const _EditSkillsDialog(),
  );
}

class _EditSkillsDialog extends StatefulWidget {
  const _EditSkillsDialog();

  @override
  State<_EditSkillsDialog> createState() => _EditSkillsDialogState();
}

class _EditSkillsDialogState extends State<_EditSkillsDialog> {
  final _search = TextEditingController();
  late final List<String> _skills = [...ProfileController.instance.skills];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _add() {
    final skill = _search.text.trim();
    if (skill.isEmpty) return;
    if (!_skills.contains(skill)) setState(() => _skills.add(skill));
    _search.clear();
  }

  Future<void> _save() async {
    _add();
    final profile = ProfileController.instance;
    final skills = [..._skills];
    final messenger = ScaffoldMessenger.of(context);
    // The list is the app's own state, so it is kept even when the signed-in
    // account cannot be reached.
    await profile.saveSkills(skills);
    if (!mounted) return;
    if (profile.errorMessage.isNotEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(profile.errorMessage),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(AppDimensions.md),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Edit Skills', style: AppTextStyles.heading4),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close,
                      size: AppDimensions.iconSm + 2,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.sm),
              Text(
                'Your Skills',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppDimensions.sm),
              Flexible(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.accent),
                    borderRadius: BorderRadius.circular(AppDimensions.radius),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppDimensions.sm),
                    child: Wrap(
                      spacing: AppDimensions.sm,
                      runSpacing: AppDimensions.sm,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (final skill in _skills)
                          _SkillChip(
                            skill: skill,
                            onRemove: () =>
                                setState(() => _skills.remove(skill)),
                          ),
                        SizedBox(
                          width: 150,
                          child: TextField(
                            controller: _search,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _add(),
                            style: AppTextStyles.bodyMedium,
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'Search Skills',
                              hintStyle: const TextStyle(
                                color: AppColors.textHint,
                                fontSize: 14,
                              ),
                              filled: false,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 8,
                              ),
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: AppDimensions.sm),
                  AppButton(
                    text: 'Save changes',
                    width: 148,
                    backgroundColor: AppColors.accent,
                    textColor: AppColors.primary,
                    borderRadius: AppDimensions.radiusXl,
                    onPressed: _save,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkillChip extends StatelessWidget {
  final String skill;
  final VoidCallback onRemove;

  const _SkillChip({required this.skill, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(
        left: AppDimensions.md,
        right: AppDimensions.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              skill,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Remove $skill',
            onPressed: onRemove,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.only(left: AppDimensions.xs),
            icon: const Icon(
              Icons.close,
              size: AppDimensions.iconSm,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
