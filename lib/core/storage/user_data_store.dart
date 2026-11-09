import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A small JSON document per account, kept in the device keystore.
///
/// A sign-in shows the profile from this copy before `GET /api/profile` has
/// answered, and an account with no connection still sees its own data. Every
/// document is stored under the id of the account it belongs to, so another
/// account on the same phone can never read it, and nothing here is secret
/// material: no passwords, no tokens, no cookies.
class UserDataStore {
  UserDataStore._();

  static final UserDataStore instance = UserDataStore._();

  static const FlutterSecureStorage _keystore = FlutterSecureStorage();

  final Map<String, String> _memory = {};
  bool _inMemory = false;

  /// Keeps documents in RAM only. Widget tests run on a fake clock, which can
  /// never resolve a platform channel.
  void useInMemoryStorage() {
    _inMemory = true;
    _memory.clear();
  }

  Future<Map<String, dynamic>?> read(String collection, String userId) async {
    if (userId.isEmpty) return null;
    final raw = await _read(_key(collection, userId));
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> write(
    String collection,
    String userId,
    Map<String, dynamic> document,
  ) => _save(_key(collection, userId), jsonEncode(document));

  /// Drops one account's document, used when the account itself says the data
  /// is no longer wanted.
  Future<void> forget(String collection, String userId) =>
      _remove(_key(collection, userId));

  String _key(String collection, String userId) =>
      'userdata.$collection.$userId';

  Future<String?> _read(String key) async {
    if (_inMemory) return _memory[key];
    try {
      return await _keystore.read(key: key);
    } catch (_) {
      // No keystore on this platform: the app simply keeps working from memory.
      return null;
    }
  }

  Future<void> _save(String key, String value) async {
    if (_inMemory) {
      _memory[key] = value;
      return;
    }
    try {
      await _keystore.write(key: key, value: value);
    } catch (_) {
      // A write that cannot reach the keystore is not worth failing a save for.
    }
  }

  Future<void> _remove(String key) async {
    _memory.remove(key);
    if (_inMemory) return;
    try {
      await _keystore.delete(key: key);
    } catch (_) {
      // Nothing stored, nothing to delete.
    }
  }
}
