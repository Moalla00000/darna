import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:darna/core/constants.dart';

class Esp32Service {
  final http.Client _client = http.Client();

  Future<(bool, String)> openDoor({required String token}) async {
    final uri = Uri.parse(
      '${AppConstants.esp32BaseUrl}${AppConstants.openDoorEndpoint}',
    );
    try {
      final response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        return (true, 'Door opened successfully');
      }
      try {
        final data = jsonDecode(response.body);
        if (data is Map && data['message'] != null) {
          return (false, data['message'] as String);
        }
      } catch (_) {}
      return (
        false,
        'Door controller returned an error (${response.statusCode}).',
      );
    } on SocketException {
      return (
        false,
        "Couldn't connect to your home device. Make sure you're on your home Wi-Fi.",
      );
    } on http.ClientException {
      return (false, 'Connection error. Please try again.');
    } on TimeoutException {
      return (false, 'Connection timed out. Please try again.');
    } catch (_) {
      return (false, 'Something went wrong. Please try again.');
    }
  }

  Future<(bool, List<Map<String, dynamic>>, String)> listDevices({
    required String token,
  }) async {
    final uri = Uri.parse(
      '${AppConstants.esp32BaseUrl}${AppConstants.devicesEndpoint}',
    );
    try {
      final response = await _client
          .get(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final devices =
            (data['devices'] as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            <Map<String, dynamic>>[];
        return (true, devices, '');
      }
      try {
        final data = jsonDecode(response.body);
        if (data is Map && data['message'] != null) {
          return (false, <Map<String, dynamic>>[], data['message'] as String);
        }
      } catch (_) {}
      return (false, <Map<String, dynamic>>[], 'Failed to load devices.');
    } on SocketException {
      return (
        false,
        <Map<String, dynamic>>[],
        "Couldn't connect to your home device.",
      );
    } on TimeoutException {
      return (
        false,
        <Map<String, dynamic>>[],
        'Connection timed out. Check connection to Darna.',
      );
    } catch (_) {
      return (false, <Map<String, dynamic>>[], 'Something went wrong.');
    }
  }

  Future<(bool, String)> registerDevice({
    required String token,
    required String name,
    required String newToken,
  }) async {
    final uri = Uri.parse(
      '${AppConstants.esp32BaseUrl}${AppConstants.devicesEndpoint}/register',
    );
    try {
      final response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'name': name, 'token': newToken}),
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        return (true, 'Device registered successfully');
      }
      try {
        final data = jsonDecode(response.body);
        if (data is Map && data['message'] != null) {
          return (false, data['message'] as String);
        }
      } catch (_) {}
      return (
        false,
        'Registration rejected by the door controller (${response.statusCode}).',
      );
    } on SocketException {
      return (
        false,
        "Couldn't connect to Darna. Make sure you're on your home Wi-Fi.",
      );
    } on TimeoutException {
      return (false, 'Connection timed out. Check connection to Darna.');
    } catch (_) {
      return (false, 'Something went wrong while registering device.');
    }
  }

  Future<(bool, String)> revokeDevice({
    required String token,
    int? deviceId,
    String? targetToken,
  }) async {
    final uri = Uri.parse(
      '${AppConstants.esp32BaseUrl}${AppConstants.devicesEndpoint}/revoke',
    );
    try {
      final bodyMap = <String, dynamic>{};
      if (deviceId != null) {
        bodyMap['id'] = deviceId;
      }
      if (targetToken != null && targetToken.isNotEmpty) {
        bodyMap['token'] = targetToken;
      }
      final response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(bodyMap),
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        return (true, 'Device revoked successfully');
      }
      try {
        final data = jsonDecode(response.body);
        if (data is Map && data['message'] != null) {
          return (false, data['message'] as String);
        }
      } catch (_) {}
      return (
        false,
        'Revocation rejected by the door controller (${response.statusCode}).',
      );
    } on SocketException {
      return (
        false,
        "Couldn't connect to Darna. Make sure you're on your home Wi-Fi.",
      );
    } on TimeoutException {
      return (false, 'Connection timed out. Check connection to Darna.');
    } catch (_) {
      return (false, 'Something went wrong while revoking device.');
    }
  }

  // Verify an existing authorized bearer token with the ESP32.
  Future<
    (bool, String /* deviceName */, bool /* isAdmin */, String /* message */)
  >
  verifyAuthToken({required String token}) async {
    final uri = Uri.parse('${AppConstants.esp32BaseUrl}/api/v1/auth/verify');
    try {
      final response = await _client
          .get(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final deviceName = data['deviceName'] as String? ?? 'Authorized Device';
        final isAdmin = data['isAdmin'] as bool? ?? false;
        return (true, deviceName, isAdmin, 'Token verified');
      }
      try {
        final data = jsonDecode(response.body);
        if (data is Map && data['message'] != null) {
          return (false, '', false, data['message'] as String);
        }
      } catch (_) {}
      return (false, '', false, 'Invalid or unauthorized device token.');
    } on SocketException {
      return (
        false,
        '',
        false,
        "Couldn't connect to Darna. Make sure you're on your home Wi-Fi.",
      );
    } on TimeoutException {
      return (
        false,
        '',
        false,
        'Connection timed out. Check connection to Darna.',
      );
    } catch (_) {
      return (false, '', false, 'Something went wrong verifying token.');
    }
  }

  // One-time initial setup: register the first (admin) device using a setup
  // token obtained from the ESP32 Serial Monitor. No bearer auth required.
  Future<(bool, String /* deviceToken */, String)> setupRegister({
    required String setupToken,
    required String deviceName,
  }) async {
    final uri = Uri.parse('${AppConstants.esp32BaseUrl}/api/v1/setup/register');
    try {
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'setupToken': setupToken,
              'deviceName': deviceName,
            }),
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final deviceToken = data['deviceToken'] as String? ?? '';
        return (true, deviceToken, 'Setup complete.');
      }
      return (false, '', 'Setup rejected by the door controller.');
    } on SocketException {
      return (false, '', "Couldn't connect to your home device.");
    } on TimeoutException {
      return (false, '', 'Connection timed out. Check connection to Darna.');
    } catch (_) {
      return (false, '', 'Something went wrong.');
    }
  }
}
