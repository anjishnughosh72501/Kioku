import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_mobile/core/services/user_profile_service.dart';
import 'package:flutter_mobile/core/theme/index.dart';
import 'package:flutter_mobile/features/auth/presentation/widgets/username_dialog.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await UserProfileService.instance.init();
  });

  Widget buildTestWidget(Widget child) {
    return MaterialApp(
      theme: AppTheme.coffeeLight(),
      home: Scaffold(body: child),
    );
  }

  testWidgets('UsernameDialog validates empty or single-character input', (tester) async {
    await tester.pumpWidget(buildTestWidget(const UsernameDialog(isDismissible: false)));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Kioku'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);

    // Tap Get Started without entering a name
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    expect(find.text('Please enter a username or nickname'), findsOneWidget);

    // Enter single character
    await tester.enterText(find.byType(TextField), 'A');
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    expect(find.text('Name must be at least 2 characters'), findsOneWidget);
  });

  testWidgets('UsernameDialog saves username and marks kioku_username_prompted on valid submit', (tester) async {
    await tester.pumpWidget(buildTestWidget(const UsernameDialog(isDismissible: false)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'TestUser');
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('kioku_username'), 'TestUser');
    expect(prefs.getBool('kioku_username_prompted'), true);
    expect(prefs.getBool('first_startup_completed'), true);
  });

  testWidgets('UsernameDialog.showIfNeeded does not show dialog if already prompted', (tester) async {
    SharedPreferences.setMockInitialValues({
      'kioku_username': 'ExistingUser',
      'kioku_username_prompted': true,
      'first_startup_completed': true,
    });
    await UserProfileService.instance.init();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.coffeeLight(),
        home: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () => UsernameDialog.showIfNeeded(context),
              child: const Text('Check Dialog'),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Check Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Kioku'), findsNothing);
  });
}
