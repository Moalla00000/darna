import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Manages in-memory session authentication for Darna.
///
/// Authentication state is stored purely in runtime memory and is NEVER
/// persisted to disk, SharedPreferences, or secure storage. It automatically
/// resets whenever the application process terminates or restarts.
class SessionAuthService {
  static final SessionAuthService _instance = SessionAuthService._internal();
  factory SessionAuthService() => _instance;
  SessionAuthService._internal();

  bool _isAuthenticated = false;

  /// Whether the user has authenticated with the PIN during the current app session.
  bool get isAuthenticated => _isAuthenticated;

  /// Marks the current session as authenticated.
  void markAuthenticated() {
    _isAuthenticated = true;
  }

  /// Resets session authentication (used for testing or explicit lock).
  void resetSession() {
    _isAuthenticated = false;
  }

  // Testing hook: allow unit tests to mock or set the PIN directly without loading files.
  bool _hasTestPinOverride = false;
  String? _testPinOverride;

  void setTestPin(String? pin) {
    _hasTestPinOverride = true;
    _testPinOverride = pin;
  }

  void clearTestPinOverride() {
    _hasTestPinOverride = false;
    _testPinOverride = null;
  }

  /// Validates and returns the configured 4-digit PIN from .env.
  /// Returns null if missing, empty, or not strictly 4 numeric digits.
  String? get configuredPin {
    if (_hasTestPinOverride) {
      if (_testPinOverride == null) return null;
      final pin = _testPinOverride!.trim();
      return RegExp(r'^\d{4}$').hasMatch(pin) ? pin : null;
    }

    if (!dotenv.isInitialized) return null;

    final raw = dotenv.env['DOOR_PIN']?.trim();
    if (raw == null || raw.isEmpty) return null;
    if (RegExp(r'^\d{4}$').hasMatch(raw)) {
      return raw;
    }
    return null;
  }

  /// Whether a valid 4-digit numeric PIN is configured in the environment.
  bool get isPinConfigured => configuredPin != null;

  /// Verifies an entered PIN against the configured PIN.
  /// Fails safely (returns false) if the PIN is not properly configured.
  bool verifyPin(String enteredPin) {
    final validPin = configuredPin;
    if (validPin == null) return false;
    return validPin == enteredPin;
  }
}
