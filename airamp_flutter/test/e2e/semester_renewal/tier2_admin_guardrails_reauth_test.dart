// Tier 2 E2E Test Suite: Protected Administrative Reset Trigger & Re-Authentication Guardrails
// Tests: Trigger lock state, multi-step confirmation flow, password re-auth check, rejection of invalid credentials.

import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import 'harness/academic_term_fixture.dart';
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

  group('Tier 2: Protected Admin Guardrails & Re-Authentication', () {
    test('1. Reset trigger is initially locked and disabled before archive generation', () {
      const initialState = SemesterRenewalState();

      expect(initialState.isArchiveGenerating, isFalse);
      expect(initialState.isArchiveVerified, isFalse);
      expect(initialState.verificationResult, isNull);
      expect(initialState.isResetUnlocked, isFalse);
    });

    test('2. Attempting purge while trigger is locked throws StateError and leaves database untouched', () async {
      final initialSnapshot = await harness.snapshotState();

      expect(
        () async => await harness.service.executeSelectivePurge(
          adminId: 'A-100-0001',
          schoolId: 'sch_main',
          adminPassword: fixture.adminPassword,
          scopeReviewed: true,
          acknowledgementChecked: true,
          confirmationPhrase: 'CONFIRM SEMESTER RESET',
          isResetUnlocked: false, // Locked!
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Semester reset is locked'),
        )),
      );

      // Verify zero state mutations
      final postSnapshot = await harness.snapshotState();
      expect(postSnapshot.subjectCount, equals(initialSnapshot.subjectCount));
      expect(postSnapshot.quizCount, equals(initialSnapshot.quizCount));
      expect(postSnapshot.submissionCount, equals(initialSnapshot.submissionCount));
    });

    test('3. Failed archive verification maintains locked reset trigger', () {
      final corruptBytes = Uint8List.fromList([0x00, 0x01, 0x02]);
      final verification = harness.service.verifyPdfArchive(corruptBytes, 2);

      expect(verification.isValid, isFalse);

      var state = const SemesterRenewalState();
      state = state.copyWith(
        isArchiveVerified: false,
        verificationResult: verification,
      );

      expect(state.isResetUnlocked, isFalse);
    });

    test('4. Successful archive verification unlocks the administrative reset trigger', () async {
      final records = await harness.service.fetchAllStudentRecords();
      final pdfBytes = await harness.service.generatePdfArchive(records);
      final verification = harness.service.verifyPdfArchive(pdfBytes, records.length);

      expect(verification.isValid, isTrue);

      var state = const SemesterRenewalState();
      state = state.copyWith(
        isArchiveVerified: true,
        verificationResult: verification,
      );

      expect(state.isResetUnlocked, isTrue);
    });

    test('5. Confirmation sequence rejects incomplete steps (scope, acknowledgement, phrase)', () async {
      // Step A: Scope not reviewed
      expect(
        () async => await harness.service.executeSelectivePurge(
          adminId: 'A-100-0001',
          schoolId: 'sch_main',
          adminPassword: fixture.adminPassword,
          scopeReviewed: false,
          acknowledgementChecked: true,
          confirmationPhrase: 'CONFIRM SEMESTER RESET',
          isResetUnlocked: true,
        ),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('scope must be reviewed'))),
      );

      // Step B: Acknowledgement unchecked
      expect(
        () async => await harness.service.executeSelectivePurge(
          adminId: 'A-100-0001',
          schoolId: 'sch_main',
          adminPassword: fixture.adminPassword,
          scopeReviewed: true,
          acknowledgementChecked: false,
          confirmationPhrase: 'CONFIRM SEMESTER RESET',
          isResetUnlocked: true,
        ),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('acknowledgement must be checked'))),
      );

      // Step C: Incorrect confirmation phrase
      expect(
        () async => await harness.service.executeSelectivePurge(
          adminId: 'A-100-0001',
          schoolId: 'sch_main',
          adminPassword: fixture.adminPassword,
          scopeReviewed: true,
          acknowledgementChecked: true,
          confirmationPhrase: 'WRONG PHRASE',
          isResetUnlocked: true,
        ),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('Confirmation phrase mismatch'))),
      );
    });

    test('6. Password re-authentication rejects invalid credentials and halts purge without database changes', () async {
      final initialSnapshot = await harness.snapshotState();

      expect(
        () async => await harness.service.executeSelectivePurge(
          adminId: 'A-100-0001',
          schoolId: 'sch_main',
          adminPassword: 'IncorrectPassword999!', // Wrong password
          scopeReviewed: true,
          acknowledgementChecked: true,
          confirmationPhrase: 'CONFIRM SEMESTER RESET',
          isResetUnlocked: true,
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Administrative re-authentication failed'),
        )),
      );

      // Zero mutations
      final postSnapshot = await harness.snapshotState();
      expect(postSnapshot.subjectCount, equals(initialSnapshot.subjectCount));
      expect(postSnapshot.submissionCount, equals(initialSnapshot.submissionCount));
      expect(postSnapshot.auditLogCount, equals(0));
    });

    test('7. Password re-authentication succeeds with valid password and executes purge', () async {
      final summary = await harness.service.executeSelectivePurge(
        adminId: 'A-100-0001',
        schoolId: 'sch_main',
        adminPassword: fixture.adminPassword, // Correct password
        scopeReviewed: true,
        acknowledgementChecked: true,
        confirmationPhrase: 'CONFIRM SEMESTER RESET',
        isResetUnlocked: true,
      );

      expect(summary.deletedSubjectsCount, equals(2));
      expect(summary.deletedAttemptsCount, equals(4));
      expect(summary.deletedSubmissionsCount, equals(3));
      expect(summary.preservedUsersCount, equals(5)); // 1 admin + 2 teachers + 2 students
    });
  });
}
