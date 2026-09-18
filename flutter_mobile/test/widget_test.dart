// Kioku smoke test — verifies the app boots to onboarding or join screen.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_mobile/main.dart';
import 'package:flutter_mobile/features/feed/presentation/screens/feed_screen.dart';

void main() {
  testWidgets('App boots without crashing and shows onboarding for new users', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const ProviderScope(child: KiokuApp()));
    await tester.pumpAndSettle();

    expect(find.text('Zero-Knowledge Privacy'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('App boots to Join screen when onboarding is completed on first startup', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'kioku_onboarding_done': true});

    await tester.pumpWidget(const ProviderScope(child: KiokuApp()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Kioku'), findsWidgets);
  });

  testWidgets('App boots directly to Feed on later startups without showing Join or Onboarding', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'kioku_onboarding_done': true,
      'first_startup_completed': true,
      'kioku_username_prompted': true,
    });

    await tester.pumpWidget(const ProviderScope(child: KiokuApp()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(FeedScreen), findsOneWidget);
    expect(find.text('Sign in with Google'), findsNothing);
    expect(find.text('Welcome to Kioku'), findsNothing);
  });
}