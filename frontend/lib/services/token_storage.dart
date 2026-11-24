import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Secure, encrypted storage for *this phone's own* device token.
// Real tokens never appear in Dart source code.
class TokenStorage {
  static const _deviceTokenKey = 'device_token';
  static const _deviceNameKey = 'device_name';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<String?> getDeviceToken() async {
    try {
      return await _storage.read(key: _deviceTokenKey);
    } catch (_) {
      // Treat a storage failure like a missing token so the app routes to setup.
      return null;
    }
  }

  Future<bool> saveDevice({required String token, required String name}) async {
    try {
      await _storage.write(key: _deviceTokenKey, value: token);
      await _storage.write(key: _deviceNameKey, value: name);
      return true;
    } catch (_) {
      return false;
    }
  }
}
