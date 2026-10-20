import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:airamp_flutter/src/core/database/database_helper.dart';
import 'package:airamp_flutter/src/features/auth/application/auth_provider.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Session Must Change Password Reopening & Persistence Tests', () {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final testStudentEmail = 'firstlogin_$timestamp@example.com';
    final testPassword = 'Initial@123';

    test('reopening app / bootstrap preserves mustChangePassword requirement from session', () async {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      // 1. Create a student requiring password change
      final studentId = await dbHelper.createStudent(
        fullName: 'First Login Student $timestamp',
        email: testStudentEmail,
        password: testPassword,
        username: 'firstlogin_$timestamp',
        grade: 'Grade 10',
        section: 'Ruby',
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // 2. Perform initial login
      await container.read(authProvider.notifier).login(testStudentEmail, testPassword);
      final loggedInUser = container.read(authProvider);

      expect(loggedInUser, isNotNull);
      expect(loggedInUser!.mustChangePassword, isTrue);

      // Verify sessions table has must_change_password = 1
      final sessionRows = await db.query('sessions', orderBy: 'id DESC', limit: 1);
      expect(sessionRows, isNotEmpty);
      expect(sessionRows.first['must_change_password'], equals(1));

      // 3. Simulate App Close & Reopen (Re-bootstrap with new ProviderContainer)
      final reopenedContainer = ProviderContainer();
      addTearDown(reopenedContainer.dispose);

      // Before bootstrap, state is null
      expect(reopenedContainer.read(authProvider), isNull);

      // Run app bootstrap (what happens when reopening the app)
      await reopenedContainer.read(authProvider.notifier).bootstrap();
      final restoredUser = reopenedContainer.read(authProvider);

      // CRITICAL ASSERTION: mustChangePassword MUST NOT be bypassed or lost upon reopening!
      expect(restoredUser, isNotNull);
      expect(restoredUser!.id, equals(studentId));
      expect(restoredUser.mustChangePassword, isTrue);

      // 4. Update the password to satisfy the requirement
      await reopenedContainer.read(authProvider.notifier).updateProfile(password: 'NewStrongPassword@123');
      final updatedUser = reopenedContainer.read(authProvider);

      expect(updatedUser!.mustChangePassword, isFalse);

      // Verify sessions table was cleared to 0
      final updatedSessionRows = await db.query('sessions', orderBy: 'id DESC', limit: 1);
      expect(updatedSessionRows.first['must_change_password'], equals(0));

      // 5. Simulate closing and reopening app AGAIN after password has been changed
      final postChangeContainer = ProviderContainer();
      addTearDown(postChangeContainer.dispose);

      await postChangeContainer.read(authProvider.notifier).bootstrap();
      final postChangeUser = postChangeContainer.read(authProvider);

      expect(postChangeUser, isNotNull);
      expect(postChangeUser!.mustChangePassword, isFalse);
    });

    test('bootstrap enforces mustChangePassword even if user profile in users table is missing or unindexed', () async {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      final orphanUserId = 'student_orphan_$timestamp';

      // Insert directly into sessions with must_change_password = 1 (e.g. cloud restored session)
      await db.delete('sessions');
      await db.insert('sessions', {
        'user_id': orphanUserId,
        'token': 'aira_sec_orphan_token_$timestamp',
        'role': 'student',
        'must_change_password': 1,
        'created_at': DateTime.now().toIso8601String(),
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(authProvider.notifier).bootstrap();
      final restored = container.read(authProvider);

      expect(restored, isNotNull);
      expect(restored!.id, equals(orphanUserId));
      expect(restored.mustChangePassword, isTrue);
    });
  });
}
