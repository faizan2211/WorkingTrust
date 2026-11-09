import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the cookie jar keeps its copy between app launches.
abstract class SessionCookieStorage {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

/// The device keystore (Keychain / Keystore) behind the Dart API.
class _SecureCookieStorage implements SessionCookieStorage {
  const _SecureCookieStorage();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Widget tests cannot await a platform channel: `testWidgets` runs on a fake
/// clock, so a real plugin response never arrives.
class _MemoryCookieStorage implements SessionCookieStorage {
  String? _value;

  @override
  Future<String?> read(String key) async => _value;

  @override
  Future<void> write(String key, String value) async => _value = value;

  @override
  Future<void> delete(String key) async => _value = null;
}

/// The cookies the backend set for us, kept between app launches.
///
/// `package:http` is not a browser: it neither stores nor replays cookies, and
/// the Next.js backend recognises a signed-in device only through the NextAuth
/// session cookie. This jar is therefore the mobile equivalent of browser
/// cookie storage, scoped to the single configured backend origin.
///
/// Only cookie name/value pairs are kept — no passwords, no server secrets.
class SessionStore {
  SessionStore._();

  static final SessionStore instance = SessionStore._();

  static const String _storageKey = 'session.cookies.v1';

  final Map<String, String> _cookies = {};
  SessionCookieStorage _storage = const _SecureCookieStorage();
  bool _loaded = false;

  /// Keeps the jar in RAM only. Tests use this to stay deterministic.
  void useInMemoryStorage() => _storage = _MemoryCookieStorage();

  /// Single `Cookie` request header value, or null while signed out.
  String? get cookieHeader => _cookies.isEmpty
      ? null
      : _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');

  String? value(String name) => _cookies[name];

  /// Whether a NextAuth session cookie is present. Never proves the session is
  /// still valid server-side — only `GET /api/auth/session` does that. The
  /// backend chunks a long cookie as `…session-token.0`, so match any name.
  bool get hasSessionCookie =>
      _cookies.keys.any((name) => name.contains('session-token'));

  /// Loads cookies saved by an earlier run. Idempotent.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final stored = await _storage.read(_storageKey);
      if (stored == null) return;
      final decoded = jsonDecode(stored);
      if (decoded is! Map) return;
      _cookies.addAll(decoded.map((k, v) => MapEntry('$k', '$v')));
    } catch (_) {
      // Missing plugin (tests) or unreadable data simply means signed out.
    }
  }

  /// Stores every `Set-Cookie` value from a response, dropping expired ones.
  ///
  /// [setCookies] must already be one entry per cookie; the raw `headers` map
  /// joins several Set-Cookie values with commas, which would corrupt them.
  void absorb(List<String> setCookies) {
    if (setCookies.isEmpty) return;
    for (final raw in setCookies) {
      final io.Cookie cookie;
      try {
        cookie = io.Cookie.fromSetCookieValue(raw);
      } on FormatException {
        continue;
      }
      if (cookie.name.isEmpty) continue;
      final expired =
          (cookie.maxAge != null && cookie.maxAge! <= 0) ||
          (cookie.expires != null && cookie.expires!.isBefore(DateTime.now()));
      if (expired) {
        _cookies.remove(cookie.name);
      } else {
        _cookies[cookie.name] = cookie.value;
      }
    }
    unawaited(_persist());
  }

  /// Signs out locally: NextAuth uses stateless JWTs, so there is nothing to
  /// revoke server-side once the device drops its cookies.
  Future<void> clear() async {
    _cookies.clear();
    _loaded = true;
    try {
      await _storage.delete(_storageKey);
    } catch (_) {
      // Nothing persisted, nothing to delete.
    }
  }

  Future<void> _persist() async {
    try {
      await _storage.write(_storageKey, jsonEncode(_cookies));
    } catch (_) {
      // In-memory only when secure storage is unavailable.
    }
  }
}
