// Tier 3 E2E Test Suite: Selective Academic Data Purge & Account Preservation
// Tests: Transient collections purge, /users preservation, student enrollment fields reset, audit logging.

import 'package:flutter_test/flutter_test.dart';

import 'harness/academic_term_fixture.dart';
import 'harness/semester_renewal_test_harness.dart';

void main() {
  late SemesterRenewalTestHarness harness;
  late AcademicTermFixture fixture;

  setUp(() async {
    harness = await SemesterRenewalTestHarness.initialize();
    fixture = AcademicTermFixture();
    await harness.seedAcademicTerm(fixture);
  });

  tearDown(() async {
    await harness.dispose();
  });

  group('Tier 3: Selective Purge & User Preservation', () {
    test('1. Selective purge completely deletes all transient academic collections', () async {
      final initialSnapshot = await harness.snapshotState();
      expect(initialSnapshot.totalTransientCount, greaterThan(0));

      final summary = await harness.service.executeSelectivePurge(
        adminId: 'A-100-0001',
        schoolId: 'sch_main',
        adminPassword: fixture.adminPassword,
        scopeReviewed: true,
        acknowledgementChecked: true,
        confirmationPhrase: 'CONFIRM SEMESTER RESET',
        isResetUnlocked: true,
      );

      final postSnapshot = await harness.snapshotState();

      // Verify all transient collections are empty (0 documents)
      expect(postSnapshot.subjectCount, equals(0));
      expect(postSnapshot.moduleCount, equals(0));
      expect(postSnapshot.quizCount, equals(0));
      expect(postSnapshot.quizAttemptCount, equals(0));
      expect(postSnapshot.assignmentCount, equals(0));
      expect(postSnapshot.submissionCount, equals(0));
      expect(postSnapshot.flashcardCount, equals(0));
      expect(postSnapshot.scheduleCount, equals(0));
      expect(postSnapshot.enrollmentKeyCount, equals(0));
      expect(postSnapshot.regLinkCount, equals(0));
      expect(postSnapshot.totalTransientCount, equals(0));

      // Verify summary numbers match what was deleted
      expect(summary.deletedSubjectsCount, equals(initialSnapshot.subjectCount));
      expect(summary.deletedModulesCount, equals(initialSnapshot.moduleCount));
      expect(summary.deletedQuizzesCount, equals(initialSnapshot.quizCount));
      expect(summary.deletedAttemptsCount, equals(initialSnapshot.quizAttemptCount));
      expect(summary.deletedAssignmentsCount, equals(initialSnapshot.assignmentCount));
      expect(summary.deletedSubmissionsCount, equals(initialSnapshot.submissionCount));
    });

    test('2. Strict preservation of all core accounts in /users (admin, teacher, student)', () async {
      final initialUsers = await harness.firestoreGateway.getCollection('users');
      expect(initialUsers.length, equals(5));

      await harness.service.executeSelectivePurge(
        adminId: 'A-100-0001',
        schoolId: 'sch_main',
        adminPassword: fixture.adminPassword,
        scopeReviewed: true,
        acknowledgementChecked: true,
        confirmationPhrase: 'CONFIRM SEMESTER RESET',
        isResetUnlocked: true,
      );

      final preservedUsers = await harness.firestoreGateway.getCollection('users');
      expect(preservedUsers.length, equals(initialUsers.length));

      // Verify Admin
      final admin = preservedUsers.firstWhere((u) => u['id'] == 'A-100-0001');
      expect(admin['role'], equals('admin'));
      expect(admin['password'], equals(fixture.adminPasswordHash));
      expect(admin['password_salt'], equals(fixture.adminSalt));

      // Verify Teachers
      final teachers = preservedUsers.where((u) => u['role'] == 'teacher').toList();
      expect(teachers.length, equals(2));
      for (final t in teachers) {
        expect(t['institutional_id'], startsWith('T-100-'));
        expect(t['password'], isNotEmpty);
        expect(t['password_salt'], isNotEmpty);
      }

      // Verify Students
      final students = preservedUsers.where((u) => u['role'] == 'student').toList();
      expect(students.length, equals(2));
      for (final s in students) {
        expect(s['institutional_id'], startsWith('S-100-'));
        expect(s['password'], isNotEmpty);
        expect(s['password_salt'], isNotEmpty);
      }
    });

    test('3. Student profile enrollment fields are cleanly reset to empty state', () async {
      // Prior to purge: Juan has 2 subjects enrolled
      final studentBefore = await harness.firestoreGateway.getDocument('users', 'S-100-0001');
      expect((studentBefore!['enrolled_subjects'] as List).length, equals(2));
      expect(studentBefore['enrolled_courses'], equals(2));

      await harness.service.executeSelectivePurge(
        adminId: 'A-100-0001',
        schoolId: 'sch_main',
        adminPassword: fixture.adminPassword,
        scopeReviewed: true,
        acknowledgementChecked: true,
        confirmationPhrase: 'CONFIRM SEMESTER RESET',
        isResetUnlocked: true,
      );

      final studentAfter = await harness.firestoreGateway.getDocument('users', 'S-100-0001');
      expect(studentAfter!['enrolled_subjects'], isEmpty);
      expect(studentAfter['enrolled_courses'], equals(0));

      // Personal identity and section remain preserved
      expect(studentAfter['full_name'], equals('Juan Dela Cruz'));
      expect(studentAfter['section'], equals('10-Rizal'));
      expect(studentAfter['grade_level'], equals('Grade 10'));
    });

    test('4. Base teacher profiles remain intact with active status', () async {
      await harness.service.executeSelectivePurge(
        adminId: 'A-100-0001',
        schoolId: 'sch_main',
        adminPassword: fixture.adminPassword,
        scopeReviewed: true,
        acknowledgementChecked: true,
        confirmationPhrase: 'CONFIRM SEMESTER RESET',
        isResetUnlocked: true,
      );

      final teacher = await harness.firestoreGateway.getDocument('users', 'T-100-0001');
      expect(teacher, isNotNull);
      expect(teacher!['full_name'], equals('Prof. Maria Santos'));
      expect(teacher['department'], equals('Mathematics'));
      expect(teacher['is_active'], equals(1));
    });

    test('5. Reset execution event is recorded in system_audit_logs with execution summary', () async {
      final initialLogs = await harness.firestoreGateway.countCollection('system_audit_logs');
      expect(initialLogs, equals(0));

      final summary = await harness.service.executeSelectivePurge(
        adminId: 'A-100-0001',
        schoolId: 'sch_main',
        adminPassword: fixture.adminPassword,
        scopeReviewed: true,
        acknowledgementChecked: true,
        confirmationPhrase: 'CONFIRM SEMESTER RESET',
        isResetUnlocked: true,
      );

      final logs = await harness.firestoreGateway.getCollection('system_audit_logs');
      expect(logs.length, equals(1));

      final log = logs.first;
      expect(log['event'], equals('SEMESTER_SELECTIVE_PURGE'));
      expect(log['admin_id'], equals('A-100-0001'));
      expect(log['school_id'], equals('sch_main'));
      expect(log['timestamp'], isNotEmpty);
      expect(log['summary'], isNotNull);
      expect(log['summary']['preserved_users'], equals(5));
      expect(log['summary']['total_deleted'], equals(summary.totalDeletedRecords));
    });

    test('6. Idempotent purge execution on already cleared term completes cleanly', () async {
      // First purge
      await harness.service.executeSelectivePurge(
        adminId: 'A-100-0001',
        schoolId: 'sch_main',
        adminPassword: fixture.adminPassword,
        scopeReviewed: true,
        acknowledgementChecked: true,
        confirmationPhrase: 'CONFIRM SEMESTER RESET',
        isResetUnlocked: true,
      );

      // Second purge immediately following
      final secondSummary = await harness.service.executeSelectivePurge(
        adminId: 'A-100-0001',
        schoolId: 'sch_main',
        adminPassword: fixture.adminPassword,
        scopeReviewed: true,
        acknowledgementChecked: true,
        confirmationPhrase: 'CONFIRM SEMESTER RESET',
        isResetUnlocked: true,
      );

      expect(secondSummary.deletedSubjectsCount, equals(0));
      expect(secondSummary.deletedSubmissionsCount, equals(0));
      expect(secondSummary.preservedUsersCount, equals(5));

      final logs = await harness.firestoreGateway.getCollection('system_audit_logs');
      expect(logs.length, equals(2));
    });
  });
}
