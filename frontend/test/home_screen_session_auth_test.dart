import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:darna/core/theme.dart';
import 'package:darna/features/home/home_screen.dart';
import 'package:darna/services/session_auth_service.dart';
import 'package:darna/services/token_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionAuthService sessionAuth;
  late TokenStorage tokenStorage;

  setUp(() async {
    dotenv.loadFromString(envString: 'ESP32_BASE_URL=http://127.0.0.1:80\nDOOR_PIN=4829\n');
    FlutterSecureStorage.setMockInitialValues({'device_token': 'dummy_test_token_12345'});
    SharedPreferences.setMockInitialValues({});
    sessionAuth = SessionAuthService();
    sessionAuth.resetSession();
    sessionAuth.setTestPin('4829');
    tokenStorage = TokenStorage();
    await tokenStorage.saveDevice(token: 'dummy_test_token_12345', name: 'Test Phone');
  });

  Widget buildHomeScreen() {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: const HomeScreen(),
    );
  }

  testWidgets('Scenario A: First tap on Open Door presents PIN dialog',
      (WidgetTester tester) async {
    expect(sessionAuth.isAuthenticated, isFalse);

    await tester.pumpWidget(buildHomeScreen());
    await tester.pumpAndSettle();

    // Verify on HomeScreen
    expect(find.text('Front Door'), findsOneWidget);
    expect(find.text('Open Door'), findsOneWidget);

    // Tap Open Door
    await tester.tap(find.text('Open Door'));
    await tester.pumpAndSettle();

    // Verify PIN dialog is now shown
    expect(find.text('Enter your PIN'), findsOneWidget);
    expect(sessionAuth.isAuthenticated, isFalse);
  });

  testWidgets('Canceling PIN dialog does not authenticate session',
      (WidgetTester tester) async {
    await tester.pumpWidget(buildHomeScreen());
    await tester.pumpAndSettle();

    // Tap Open Door
    await tester.tap(find.text('Open Door'));
    await tester.pumpAndSettle();

    // Tap Cancel
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    // Dialog dismissed, session remains unauthenticated
    expect(find.text('Enter your PIN'), findsNothing);
    expect(sessionAuth.isAuthenticated, isFalse);
  });

  testWidgets(
      'Entering correct PIN authenticates session and subsequent taps skip PIN dialog',
      (WidgetTester tester) async {
    await tester.pumpWidget(buildHomeScreen());
    await tester.pumpAndSettle();

    // 1. First attempt: tap Open Door
    await tester.tap(find.text('Open Door'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your PIN'), findsOneWidget);

    // Enter correct PIN: 4829
    await tester.tap(find.text('4'));
    await tester.pump();
    await tester.tap(find.text('8'));
    await tester.pump();
    await tester.tap(find.text('2'));
    await tester.pump();
    await tester.tap(find.text('9'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Dialog closed and session is now authenticated!
    expect(find.text('Enter your PIN'), findsNothing);
    expect(sessionAuth.isAuthenticated, isTrue);

    // Advance time to let network call (SocketException) complete and error timer clear
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 4));

    // 2. Scenario B & C: Subsequent tap on Open Door in the same session
    await tester.tap(find.text('Open Door'));
    await tester.pump();

    // Should NOT show the PIN dialog again!
    expect(find.text('Enter your PIN'), findsNothing);
    expect(sessionAuth.isAuthenticated, isTrue);

    // Advance time to let second call finish
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 4));

    // 3. Scenario D: Application restart (resetSession)
    sessionAuth.resetSession();
    expect(sessionAuth.isAuthenticated, isFalse);

    await tester.tap(find.text('Open Door'));
    await tester.pumpAndSettle();

    // PIN dialog is requested again!
    expect(find.text('Enter your PIN'), findsOneWidget);
  });

  testWidgets('Missing or invalid PIN configuration fails safely with error message',
      (WidgetTester tester) async {
    sessionAuth.setTestPin(null); // Invalid / unconfigured

    await tester.pumpWidget(buildHomeScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Door'));
    await tester.pumpAndSettle();

    // PIN dialog should not open and session remains unauthenticated
    expect(find.text('Enter your PIN'), findsNothing);
    expect(sessionAuth.isAuthenticated, isFalse);

    // Clear fail-safe error feedback is shown
    expect(
      find.text('PIN configuration error: DOOR_PIN is missing or invalid in .env.'),
      findsOneWidget,
    );
  });
}
