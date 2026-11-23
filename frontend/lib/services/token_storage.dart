import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Secure, encrypted storage for *this phone's own* device token.
// Real tokens never appear in Dart source code.
class TokenStorage {
  static const _deviceTokenKey = 'device_token';
  static const _deviceNameKey = 'device_name';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<String?> getDeviceToken() async => _storage.read(key: _deviceTokenKey);

  Future<String?> getDeviceName() async => _storage.read(key: _deviceNameKey);

  Future<void> saveDevice({
    required String token,
    required String name,
  }) async {
    await _storage.write(key: _deviceTokenKey, value: token);
    await _storage.write(key: _deviceNameKey, value: name);
  }

  Future<void> clearDevice() async {
    await _storage.delete(key: _deviceTokenKey);
    await _storage.delete(key: _deviceNameKey);
  }
}
