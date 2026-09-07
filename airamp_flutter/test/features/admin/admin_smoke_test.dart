import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:airamp_flutter/src/features/admin/presentation/admin_dashboard_screen.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('AdminDashboardScreen renders stats cards', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: AdminDashboardScreen())),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    // Header present
    expect(find.text('Admin Dashboard'), findsOneWidget);

    // Stat cards present (count will be 0 since no data)
    expect(find.text('Students'), findsOneWidget);
    expect(find.text('Subjects'), findsOneWidget);
    expect(find.text('Sections'), findsOneWidget);
  });
}
