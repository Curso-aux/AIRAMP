import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:airamp_flutter/src/features/auth/application/auth_provider.dart';
import 'package:airamp_flutter/src/core/theme/app_theme.dart';
import 'package:airamp_flutter/src/features/admin/presentation/web/admin_web_teachers_screen.dart';

class MockAuthNotifier extends AuthNotifier {
  final User? _u;
  MockAuthNotifier(this._u);
  @override
  User? build() => _u;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('Test AdminWebTeachersScreen layout in scaffold column', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final adminUser = User(
      id: 'admin_1',
      email: 'aira@admin',
      fullName: 'Aira Admin',
      role: 'super_admin',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(() => MockAuthNotifier(adminUser)),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: Row(
              children: [
                SizedBox(width: 260),
                Expanded(
                  child: Column(
                    children: [
                      SizedBox(height: 64),
                      Expanded(
                        child: AdminWebTeachersScreen(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Pump frames without pumpAndSettle to avoid infinite timer hang
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Faculty & Teacher Management'), findsOneWidget);
    debugPrint('TEST PASSED CLEANLY');
  });
}
