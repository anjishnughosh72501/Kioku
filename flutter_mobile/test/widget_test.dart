// Kioku smoke test — verifies the app boots to the Join screen.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_mobile/main.dart';

void main() {
  testWidgets('App boots without crashing', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    // Given no prior Google session, the sign-in (Join) screen renders.
    await tester.pumpWidget(const ProviderScope(child: KiokuApp()));
    await tester.pumpAndSettle();

    expect(find.text('Kioku'), findsWidgets);
  });
}