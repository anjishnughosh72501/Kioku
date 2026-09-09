import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mobile/core/theme/index.dart';
import 'package:flutter_mobile/shared/widgets/clay_card.dart';

void main() {
  testWidgets('ClayCard renders child and fires onTap', (WidgetTester tester) async {
    bool tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.forestDark(),
        home: Scaffold(
          body: ClayCard(
            onTap: () => tapped = true,
            child: const Text('Clay Card Content'),
          ),
        ),
      ),
    );

    expect(find.text('Clay Card Content'), findsOneWidget);

    await tester.tap(find.text('Clay Card Content'));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
  });

  testWidgets('ClayCard renders without onTap as static container', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.forestDark(),
        home: const Scaffold(
          body: ClayCard(
            child: Text('Static Card'),
          ),
        ),
      ),
    );

    expect(find.text('Static Card'), findsOneWidget);
  });
}
