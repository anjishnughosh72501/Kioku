// Kioku smoke test — verifies the app boots to onboarding or join screen.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_mobile/main.dart';

void main() {
  testWidgets('App boots without crashing and shows onboarding for new users', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const ProviderScope(child: KiokuApp()));
    await tester.pumpAndSettle();

    expect(find.text('Zero-Knowledge Privacy'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('App boots to Join screen when onboarding is completed', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'kioku_onboarding_done': true});

    await tester.pumpWidget(const ProviderScope(child: KiokuApp()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Kioku'), findsWidgets);
  });
}