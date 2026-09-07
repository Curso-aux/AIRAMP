import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:airamp_flutter/main.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('AirampApp boots without error', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: AirampApp(),
      ),
    );

    // First frame: bootstrap loading
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Allow async bootstrap to complete (no infinite animations)
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    // App should have rendered without throwing
    expect(find.byType(AirampApp), findsOneWidget);
  });
}
