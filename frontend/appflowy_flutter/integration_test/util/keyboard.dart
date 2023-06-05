import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart' as flutter_test;

class FlowyTestKeyboard {
  static Future<void> simulateKeyDownEvent(
    final List<LogicalKeyboardKey> keys, {
    required final flutter_test.WidgetTester tester,
  }) async {
    for (final LogicalKeyboardKey key in keys) {
      await flutter_test.simulateKeyDownEvent(key);
      await tester.pumpAndSettle();
    }
  }
}
