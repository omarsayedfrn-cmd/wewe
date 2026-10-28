import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores the platform account password locally on the device only.
///
/// The login code lives on the server (bound to the profile), while the
/// password never leaves the device. Keys are namespaced per app user so a
/// shared device does not leak credentials between accounts.
class SecureCredentials {
  SecureCredentials._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static String _key(String userId) => 'platform_password_$userId';

  /// Reads the cached password for a user, or null when unavailable.
  static Future<String?> readPassword(String userId) async {
    try {
      return await _storage.read(key: _key(userId));
    } catch (_) {
      return null;
    }
  }

  /// Caches the password for a user. Best-effort: a local failure must not
  /// block solving.
  static Future<void> savePassword(String userId, String password) async {
    try {
      await _storage.write(key: _key(userId), value: password);
    } catch (_) {}
  }

  /// Removes the cached password (e.g. on sign-out).
  static Future<void> clear(String userId) async {
    try {
      await _storage.delete(key: _key(userId));
    } catch (_) {}
  }
}
