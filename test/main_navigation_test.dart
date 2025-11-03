import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orivis/main.dart';

void main() {
  testWidgets('navigates to Settings tab', (tester) async {
    await tester.pumpWidget(const OrivisApp());
    expect(find.text('Orivis'), findsOneWidget);

    // Tap the Settings destination in the NavigationBar
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    // Settings AppBar title should be visible (avoid matching nav label)
    final appBarTitle = find.descendant(
      of: find.byType(AppBar),
      matching: find.text('Settings'),
    );
    expect(appBarTitle, findsOneWidget);
  });
}
