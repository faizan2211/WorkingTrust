import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../controller/profile_controller.dart';
import '../services/profile_photo_service.dart';

enum _PhotoChoice { gallery, camera, remove }

/// Opens the profile photo picker sheet and uploads the result to the signed-in
/// account, so every avatar in the app shows the stored photo.
Future<void> showProfilePhotoSheet(BuildContext context) async {
  final profile = ProfileController.instance;
  final hasPhoto = profile.avatarBytes != null || profile.avatarUrl != null;
  final messenger = ScaffoldMessenger.of(context);
  final choice = await showModalBottomSheet<_PhotoChoice>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppDimensions.radiusLg),
      ),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimensions.md),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Profile photo', style: AppTextStyles.heading4),
            ),
          ),
          ListTile(
            leading: const Icon(
              Icons.photo_library_outlined,
              color: AppColors.primary,
            ),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(sheetContext, _PhotoChoice.gallery),
          ),
          ListTile(
            leading: const Icon(
              Icons.photo_camera_outlined,
              color: AppColors.primary,
            ),
            title: const Text('Take a photo'),
            onTap: () => Navigator.pop(sheetContext, _PhotoChoice.camera),
          ),
          if (hasPhoto)
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: const Text('Remove photo'),
              onTap: () => Navigator.pop(sheetContext, _PhotoChoice.remove),
            ),
          const SizedBox(height: AppDimensions.sm),
        ],
      ),
    ),
  );

  switch (choice) {
    case _PhotoChoice.gallery:
      _pick(ImageSource.gallery, messenger);
    case _PhotoChoice.camera:
      _pick(ImageSource.camera, messenger);
    case _PhotoChoice.remove:
      _remove(profile, messenger);
    case null:
      break;
  }
}

/// Uploads through `POST /api/profile/avatar`. A photo the backend did not
/// accept is not shown as if it were saved.
Future<void> _pick(ImageSource source, ScaffoldMessengerState messenger) async {
  final profile = ProfileController.instance;
  try {
    final picked = await ProfilePhotoService.instance.pickAvatar(source);
    if (picked == null) return;
    final uploaded = await profile.uploadAvatar(
      picked.bytes,
      filename: picked.filename,
      mimeType: picked.mimeType,
    );
    _note(
      messenger,
      uploaded
          ? 'Profile photo updated.'
          : profile.errorMessage.isEmpty
          ? 'The photo could not be uploaded.'
          : profile.errorMessage,
    );
  } catch (_) {
    _note(messenger, 'This device could not open the photo picker.');
  }
}

Future<void> _remove(
  ProfileController profile,
  ScaffoldMessengerState messenger,
) async {
  final removed = await profile.removeAvatar();
  _note(
    messenger,
    removed
        ? 'Profile photo removed.'
        : profile.errorMessage.isEmpty
        ? 'The photo could not be removed.'
        : profile.errorMessage,
  );
}

void _note(ScaffoldMessengerState messenger, String message) {
  messenger.showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}
