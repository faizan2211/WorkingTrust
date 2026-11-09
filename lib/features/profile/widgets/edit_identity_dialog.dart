import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../controller/profile_controller.dart';

/// Opens the "Edit Title, Hourly Rate & Description" dialog, writes the result
/// to the shared [ProfileController] and, for a signed-in account, to the
/// backend through `PATCH /api/profile`.
Future<void> showEditIdentityDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => const _EditIdentityDialog(),
  );
}

class _EditIdentityDialog extends StatefulWidget {
  const _EditIdentityDialog();

  @override
  State<_EditIdentityDialog> createState() => _EditIdentityDialogState();
}

class _EditIdentityDialogState extends State<_EditIdentityDialog> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _rate = TextEditingController();
  final _overview = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = ProfileController.instance;
    _title.text = profile.title;
    _rate.text = profile.hourlyRate;
    _overview.text = profile.bio;
  }

  @override
  void dispose() {
    _title.dispose();
    _rate.dispose();
    _overview.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !(_form.currentState?.validate() ?? false)) return;
    final profile = ProfileController.instance;
    final close = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    final saved = await profile.saveIdentity(
      title: _title.text.trim(),
      hourlyRate: _rate.text.trim(),
      bio: _overview.text.trim(),
    );
    if (!mounted) return;
    if (!saved) {
      // The typed text stays on screen so it can be corrected and retried:
      // nothing was stored.
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(profile.errorMessage),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    close.pop();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Profile saved.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 560;
    // The keyboard takes most of a short screen, and a six-line overview on top
    // of the two fields does not fit in what is left, so the form scrolls.
    final visible =
        MediaQuery.sizeOf(context).height -
        MediaQuery.viewInsetsOf(context).bottom;
    final heading = Row(
      children: [
        Expanded(
          child: Text(
            'Edit Title, Hourly Rate & Description',
            style: AppTextStyles.heading4,
          ),
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
    );
    final pair = [
      AppTextField(
        label: 'Your Title',
        hint: 'Ex. Senior Web Developer...',
        controller: _title,
        validator: (value) =>
            (value ?? '').trim().isEmpty ? 'This field is required' : null,
      ),
      AppTextField(
        label: 'Hourly Rate',
        hint: '\$50.00 /hr',
        controller: _rate,
        validator: (value) =>
            (value ?? '').trim().isEmpty ? 'This field is required' : null,
      ),
    ];
    return Dialog(
      insetPadding: const EdgeInsets.all(AppDimensions.md),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 680,
          maxHeight: (visible - 2 * AppDimensions.md).clamp(120.0, 640.0),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.lg),
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                heading,
                const SizedBox(height: AppDimensions.md),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: pair.first),
                      const SizedBox(width: AppDimensions.md),
                      Expanded(child: pair.last),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      pair.first,
                      const SizedBox(height: AppDimensions.md),
                      pair.last,
                    ],
                  ),
                const SizedBox(height: AppDimensions.md),
                AppTextField(
                  label: 'Overview',
                  hint:
                      'Ex. Clean, developer-ready UI/UX for SaaS products, web '
                      'apps, and mobile apps designed to be understood in one '
                      'look, not explained in three meetings...',
                  controller: _overview,
                  maxLines: 6,
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'This field is required'
                      : null,
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
                      text: _saving ? 'Saving…' : 'Save changes',
                      width: 148,
                      backgroundColor: AppColors.accent,
                      textColor: AppColors.primary,
                      borderRadius: AppDimensions.radiusXl,
                      onPressed: _saving ? null : _save,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
