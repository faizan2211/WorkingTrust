import 'package:url_launcher/url_launcher.dart';

import 'validators.dart';

/// Hands an address to whatever app on the device handles it — the YouTube or
/// Vimeo client, a browser, or the system player for a direct video file.
///
/// The link is launched exactly as it was stored: nothing is rewritten into a
/// YouTube address, and the app never tries to play the video itself.
class LinkOpener {
  LinkOpener._();

  /// Replaced in tests, since the real call leaves the process.
  static Future<bool> Function(Uri uri) launch = _external;

  /// Answers null once the address has been handed over, and the message to
  /// show the user when it has not.
  static Future<String?> open(String url) async {
    final link = url.trim();
    if (!Validators.isWebAddress(link)) {
      return 'That link is not a web address.';
    }
    try {
      return await launch(Uri.parse(link))
          ? null
          : 'No app on this device can open that link.';
    } catch (_) {
      return 'The link could not be opened.';
    }
  }

  static Future<bool> _external(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);
}
