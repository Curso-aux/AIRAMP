import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:airamp_flutter/src/features/student/presentation/student_home_screen.dart';
import 'package:airamp_flutter/src/features/auth/application/auth_provider.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('StudentHomeScreen renders welcome header', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(() => _MockAuthNotifier()),
        ],
        child: const MaterialApp(home: Scaffold(body: StudentHomeScreen())),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Welcome back,'), findsOneWidget);
  });
}

class _MockAuthNotifier extends AuthNotifier {
  @override
  User? build() {
    return User(id: '1', email: 'test@test.com', role: 'student', fullName: 'Test User');
  }
}
