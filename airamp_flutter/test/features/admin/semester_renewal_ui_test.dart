import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:airamp_flutter/src/core/theme/app_theme.dart';
import 'package:airamp_flutter/src/core/database/database_helper.dart';
import 'package:airamp_flutter/src/features/auth/application/auth_provider.dart';
import 'package:airamp_flutter/src/features/admin/domain/semester_archive_models.dart';
import 'package:airamp_flutter/src/features/admin/data/semester_record_archiving_service.dart';
import 'package:airamp_flutter/src/features/admin/data/semester_selective_purge_service.dart';
import 'package:airamp_flutter/src/features/admin/presentation/controllers/semester_renewal_controller.dart';
import 'package:airamp_flutter/src/features/admin/presentation/widgets/academic_term_reset_modal.dart';
import 'package:airamp_flutter/src/features/admin/presentation/web/admin_web_analytics_view.dart';
import 'package:airamp_flutter/src/features/admin/data/admin_repository.dart';

// ── Test Doubles ─────────────────────────────────────────────────────────────

class MockArchivingService implements ISemesterRecordArchivingService {
  List<StudentArchiveRecord> mockRecords;
  bool shouldVerifyPass;

  MockArchivingService({
    this.mockRecords = const [],
    this.shouldVerifyPass = true,
  });

  @override
  Future<List<StudentArchiveRecord>> fetchAllStudentRecords() async {
    return mockRecords;
  }

  @override
  Future<Uint8List> generatePdfArchive(List<StudentArchiveRecord> records) async {
    // Standard mock PDF header
    return Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D, ...List.filled(2000, 65)]);
  }

  @override
  ArchiveVerificationResult verifyPdfArchive(Uint8List pdfBytes, int expectedStudentCount) {
    if (shouldVerifyPass) {
      return ArchiveVerificationResult(
        isValid: true,
        studentCount: expectedStudentCount,
        byteLength: pdfBytes.length,
        checksum: 'mock_checksum_abc123',
        errorMessage: null,
        pdfBytes: pdfBytes,
      );
    } else {
      return ArchiveVerificationResult(
        isValid: false,
        studentCount: 0,
        byteLength: pdfBytes.length,
        checksum: 'mock_checksum_invalid',
        errorMessage: 'Mock archive verification failure',
        pdfBytes: pdfBytes,
      );
    }
  }
}

class MockSelectivePurgeService implements ISemesterSelectivePurgeService {
  int purgeCalls = 0;
  String? lastAdminId;
  String? lastSchoolId;
  PurgeSummary? customSummary;

  @override
  Future<PurgeSummary> executeSelectivePurge({
    required String adminId,
    required String schoolId,
  }) async {
    purgeCalls++;
    lastAdminId = adminId;
    lastSchoolId = schoolId;

    return customSummary ??
        PurgeSummary(
          deletedSubjectsCount: 8,
          deletedModulesCount: 24,
          deletedQuizzesCount: 12,
          deletedAttemptsCount: 45,
          deletedAssignmentsCount: 10,
          deletedSubmissionsCount: 38,
          preservedUsersCount: 25,
          executedAt: DateTime.now(),
        );
  }
}

class MockAdminAnalyticsNotifier extends AdminAnalyticsNotifier {
  @override
  Map<String, dynamic> build() {
    return {
      'totalUsers': 50,
      'totalStudents': 40,
      'totalTeachers': 10,
      'totalEnrollments': 80,
      'totalSubjects': 8,
      'totalLos': 32,
      'totalAttempts': 120,
      'passedAttempts': 100,
      'passRate': 83,
      'avgScore': 86,
      'unassignedStudents': 0,
      'demographics': {'regular': 35, 'transferee': 5},
      'hasData': true,
      'subjectEnrollments': <Map<String, dynamic>>[],
      'sectionDistribution': <Map<String, dynamic>>[],
      'recentAttempts': <Map<String, dynamic>>[],
    };
  }

  @override
  Future<void> loadAnalytics({AnalyticsFilter? filter, bool syncCloud = false}) async {}
}

class MockSubjectsNotifier extends SubjectsNotifier {
  @override
  List<Map<String, dynamic>> build() => [
        {'id': 1, 'name': 'Computer Systems Servicing', 'subject_code': 'CSS-NC-II'},
      ];
}

class MockSectionsNotifier extends SectionsNotifier {
  @override
  List<Map<String, dynamic>> build() => [
        {'id': 1, 'name': 'Diamond', 'grade': 'Grade 10'},
      ];
}

// ── Test Suite ───────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
  });

  group('Milestone 2: Semester-End Record Archiving & Re-Auth Guardrails Tests', () {
    late MockArchivingService mockArchiving;
    late MockSelectivePurgeService mockPurge;

    setUp(() {
      mockArchiving = MockArchivingService(
        mockRecords: [
          StudentArchiveRecord(
            studentId: 'S-100-0001',
            fullName: 'Christian Test Student',
            section: 'Diamond',
            gradeLevel: 'Grade 10',
            achievements: AcademicAchievementRecord.fromMetrics(
              gpa: 92.5,
              totalAssessmentsTaken: 10,
              totalAssessmentsPassed: 9,
              competenciesMasteredCount: 8,
            ),
          ),
        ],
        shouldVerifyPass: true,
      );
      mockPurge = MockSelectivePurgeService();
    });

    // ── Test 1: Trigger Lock State Before Archive Verification ──────────────
    testWidgets(
      'Test 1: Trigger lock state before archive verification (isResetUnlocked == false, Reset button disabled)',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              adminAnalyticsProvider.overrideWith(() => MockAdminAnalyticsNotifier()),
              subjectsProvider.overrideWith(() => MockSubjectsNotifier()),
              sectionsProvider.overrideWith(() => MockSectionsNotifier()),
              semesterArchivingServiceProvider.overrideWithValue(mockArchiving),
              semesterPurgeServiceProvider.overrideWithValue(mockPurge),
            ],
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const Scaffold(
                body: SingleChildScrollView(child: AdminWebAnalyticsView()),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 1. Verify card is present
        expect(find.byKey(const Key('semester_renewal_card')), findsOneWidget);

        // 2. Verify status badge indicates Archive Pending & Locked
        expect(find.byKey(const Key('archive_status_badge')), findsOneWidget);
        expect(
          find.text('Archive Pending — Reset Trigger Safeguarded & Locked'),
          findsOneWidget,
        );

        // 3. Verify Reset button is locked and disabled
        final resetBtnFinder = find.byKey(const Key('btn_end_of_semester_reset'));
        expect(resetBtnFinder, findsOneWidget);
        expect(find.text('End of Semester Reset (Locked)'), findsOneWidget);

        final elevatedButton = tester.widget<ElevatedButton>(resetBtnFinder);
        expect(elevatedButton.onPressed, isNull,
            reason: 'Reset button MUST be strictly disabled when archive is not verified');
      },
    );

    // ── Test 2: Trigger Unlock After Archive Verification ───────────────────
    testWidgets(
      'Test 2: Trigger unlock after archive verification (isResetUnlocked == true, Reset button enabled)',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              adminAnalyticsProvider.overrideWith(() => MockAdminAnalyticsNotifier()),
              subjectsProvider.overrideWith(() => MockSubjectsNotifier()),
              sectionsProvider.overrideWith(() => MockSectionsNotifier()),
              semesterArchivingServiceProvider.overrideWithValue(mockArchiving),
              semesterPurgeServiceProvider.overrideWithValue(mockPurge),
            ],
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const Scaffold(
                body: SingleChildScrollView(child: AdminWebAnalyticsView()),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 1. Find and tap "Generate & Download Archive" button
        final generateBtnFinder = find.byKey(const Key('btn_generate_archive'));
        expect(generateBtnFinder, findsOneWidget);

        await tester.tap(generateBtnFinder);
        await tester.pumpAndSettle();

        // 2. Verify Status Badge is now Verified & Unlocked
        expect(
          find.text('Archive Verified (1 Students) — Reset Trigger Unlocked'),
          findsOneWidget,
        );

        // 3. Verify Reset Button is now UNLOCKED & ENABLED
        final resetBtnFinder = find.byKey(const Key('btn_end_of_semester_reset'));
        expect(find.text('End of Semester Reset'), findsOneWidget);

        final elevatedButton = tester.widget<ElevatedButton>(resetBtnFinder);
        expect(elevatedButton.onPressed, isNotNull,
            reason: 'Reset button MUST be enabled after archive verification succeeds');
      },
    );

    // ── Test 3: Modal Step 1: Requires Acknowledgement Checkbox ────────────
    testWidgets(
      'Test 3: Modal multi-step flow: Step 1 requires acknowledgement checkbox before Proceed',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              semesterArchivingServiceProvider.overrideWithValue(mockArchiving),
              semesterPurgeServiceProvider.overrideWithValue(mockPurge),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: AcademicTermResetModal(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 1. Step 1 View should be visible
        expect(find.byKey(const Key('step_1_view')), findsOneWidget);
        expect(find.textContaining('Step 1 of 3: Warning & Scope Review'), findsOneWidget);

        // 2. Scope review contents
        expect(find.text('Data to be Permanently Purged:'), findsOneWidget);
        expect(find.text('Data Strictly Preserved Intact:'), findsOneWidget);

        // 3. Proceed button is disabled initially
        final proceedBtnFinder = find.byKey(const Key('step_1_proceed_button'));
        expect(proceedBtnFinder, findsOneWidget);
        var proceedBtn = tester.widget<ElevatedButton>(proceedBtnFinder);
        expect(proceedBtn.onPressed, isNull,
            reason: 'Proceed button must remain disabled until checkbox is checked');

        // 4. Tap acknowledgement checkbox
        final checkboxFinder = find.byKey(const Key('acknowledgement_checkbox'));
        expect(checkboxFinder, findsOneWidget);
        await tester.tap(checkboxFinder);
        await tester.pumpAndSettle();

        // 5. Proceed button is now ENABLED
        proceedBtn = tester.widget<ElevatedButton>(proceedBtnFinder);
        expect(proceedBtn.onPressed, isNotNull,
            reason: 'Proceed button must become enabled after acknowledging impact');

        // 6. Tap Proceed to transition to Step 2
        await tester.tap(proceedBtnFinder);
        await tester.pumpAndSettle();

        // 7. Verify transition to Step 2
        expect(find.byKey(const Key('step_2_view')), findsOneWidget);
        expect(find.textContaining('Step 2 of 3: Admin Re-Authentication'), findsOneWidget);
      },
    );

    // ── Test 4: Modal Step 2: Password Re-Authentication Rejects Invalid ───
    testWidgets(
      'Test 4: Modal Step 2: Password re-authentication rejects invalid password and displays error message without executing purge',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Use custom verifier expecting "SuperSecretAdminPass123"
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              semesterArchivingServiceProvider.overrideWithValue(mockArchiving),
              semesterPurgeServiceProvider.overrideWithValue(mockPurge),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: AcademicTermResetModal(
                  passwordVerifier: (entered) async =>
                      entered == 'SuperSecretAdminPass123',
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Navigate from Step 1 to Step 2
        await tester.tap(find.byKey(const Key('acknowledgement_checkbox')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('step_1_proceed_button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('step_2_view')), findsOneWidget);

        // Enter wrong password
        await tester.enterText(
          find.byKey(const Key('admin_password_field')),
          'WrongPassword999',
        );
        await tester.pumpAndSettle();

        // Tap Verify
        await tester.tap(find.byKey(const Key('step_2_verify_button')));
        await tester.pumpAndSettle();

        // Verify rejection error message is displayed
        expect(find.byKey(const Key('password_error_banner')), findsOneWidget);
        expect(
          find.text('Incorrect administrator password. Re-authentication failed.'),
          findsOneWidget,
        );

        // Verify STILL on Step 2 (Step 3 NOT visible)
        expect(find.byKey(const Key('step_2_view')), findsOneWidget);
        expect(find.byKey(const Key('step_3_view')), findsNothing);

        // Verify purge was NOT called
        expect(mockPurge.purgeCalls, equals(0));
      },
    );

    // ── Test 5: Modal Step 2 & 3: Valid Password Proceeds, Exact Phrase ────
    testWidgets(
      'Test 5: Modal Step 2 & 3: Valid password proceeds to Step 3, exact confirmation phrase required, and clicking confirm triggers purge execution',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Pre-verify the archive in controller provider so reset is unlocked
        final container = ProviderContainer(
          overrides: [
            semesterArchivingServiceProvider.overrideWithValue(mockArchiving),
            semesterPurgeServiceProvider.overrideWithValue(mockPurge),
          ],
        );
        addTearDown(container.dispose);

        // Generate and verify archive first
        await container
            .read(semesterRenewalControllerProvider.notifier)
            .generateAndDownloadArchive();
        expect(container.read(semesterRenewalControllerProvider).isResetUnlocked, isTrue);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: AcademicTermResetModal(
                  adminId: 'admin_audit_user',
                  schoolId: 'sch_main',
                  passwordVerifier: (entered) async => entered == 'ValidPass2026',
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Step 1: Check acknowledgement and proceed
        await tester.tap(find.byKey(const Key('acknowledgement_checkbox')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('step_1_proceed_button')));
        await tester.pumpAndSettle();

        // Step 2: Enter correct password and verify
        await tester.enterText(
          find.byKey(const Key('admin_password_field')),
          'ValidPass2026',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('step_2_verify_button')));
        await tester.pumpAndSettle();

        // Step 3: Confirmation phrase view
        expect(find.byKey(const Key('step_3_view')), findsOneWidget);
        expect(find.textContaining('Step 3 of 3: Confirmation Phrase & Execution'), findsOneWidget);

        // Execute button is disabled initially
        final executeBtnFinder = find.byKey(const Key('execute_reset_button'));
        expect(executeBtnFinder, findsOneWidget);
        var execBtn = tester.widget<ElevatedButton>(executeBtnFinder);
        expect(execBtn.onPressed, isNull,
            reason: 'Execute button must be disabled until exact phrase is typed');

        // Enter incorrect or partial phrase
        await tester.enterText(
          find.byKey(const Key('confirmation_phrase_field')),
          'CONFIRM SEMESTER',
        );
        await tester.pumpAndSettle();
        execBtn = tester.widget<ElevatedButton>(executeBtnFinder);
        expect(execBtn.onPressed, isNull,
            reason: 'Execute button must remain disabled with incomplete phrase');

        // Enter EXACT phrase
        await tester.enterText(
          find.byKey(const Key('confirmation_phrase_field')),
          'CONFIRM SEMESTER RESET',
        );
        await tester.pumpAndSettle();

        execBtn = tester.widget<ElevatedButton>(executeBtnFinder);
        expect(execBtn.onPressed, isNotNull,
            reason: 'Execute button must be enabled when exact phrase matches');

        // Tap Execute Reset
        await tester.tap(executeBtnFinder);
        await tester.pumpAndSettle();

        // Verify purge was called with correct parameters
        expect(mockPurge.purgeCalls, equals(1));
        expect(mockPurge.lastAdminId, equals('admin_audit_user'));
        expect(mockPurge.lastSchoolId, equals('sch_main'));

        // Verify completion view is displayed
        expect(find.byKey(const Key('purge_success_view')), findsOneWidget);
        expect(find.text('Semester Reset Completed'), findsOneWidget);
        expect(find.text('8 subjects, 24 modules'), findsOneWidget);
        expect(find.text('25 accounts intact'), findsOneWidget);
      },
    );

    // ── Test 6: Controller Unit Test: executeReset Throws if Locked ─────────
    test(
      'Test 6: Controller unit test: executeReset throws if isResetUnlocked is false, succeeds after verification',
      () async {
        final container = ProviderContainer(
          overrides: [
            semesterArchivingServiceProvider.overrideWithValue(mockArchiving),
            semesterPurgeServiceProvider.overrideWithValue(mockPurge),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(semesterRenewalControllerProvider.notifier);
        final initialState = container.read(semesterRenewalControllerProvider);

        // 1. Initial State: isResetUnlocked MUST be false
        expect(initialState.isArchiveVerified, isFalse);
        expect(initialState.verificationResult, isNull);
        expect(initialState.isResetUnlocked, isFalse);

        // 2. Calling executeReset before verification MUST throw StateError
        expect(
          () => notifier.executeReset(adminId: 'admin_1', schoolId: 'sch_1'),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('Cannot execute semester reset: Archive generation and verification is required.'),
            ),
          ),
        );
        expect(mockPurge.purgeCalls, equals(0),
            reason: 'Purge service must never be invoked when locked');

        // 3. Generate and verify archive
        final result = await notifier.generateAndDownloadArchive();
        expect(result, isNotNull);
        expect(result!.isValid, isTrue);

        final verifiedState = container.read(semesterRenewalControllerProvider);
        expect(verifiedState.isArchiveVerified, isTrue);
        expect(verifiedState.isResetUnlocked, isTrue);

        // 4. Calling executeReset now MUST succeed
        final summary = await notifier.executeReset(
          adminId: 'admin_authorized',
          schoolId: 'sch_main',
        );

        expect(summary.deletedSubjectsCount, equals(8));
        expect(summary.preservedUsersCount, equals(25));
        expect(mockPurge.purgeCalls, equals(1));
        expect(mockPurge.lastAdminId, equals('admin_authorized'));

        final completedState = container.read(semesterRenewalControllerProvider);
        expect(completedState.isPurging, isFalse);
        expect(completedState.purgeSummary, isNotNull);
        expect(completedState.purgeSummary!.deletedSubjectsCount, equals(8));
      },
    );
  });
}
