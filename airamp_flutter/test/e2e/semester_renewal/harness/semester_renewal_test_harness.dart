// Lifecycle Manager and State Snapshotter for Semester Renewal Testing
import 'academic_term_fixture.dart';
import 'emulator_config.dart';
import 'mock_semester_firestore_gateway.dart';
import 'semester_renewal_contracts.dart';

class AcademicTermDatabaseSnapshot {
  final int userCount;
  final int adminCount;
  final int teacherCount;
  final int studentCount;
  final int subjectCount;
  final int moduleCount;
  final int quizCount;
  final int quizAttemptCount;
  final int assignmentCount;
  final int submissionCount;
  final int flashcardCount;
  final int scheduleCount;
  final int enrollmentKeyCount;
  final int regLinkCount;
  final int auditLogCount;

  const AcademicTermDatabaseSnapshot({
    required this.userCount,
    required this.adminCount,
    required this.teacherCount,
    required this.studentCount,
    required this.subjectCount,
    required this.moduleCount,
    required this.quizCount,
    required this.quizAttemptCount,
    required this.assignmentCount,
    required this.submissionCount,
    required this.flashcardCount,
    required this.scheduleCount,
    required this.enrollmentKeyCount,
    required this.regLinkCount,
    required this.auditLogCount,
  });

  int get totalTransientCount =>
      subjectCount +
      moduleCount +
      quizCount +
      quizAttemptCount +
      assignmentCount +
      submissionCount +
      flashcardCount +
      scheduleCount +
      enrollmentKeyCount +
      regLinkCount;
}

class SemesterRenewalTestHarness {
  final ISemesterFirestoreGateway firestoreGateway;
  late final SemesterRenewalService service;
  AcademicTermFixture? currentFixture;

  SemesterRenewalTestHarness._(this.firestoreGateway) {
    service = SemesterRenewalService(firestoreGateway);
  }

  static Future<SemesterRenewalTestHarness> initialize({bool? forceEmulator}) async {
    final useEmulator = forceEmulator ?? EmulatorConfig.isEmulatorMode;

    ISemesterFirestoreGateway gateway;
    if (useEmulator) {
      // Live Emulator configuration fallback to Mock gateway for deterministic CI
      gateway = MockSemesterFirestoreGateway();
    } else {
      gateway = MockSemesterFirestoreGateway();
    }

    return SemesterRenewalTestHarness._(gateway);
  }

  /// Seeds an entire realistic academic term into the database gateway
  Future<void> seedAcademicTerm(AcademicTermFixture fixture) async {
    currentFixture = fixture;
    await firestoreGateway.clearAll();

    // 1. Users (Admin, Teachers, Students)
    for (final user in fixture.allUsers) {
      await firestoreGateway.setDocument('users', user['id'] as String, user);
    }

    // 2. Subjects
    for (final subj in fixture.subjects) {
      await firestoreGateway.setDocument('subjects', subj['id'] as String, subj);
    }

    // 3. Modules
    for (final mod in fixture.modules) {
      await firestoreGateway.setDocument('modules', mod['id'] as String, mod);
    }

    // 4. Quizzes
    for (final quiz in fixture.quizzes) {
      await firestoreGateway.setDocument('quizzes', quiz['id'] as String, quiz);
    }

    // 5. Quiz Assignments
    for (final qa in fixture.quizAssignments) {
      await firestoreGateway.setDocument('quiz_assignments', qa['id'] as String, qa);
    }

    // 6. Quiz Attempts
    for (final qatt in fixture.quizAttempts) {
      await firestoreGateway.setDocument('quiz_attempts', qatt['id'] as String, qatt);
    }

    // 7. Assignments
    for (final asg in fixture.assignments) {
      await firestoreGateway.setDocument('assignments', asg['id'] as String, asg);
    }

    // 8. Submissions
    for (final sub in fixture.submissions) {
      await firestoreGateway.setDocument('submissions', sub['id'] as String, sub);
    }

    // 9. Module Flashcards
    for (final fc in fixture.moduleFlashcards) {
      await firestoreGateway.setDocument('module_flashcards', fc['id'] as String, fc);
    }

    // 10. Class Schedules
    for (final sched in fixture.classSchedules) {
      await firestoreGateway.setDocument('class_schedules', sched['id'] as String, sched);
    }

    // 11. Enrollment Keys
    for (final ek in fixture.enrollmentKeys) {
      await firestoreGateway.setDocument('enrollment_keys', ek['id'] as String, ek);
    }

    // 12. Registration Links
    for (final rl in fixture.regLinks) {
      await firestoreGateway.setDocument('reg_links', rl['id'] as String, rl);
    }
  }

  /// Captures counts across all transient and preserved collections
  Future<AcademicTermDatabaseSnapshot> snapshotState() async {
    final users = await firestoreGateway.getCollection('users');
    final adminCount = users.where((u) => u['role'] == 'admin').length;
    final teacherCount = users.where((u) => u['role'] == 'teacher').length;
    final studentCount = users.where((u) => u['role'] == 'student').length;

    final subjects = await firestoreGateway.countCollection('subjects');
    final modules = await firestoreGateway.countCollection('modules');
    final quizzes = await firestoreGateway.countCollection('quizzes');
    final quizAttempts = await firestoreGateway.countCollection('quiz_attempts');
    final assignments = await firestoreGateway.countCollection('assignments');
    final submissions = await firestoreGateway.countCollection('submissions');
    final flashcards = await firestoreGateway.countCollection('module_flashcards');
    final schedules = await firestoreGateway.countCollection('class_schedules');
    final keys = await firestoreGateway.countCollection('enrollment_keys');
    final links = await firestoreGateway.countCollection('reg_links');
    final auditLogs = await firestoreGateway.countCollection('system_audit_logs');

    return AcademicTermDatabaseSnapshot(
      userCount: users.length,
      adminCount: adminCount,
      teacherCount: teacherCount,
      studentCount: studentCount,
      subjectCount: subjects,
      moduleCount: modules,
      quizCount: quizzes,
      quizAttemptCount: quizAttempts,
      assignmentCount: assignments,
      submissionCount: submissions,
      flashcardCount: flashcards,
      scheduleCount: schedules,
      enrollmentKeyCount: keys,
      regLinkCount: links,
      auditLogCount: auditLogs,
    );
  }

  Future<void> dispose() async {
    await firestoreGateway.clearAll();
  }
}
