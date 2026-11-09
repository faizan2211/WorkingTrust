import 'dart:typed_data';

import '../../../core/utils/file_selection_service.dart';

/// A file the freelancer picked for a proposal. [bytes] is what the upload
/// route needs, and [mimeType] is the one the media route accepts for that
/// extension — it refuses anything outside its allow-list.
class ProposalAttachment {
  const ProposalAttachment({
    required this.name,
    required this.bytes,
    required this.mimeType,
  });

  final String name;
  final Uint8List bytes;
  final String mimeType;

  int get size => bytes.length;

  String get sizeLabel => size >= 1048576
      ? '${(size / 1048576).toStringAsFixed(1)} MB'
      : '${(size / 1024).ceil()} KB';
}

/// Picks images and documents that the proposal upload endpoint accepts.
class ProposalAttachmentService {
  ProposalAttachmentService._();

  static final ProposalAttachmentService instance =
      ProposalAttachmentService._();

  static const int maxFileBytes = 10 * 1024 * 1024;
  static const List<String> allowedExtensions = [
    'jpg',
    'jpeg',
    'png',
    'webp',
    'pdf',
    'doc',
    'docx',
  ];

  /// Returns at most [slots] files, empty when the user backs out.
  Future<List<ProposalAttachment>> pick({required int slots}) async {
    final files = await FileSelectionService.pick(
      extensions: allowedExtensions,
      allowMultiple: true,
    );
    if (files.length > slots) {
      throw FormatException('Choose no more than $slots files at a time.');
    }
    for (final file in files) {
      if (file.bytes.length > maxFileBytes) {
        throw FormatException('${file.name} exceeds the 10 MB limit.');
      }
    }
    return [
      for (final file in files)
        ProposalAttachment(
          name: file.name,
          bytes: file.bytes,
          mimeType: file.mimeType,
        ),
    ];
  }
}
