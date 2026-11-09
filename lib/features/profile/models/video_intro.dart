/// The video intro route stores one address and offers no way to read it back,
/// so everything the app shows for a poster has to come from the link itself.
library;

/// A still for [link], or null when the address is not a YouTube or Vimeo page.
///
/// Mirrors the web card, which builds the picture from the video id on a
/// public thumbnail host. A direct file link like `…/intro.mp4` has no id to
/// hang a poster on, so it stays null and the card keeps showing the address —
/// the link opens either way.
String? videoPosterUrl(String link) {
  final uri = Uri.tryParse(link.trim());
  if (uri == null) return null;
  final host = uri.host.toLowerCase().replaceFirst('www.', '');
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.isEmpty) return null;

  if (host == 'youtu.be') {
    return _youtube(segments.first);
  }
  if (host == 'youtube.com' ||
      host == 'm.youtube.com' ||
      host == 'music.youtube.com') {
    switch (segments.first) {
      case 'watch':
        return _youtube(uri.queryParameters['v'] ?? '');
      case 'embed':
      case 'shorts':
      case 'live':
      case 'v':
        return _youtube(segments.length > 1 ? segments[1] : '');
    }
    return null;
  }
  if (host == 'vimeo.com' || host == 'player.vimeo.com') {
    final id = segments.last.replaceAll(RegExp(r'[^0-9]'), '');
    if (RegExp(r'^\d+$').hasMatch(id)) {
      return 'https://vumbnail.com/$id.jpg';
    }
  }
  return null;
}

String? _youtube(String id) {
  if (!RegExp(r'^[\w-]{6,}$').hasMatch(id)) return null;
  return 'https://img.youtube.com/vi/$id/hqdefault.jpg';
}
