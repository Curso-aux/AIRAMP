import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:airamp_flutter/src/core/database/database_helper.dart';
import 'package:airamp_flutter/src/features/landing/presentation/components/placeholders_and_vanish_input_demo.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Student/Teacher Inquiry and Admin Reply Workflow', () {
    test('DatabaseHelper inquiry lifecycle: lookup, submit, list, and reply', () async {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      // Seed a test student
      await db.insert(
        'users',
        {
          'id': 'STU-TEST-999',
          'email': 'student999@school.edu',
          'full_name': 'Maria Santos',
          'password': 'hashed_password_test',
          'role': 'student',
          'created_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 1. Verify ID lookup succeeds for valid student ID
      final user = await dbHelper.findUserByIdOrIdentifier('STU-TEST-999');
      expect(user, isNotNull);
      expect(user!['id'], 'STU-TEST-999');
      expect(user['name'], 'Maria Santos');
      expect(user['email'], 'student999@school.edu');
      expect(user['role'], 'student');

      // 2. Verify lookup returns null for non-existent ID
      final notFound = await dbHelper.findUserByIdOrIdentifier('INVALID-ID-000');
      expect(notFound, isNull);

      // 3. Submit an inquiry with the verified ID
      final inquiryId = await dbHelper.submitInquiry(
        userId: user['id'] as String,
        userName: user['name'] as String,
        userEmail: user['email'] as String,
        userRole: user['role'] as String,
        question: 'When will the final exams schedule be posted?',
      );
      expect(inquiryId, startsWith('INQ-'));

      // 4. Retrieve inquiries and check pending status
      final inquiries = await dbHelper.getInquiries(status: 'pending');
      final foundInq = inquiries.firstWhere((inq) => inq['id'] == inquiryId);
      expect(foundInq['user_id'], 'STU-TEST-999');
      expect(foundInq['status'], 'pending');
      expect(foundInq['question'], 'When will the final exams schedule be posted?');

      // 5. Verify pending count is at least 1
      final pendingCount = await dbHelper.getPendingInquiriesCount();
      expect(pendingCount, greaterThanOrEqualTo(1));

      // 6. Admin replies to the inquiry
      await dbHelper.replyToInquiry(
        inquiryId: inquiryId,
        reply: 'The final examination schedule will be published on Friday via the student portal.',
        repliedBy: 'Admin Team',
      );

      // 7. Verify replied status and details
      final repliedList = await dbHelper.getInquiries(status: 'replied');
      final repliedInq = repliedList.firstWhere((inq) => inq['id'] == inquiryId);
      expect(repliedInq['status'], 'replied');
      expect(repliedInq['reply'], contains('published on Friday'));
      expect(repliedInq['replied_by'], 'Admin Team');
      expect(repliedInq['replied_at'], isNotNull);
    });

    testWidgets('PlaceholdersAndVanishInputDemo guides users to login for complicated questions without requiring ID', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PlaceholdersAndVanishInputDemo(isDark: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the school management title
      expect(find.text('Ask AIRA School Management'), findsOneWidget);

      // Verify ID input box is removed
      expect(find.textContaining('Student / Faculty ID'), findsNothing);

      // Verify guidance message for complicated questions
      expect(find.textContaining("If it's a complicated question, you can proceed to log in and contact your concern inside"), findsWidgets);
    });
  });
}
