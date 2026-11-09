import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

typedef SelectedFile = ({String name, Uint8List bytes, String mimeType});

class FileSelectionService {
  FileSelectionService._();

  static Future<List<SelectedFile>> pick({
    required List<String> extensions,
    bool allowMultiple = false,
  }) async {
    final List<PlatformFile> files;
    if (allowMultiple) {
      files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: extensions,
      );
    } else {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: extensions,
      );
      files = file == null ? const [] : [file];
    }
    return [
      for (final file in files)
        (
          name: file.name,
          bytes: await file.readAsBytes(),
          mimeType: mimeTypeFor(file.name),
        ),
    ];
  }

  static String mimeTypeFor(String filename) => switch (filename
      .split('.')
      .last
      .toLowerCase()) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'pdf' => 'application/pdf',
    'doc' => 'application/msword',
    'docx' =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    _ => 'application/octet-stream',
  };
}
