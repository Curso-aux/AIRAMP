import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:airamp_flutter/src/features/student/presentation/student_profile_screen.dart';
import 'package:airamp_flutter/src/features/auth/application/auth_provider.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Student Mandatory Password Change Tests', () {
    testWidgets('renders dedicated mandatory security setup when mustChangePassword is true', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _MockMustChangeAuthNotifier()),
          ],
          child: const MaterialApp(
            home: StudentProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify dedicated header and locked title
      expect(find.text('Security Requirement'), findsOneWidget);
      expect(find.text('Password Change Required'), findsOneWidget);
      expect(find.text('Save Password & Unlock Account'), findsOneWidget);
      expect(find.text('Sign out to switch account'), findsOneWidget);

      // Verify that normal profile clutter is NOT shown
      expect(find.text('Appearance'), findsNothing);
      expect(find.text('Personal Information'), findsNothing);
      expect(find.text('App Updates & Version'), findsNothing);
    });

    testWidgets('renders normal profile screen when mustChangePassword is false', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _MockNormalAuthNotifier()),
          ],
          child: const MaterialApp(
            home: StudentProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify normal profile header and sections
      expect(find.text('Student Profile'), findsOneWidget);
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Personal Information'), findsOneWidget);
      expect(find.text('Save Password & Unlock Account'), findsNothing);
    });

    testWidgets('real-time validation indicators update as user enters new password', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _MockMustChangeAuthNotifier()),
          ],
          child: const MaterialApp(
            home: StudentProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find password textfields
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(2));

      // Enter matching password >= 6 chars
      await tester.enterText(textFields.first, 'newpass123');
      await tester.enterText(textFields.last, 'newpass123');
      await tester.pump();

      // Both criteria met
      expect(find.text('At least 6 characters'), findsOneWidget);
      expect(find.text('Passwords match'), findsOneWidget);
    });
  });
}

class _MockMustChangeAuthNotifier extends AuthNotifier {
  @override
  User? build() {
    return User(
      id: 'student_test_1',
      email: 'student_test@example.com',
      role: 'student',
      fullName: 'New Student',
      mustChangePassword: true,
    );
  }
}

class _MockNormalAuthNotifier extends AuthNotifier {
  @override
  User? build() {
    return User(
      id: 'student_test_2',
      email: 'student_regular@example.com',
      role: 'student',
      fullName: 'Regular Student',
      mustChangePassword: false,
    );
  }
}
