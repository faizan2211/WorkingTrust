import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// Wraps the device media picker so the screens only deal with bytes and
/// files, never with platform channels.
class ProfilePhotoService {
  ProfilePhotoService._();

  static final ProfilePhotoService instance = ProfilePhotoService._();

  final ImagePicker _picker = ImagePicker();

  /// An avatar plus what the upload route needs: the part's file name and its
  /// MIME type, which the backend checks against JPG, PNG and WEBP.
  Future<({Uint8List bytes, String filename, String mimeType})?> pickAvatar(
    ImageSource source,
  ) async {
    final file = await _pickFile(source);
    if (file == null) return null;
    return _upload(file);
  }

  /// A portfolio image, kept at full size: the media route takes up to 60MB and
  /// checks the MIME type against its own allow-list, so nothing is downscaled.
  Future<({Uint8List bytes, String filename, String mimeType})?> pickFile(
    ImageSource source,
  ) async {
    final file = await _picker.pickImage(source: source);
    if (file == null) return null;
    return _upload(file);
  }

  Future<({Uint8List bytes, String filename, String mimeType})> _upload(
    XFile file,
  ) async => (
    bytes: await file.readAsBytes(),
    filename: file.name,
    mimeType: file.mimeType ?? 'image/jpeg',
  );

  Future<XFile?> _pickFile(ImageSource source) => _picker.pickImage(
    source: source,
    maxWidth: 720,
    maxHeight: 720,
    imageQuality: 85,
  );

  /// Picks a video from the gallery. Nothing decodes the frames — the app has
  /// no video plugin — so callers show the file itself.
  Future<XFile?> pickVideo() => _picker.pickVideo(source: ImageSource.gallery);
}
