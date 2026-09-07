
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:airamp_flutter/src/core/components/status_badge.dart';
void main() {
  testWidgets('StatusBadge renders label', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: StatusBadge(label: 'Active'))));
    expect(find.text('Active'), findsOneWidget);
  });
}

