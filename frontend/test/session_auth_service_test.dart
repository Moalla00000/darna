import 'package:flutter_test/flutter_test.dart';
import 'package:darna/services/session_auth_service.dart';

void main() {
  late SessionAuthService authService;

  setUp(() {
    authService = SessionAuthService();
    authService.resetSession();
    authService.setTestPin(null);
  });

  group('SessionAuthService In-Memory State', () {
    test('starts unauthenticated by default', () {
      expect(authService.isAuthenticated, isFalse);
    });

    test('markAuthenticated sets state to true', () {
      expect(authService.isAuthenticated, isFalse);
      authService.markAuthenticated();
      expect(authService.isAuthenticated, isTrue);
    });

    test('resetSession resets state to false', () {
      authService.markAuthenticated();
      expect(authService.isAuthenticated, isTrue);
      authService.resetSession();
      expect(authService.isAuthenticated, isFalse);
    });

    test('multiple markAuthenticated calls remain authenticated', () {
      authService.markAuthenticated();
      authService.markAuthenticated();
      expect(authService.isAuthenticated, isTrue);
    });
  });

  group('SessionAuthService PIN Validation & Fail-Safe Behavior', () {
    test('fails safely if PIN is not configured (null)', () {
      authService.setTestPin(null);
      expect(authService.isPinConfigured, isFalse);
      expect(authService.configuredPin, isNull);
      expect(authService.verifyPin('1234'), isFalse);
      expect(authService.verifyPin(''), isFalse);
    });

    test('fails safely if PIN is empty string', () {
      authService.setTestPin('');
      expect(authService.isPinConfigured, isFalse);
      expect(authService.configuredPin, isNull);
      expect(authService.verifyPin('1234'), isFalse);
    });

    test('fails safely if PIN has whitespace only', () {
      authService.setTestPin('   ');
      expect(authService.isPinConfigured, isFalse);
      expect(authService.configuredPin, isNull);
      expect(authService.verifyPin('1234'), isFalse);
    });

    test('fails safely if PIN contains non-digits', () {
      authService.setTestPin('12a4');
      expect(authService.isPinConfigured, isFalse);
      expect(authService.configuredPin, isNull);
      expect(authService.verifyPin('12a4'), isFalse);
    });

    test('fails safely if PIN is fewer than 4 digits', () {
      authService.setTestPin('123');
      expect(authService.isPinConfigured, isFalse);
      expect(authService.configuredPin, isNull);
      expect(authService.verifyPin('123'), isFalse);
    });

    test('fails safely if PIN is more than 4 digits', () {
      authService.setTestPin('12345');
      expect(authService.isPinConfigured, isFalse);
      expect(authService.configuredPin, isNull);
      expect(authService.verifyPin('12345'), isFalse);
    });

    test('validates correct 4-digit numeric PIN', () {
      authService.setTestPin('4829');
      expect(authService.isPinConfigured, isTrue);
      expect(authService.configuredPin, equals('4829'));

      // Correct PIN
      expect(authService.verifyPin('4829'), isTrue);

      // Incorrect PINs
      expect(authService.verifyPin('0000'), isFalse);
      expect(authService.verifyPin('4828'), isFalse);
      expect(authService.verifyPin('48290'), isFalse);
      expect(authService.verifyPin(''), isFalse);
    });
  });
}
