import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';

/// The dialog's own title, buttons and padding, which the field list has to fit
/// alongside.
const double _chrome = 216;

enum ProfileFormResult { save, remove, cancel }

/// A themed dialog holding [fields] inside a Form. Returns the action taken,
/// or [ProfileFormResult.cancel] when the user backs out.
Future<ProfileFormResult> showProfileFormDialog(
  BuildContext context, {
  required String title,
  required List<Widget> fields,
  bool removable = false,
  String saveLabel = 'Save',
}) async {
  final form = GlobalKey<FormState>();
  final result = await showDialog<ProfileFormResult>(
    context: context,
    builder: (dialogContext) {
      // A short screen, or a screen the keyboard has already taken part of,
      // cannot hold every field, so the list scrolls instead of running past the
      // bottom edge of the dialog.
      final visible =
          MediaQuery.sizeOf(dialogContext).height -
          MediaQuery.viewInsetsOf(dialogContext).bottom;
      return AlertDialog(
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.md,
          vertical: AppDimensions.lg,
        ),
        title: Text(title, style: AppTextStyles.heading4),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: (visible - _chrome).clamp(120.0, 560.0),
          ),
          child: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: fields,
              ),
            ),
          ),
        ),
        actions: [
          if (removable)
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              onPressed: () =>
                  Navigator.pop(dialogContext, ProfileFormResult.remove),
              child: const Text('Remove'),
            ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, ProfileFormResult.cancel),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (!(form.currentState?.validate() ?? false)) return;
              Navigator.pop(dialogContext, ProfileFormResult.save);
            },
            child: Text(saveLabel),
          ),
        ],
      );
    },
  );
  return result ?? ProfileFormResult.cancel;
}

/// Validator shared by the profile section forms.
String? requiredField(String? value) =>
    (value ?? '').trim().isEmpty ? 'This field is required' : null;
