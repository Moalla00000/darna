import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  // Base URL of the ESP32 door controller on the local Wi-Fi network.
  // Override at runtime in .env: ESP32_BASE_URL=http://192.168.1.200
  static String get esp32BaseUrl {
    if (!dotenv.isInitialized) return 'http://192.168.1.200';
    return dotenv.env['ESP32_BASE_URL'] ?? 'http://192.168.1.200';
  }

  static const String openDoorEndpoint = '/api/v1/door/open';
  static const String devicesEndpoint = '/api/v1/devices';

  // Duration the physical servo takes to complete the full open/close sweep
  static const Duration doorOperationDuration = Duration(milliseconds: 5200);

  static const Color primaryColor = Color(0xFF2296F3);
}
