// Minimal smoke test that keeps `flutter test` green in CI.
//
// The app's real root (MyApp -> MyHomePage) initializes Hive and opens a
// serial port in initState, which is not available in the test environment,
// so it cannot be pumped directly here. This self-contained test verifies the
// test harness and Flutter widget layer build correctly. Replace/extend it
// with real tests of isolated widgets or pure logic as the project grows.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('MaterialApp builds and renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('GL Terminal'))),
      ),
    );

    expect(find.text('GL Terminal'), findsOneWidget);
  });
}
