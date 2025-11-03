// Verifies the root app renders and shows the Home title.

import 'package:flutter_test/flutter_test.dart';

import 'package:orivis/main.dart';

void main() {
  testWidgets('Orivis app renders HomeScreen', (WidgetTester tester) async {
    await tester.pumpWidget(const OrivisApp());
    expect(find.text('Orivis'), findsOneWidget);
  });
}
