// Tier 4 E2E Test Suite: Multi-Role End-to-End Workflows & Adversarial Resilience
// Scenarios:
//   S1: Complete End-to-End Semester Rollover Lifecycle
//   S2: Failed Re-Authentication Lockdown & Zero Mutation
//   S3: Large-Scale Chunked Batch Deletion (>400 Documents Guarding 500 Op Limit)
//   S4: Continuing Student Re-Enrollment Readiness
//   S5: Corrupted Buffer & Adversarial Resilience

import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import 'harness/academic_term_fixture.dart';
import 'harness/mock_semester_firestore_gateway.dart';
import 'harness/semester_renewal_contracts.dart';
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

  group('Tier 4: Multi-Role Workflows & Resilience Scenarios', () {
    test('Scenario S1: Complete End-to-End Semester Rollover Lifecycle', () async {
      // PHASE 1: Active Term Verification
      final activeSnapshot = await harness.snapshotState();
      expect(activeSnapshot.userCount, equals(5));
      expect(activeSnapshot.studentCount, equals(2));
      expect(activeSnapshot.subjectCount, equals(2));
      expect(activeSnapshot.submissionCount, equals(3));

      // Initial state: reset trigger is locked
      var state = const SemesterRenewalState();
      expect(state.isResetUnlocked, isFalse);

      // PHASE 2: Export Archive Generation
      state = state.copyWith(isArchiveGenerating: true);
      final records = await harness.service.fetchAllStudentRecords();
      final pdfBytes = await harness.service.generatePdfArchive(records);
      state = state.copyWith(isArchiveGenerating: false);

      expect(pdfBytes.lengthInBytes, greaterThan(500));

      // PHASE 3: Archive Verification
      final verification = harness.service.verifyPdfArchive(pdfBytes, records.length);
      expect(verification.isValid, isTrue);

      state = state.copyWith(
        isArchiveVerified: true,
        verificationResult: verification,
      );
      expect(state.isResetUnlocked, isTrue);

      // PHASE 4: Administrative Re-Authentication & Multi-Step Purge
      state = state.copyWith(isPurging: true);
      final summary = await harness.service.executeSelectivePurge(
        adminId: 'A-100-0001',
        schoolId: 'sch_main',
        adminPassword: fixture.adminPassword,
        scopeReviewed: true,
        acknowledgementChecked: true,
        confirmationPhrase: 'CONFIRM SEMESTER RESET',
        isResetUnlocked: state.isResetUnlocked,
      );
      state = state.copyWith(
        isPurging: false,
        purgeSummary: summary,
      );

      // PHASE 5: Post-Purge Verification
      final postSnapshot = await harness.snapshotState();
      expect(postSnapshot.totalTransientCount, equals(0));
      expect(postSnapshot.userCount, equals(5));
      expect(postSnapshot.auditLogCount, equals(1));

      // Verify Student Juan logs in with existing password and has clean slate
      final juan = await harness.firestoreGateway.getDocument('users', 'S-100-0001');
      expect(juan, isNotNull);
      final juanPasswordValid = AcademicTermFixture.computeHash('StudentPass123!', juan!['password_salt'] as String);
      expect(juan['password'], equals(juanPasswordValid));
      expect(juan['enrolled_subjects'], isEmpty);
      expect(juan['enrolled_courses'], equals(0));
    });

    test('Scenario S2: Failed Re-Authentication Lockdown (Zero Mutation)', () async {
      // Admin generates and verifies archive
      final records = await harness.service.fetchAllStudentRecords();
      final pdfBytes = await harness.service.generatePdfArchive(records);
      final verification = harness.service.verifyPdfArchive(pdfBytes, records.length);
      expect(verification.isValid, isTrue);

      final state = SemesterRenewalState(
        isArchiveVerified: true,
        verificationResult: verification,
        isResetUnlocked: true,
      );

      final preLockdownSnapshot = await harness.snapshotState();

      // Admin enters wrong password
      expect(
        () async => await harness.service.executeSelectivePurge(
          adminId: 'A-100-0001',
          schoolId: 'sch_main',
          adminPassword: 'WrongAdminPassword!',
          scopeReviewed: true,
          acknowledgementChecked: true,
          confirmationPhrase: 'CONFIRM SEMESTER RESET',
          isResetUnlocked: state.isResetUnlocked,
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Administrative re-authentication failed'),
        )),
      );

      // Verify ZERO database mutations: every single collection remains unchanged
      final postLockdownSnapshot = await harness.snapshotState();
      expect(postLockdownSnapshot.subjectCount, equals(preLockdownSnapshot.subjectCount));
      expect(postLockdownSnapshot.moduleCount, equals(preLockdownSnapshot.moduleCount));
      expect(postLockdownSnapshot.quizCount, equals(preLockdownSnapshot.quizCount));
      expect(postLockdownSnapshot.quizAttemptCount, equals(preLockdownSnapshot.quizAttemptCount));
      expect(postLockdownSnapshot.assignmentCount, equals(preLockdownSnapshot.assignmentCount));
      expect(postLockdownSnapshot.submissionCount, equals(preLockdownSnapshot.submissionCount));
      expect(postLockdownSnapshot.userCount, equals(preLockdownSnapshot.userCount));
      expect(postLockdownSnapshot.auditLogCount, equals(0));
    });

    test('Scenario S3: Large-Scale Chunked Batch Purge (>400 docs without hitting Firestore 500 limit)', () async {
      // Seed 450 extra transient submissions to exceed 400 operations
      final largeSubmissions = AcademicTermFixture.generateLargeSubmissionsBatch(450);
      for (final sub in largeSubmissions) {
        await harness.firestoreGateway.setDocument('submissions', sub['id'] as String, sub);
      }

      final initialSnapshot = await harness.snapshotState();
      expect(initialSnapshot.submissionCount, equals(453)); // 3 original + 450 extra
      expect(initialSnapshot.totalTransientCount, greaterThan(450));

      final mockGateway = harness.firestoreGateway as MockSemesterFirestoreGateway;
      mockGateway.totalBatchesCommitted = 0;
      mockGateway.batchSizesHistory.clear();

      // Execute purge
      final summary = await harness.service.executeSelectivePurge(
        adminId: 'A-100-0001',
        schoolId: 'sch_main',
        adminPassword: fixture.adminPassword,
        scopeReviewed: true,
        acknowledgementChecked: true,
        confirmationPhrase: 'CONFIRM SEMESTER RESET',
        isResetUnlocked: true,
      );

      expect(summary.deletedSubmissionsCount, equals(453));

      // Assert that operations were chunked and NO batch exceeded 400 operations
      expect(mockGateway.totalBatchesCommitted, greaterThanOrEqualTo(2));
      for (final batchSize in mockGateway.batchSizesHistory) {
        expect(batchSize, lessThanOrEqualTo(400),
            reason: 'Firestore batch limit is 500; service must chunk in sizes <= 400');
        expect(batchSize, greaterThan(0));
      }

      final postSnapshot = await harness.snapshotState();
      expect(postSnapshot.submissionCount, equals(0));
      expect(postSnapshot.userCount, equals(5)); // Users preserved
    });

    test('Scenario S4: Continuing Student Re-Enrollment Readiness', () async {
      // 1. Purge term
      await harness.service.executeSelectivePurge(
        adminId: 'A-100-0001',
        schoolId: 'sch_main',
        adminPassword: fixture.adminPassword,
        scopeReviewed: true,
        acknowledgementChecked: true,
        confirmationPhrase: 'CONFIRM SEMESTER RESET',
        isResetUnlocked: true,
      );

      // 2. Student S-100-0001 logs in with same institutional ID and password
      final student = await harness.firestoreGateway.getDocument('users', 'S-100-0001');
      expect(student, isNotNull);

      // Credentials remain functional
      final salt = student!['password_salt'] as String;
      final expectedHash = AcademicTermFixture.computeHash('StudentPass123!', salt);
      expect(student['password'], equals(expectedHash));

      // Clean slate verification
      expect(student['enrolled_subjects'], isEmpty);
      expect(student['enrolled_courses'], equals(0));

      // 3. New semester starts: Admin creates next semester subject
      await harness.firestoreGateway.setDocument('subjects', 'SUBJ-MATH11', {
        'id': 'SUBJ-MATH11',
        'name': 'Pre-Calculus 11',
        'code': 'MATH11',
        'teacher_id': 'T-100-0001',
        'school_id': 'sch_main',
        'semester': 'Semester 2',
      });

      // 4. Student enrolls in new semester subject immediately without account recreation
      await harness.firestoreGateway.updateDocument('users', 'S-100-0001', {
        'enrolled_subjects': ['SUBJ-MATH11'],
        'enrolled_courses': 1,
      });

      final updatedStudent = await harness.firestoreGateway.getDocument('users', 'S-100-0001');
      expect(updatedStudent!['enrolled_subjects'], contains('SUBJ-MATH11'));
      expect(updatedStudent['enrolled_courses'], equals(1));
      expect(updatedStudent['id'], equals('S-100-0001'));
    });

    test('Scenario S5: Adversarial Buffer Corruption & Guardrail Hardening', () async {
      // Case A: Corrupted buffer with invalid magic bytes
      final malformedBytes = Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF]);
      final badResult = harness.service.verifyPdfArchive(malformedBytes, 2);

      expect(badResult.isValid, isFalse);

      final state = SemesterRenewalState(
        isArchiveVerified: false,
        verificationResult: badResult,
        isResetUnlocked: false,
      );

      expect(state.isResetUnlocked, isFalse);

      // Attempting reset with corrupted archive fails immediately
      expect(
        () async => await harness.service.executeSelectivePurge(
          adminId: 'A-100-0001',
          schoolId: 'sch_main',
          adminPassword: fixture.adminPassword,
          scopeReviewed: true,
          acknowledgementChecked: true,
          confirmationPhrase: 'CONFIRM SEMESTER RESET',
          isResetUnlocked: state.isResetUnlocked,
        ),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('Semester reset is locked'))),
      );

      // Case B: Partial / incomplete confirmation phrase fails
      expect(
        () async => await harness.service.executeSelectivePurge(
          adminId: 'A-100-0001',
          schoolId: 'sch_main',
          adminPassword: fixture.adminPassword,
          scopeReviewed: true,
          acknowledgementChecked: true,
          confirmationPhrase: 'CONFIRM SEMESTER', // Incomplete!
          isResetUnlocked: true,
        ),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('Confirmation phrase mismatch'))),
      );
    });
  });
}
