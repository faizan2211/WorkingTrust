/// The four states one read-only screen can be in.
///
/// A screen shows a spinner for [loading], its list for [ready], its empty state
/// for [empty] — which means the read succeeded and the account has nothing —
/// and the error card with a retry button for [failed]. [idle] is only the
/// instant before the first read starts.
enum ReadState { idle, loading, ready, empty, failed }

/// Whether the answer came back because the cookie is gone.
///
/// The controllers keep this apart from an ordinary failure so a screen can
/// offer to sign in again instead of a retry that would 401 the same way.
class SessionExpiry {
  SessionExpiry._();

  /// What the four read routes answer with no session, and the wording every
  /// screen uses for it.
  static const String message =
      'Your session has expired. Please log in again.';

  static bool isExpired(int? statusCode) => statusCode == 401;
}
