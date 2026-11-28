import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:darna/core/theme.dart';
import 'package:darna/services/session_auth_service.dart';
import 'package:darna/widgets/pin_entry_dialog.dart';

void main() {
  late SessionAuthService authService;

  setUp(() {
    authService = SessionAuthService();
    authService.resetSession();
    authService.setTestPin('4829');
  });

  Widget buildTestDialog({ThemeData? theme}) {
    return MaterialApp(
      theme: theme ?? AppTheme.lightTheme,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showDialog<bool>(
                context: context,
                builder: (_) => const PinEntryDialog(),
              ),
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('displays title, masked indicators, and keypad 0-9',
      (WidgetTester tester) async {
    await tester.pumpWidget(buildTestDialog());
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your PIN'), findsOneWidget);
    expect(find.text('Enter your 4-digit PIN to unlock Darna'), findsOneWidget);

    // Verify all 10 numeric buttons (0-9) exist
    for (int i = 0; i <= 9; i++) {
      expect(find.text(i.toString()), findsOneWidget);
    }

    // Verify backspace and cancel buttons exist
    expect(find.byIcon(Icons.backspace_outlined), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
  });

  testWidgets('pressing backspace removes entered digits',
      (WidgetTester tester) async {
    await tester.pumpWidget(buildTestDialog());
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // Tap 1, 2
    await tester.tap(find.text('1'));
    await tester.pump();
    await tester.tap(find.text('2'));
    await tester.pump();

    // Tap backspace
    await tester.tap(find.byIcon(Icons.backspace_outlined));
    await tester.pump();

    // Verify still open and not authenticated
    expect(find.text('Enter your PIN'), findsOneWidget);
    expect(authService.isAuthenticated, isFalse);
  });

  testWidgets('entering correct PIN marks session authenticated and closes dialog',
      (WidgetTester tester) async {
    bool? dialogResult;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                dialogResult = await showDialog<bool>(
                  context: context,
                  builder: (_) => const PinEntryDialog(),
                );
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // Tap 4, 8, 2, 9
    await tester.tap(find.text('4'));
    await tester.pump();
    await tester.tap(find.text('8'));
    await tester.pump();
    await tester.tap(find.text('2'));
    await tester.pump();
    await tester.tap(find.text('9'));
    await tester.pumpAndSettle();

    // Dialog closed with true
    expect(dialogResult, isTrue);
    expect(authService.isAuthenticated, isTrue);
    expect(find.text('Enter your PIN'), findsNothing);
  });

  testWidgets('entering incorrect PIN shows error feedback and clears for retry',
      (WidgetTester tester) async {
    await tester.pumpWidget(buildTestDialog());
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // Enter wrong PIN: 1, 2, 3, 4
    await tester.tap(find.text('1'));
    await tester.pump();
    await tester.tap(find.text('2'));
    await tester.pump();
    await tester.tap(find.text('3'));
    await tester.pump();
    await tester.tap(find.text('4'));
    await tester.pump(); // Triggers _validatePin

    // Verify error feedback
    expect(find.text('Incorrect PIN. Please try again.'), findsOneWidget);
    expect(authService.isAuthenticated, isFalse);

    // After 400ms delay, dots clear and user can retry
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Enter your PIN'), findsOneWidget); // Still open!

    // Now enter the correct PIN: 4, 8, 2, 9
    await tester.tap(find.text('4'));
    await tester.pump();
    await tester.tap(find.text('8'));
    await tester.pump();
    await tester.tap(find.text('2'));
    await tester.pump();
    await tester.tap(find.text('9'));
    await tester.pumpAndSettle();

    // Succeeded on retry!
    expect(authService.isAuthenticated, isTrue);
    expect(find.text('Enter your PIN'), findsNothing);
  });

  testWidgets('closing dialog via cancel button leaves session unauthenticated',
      (WidgetTester tester) async {
    bool? dialogResult;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                dialogResult = await showDialog<bool>(
                  context: context,
                  builder: (_) => const PinEntryDialog(),
                );
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // Tap Cancel
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(dialogResult, isFalse);
    expect(authService.isAuthenticated, isFalse);
    expect(find.text('Enter your PIN'), findsNothing);
  });

  testWidgets('renders cleanly in dark theme', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestDialog(theme: AppTheme.darkTheme));
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your PIN'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
  });
}
