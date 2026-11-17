import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:airamp_flutter/src/core/database/database_helper.dart';
import 'package:airamp_flutter/src/features/notifications/domain/notification_filter_service.dart';
import 'package:airamp_flutter/src/features/notifications/application/notification_activity_dispatcher.dart';

void main() {
  late DatabaseHelper dbHelper;
  late NotificationFilterService filterService;
  late NotificationActivityDispatcher dispatcher;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    dbHelper = DatabaseHelper();
    filterService = NotificationFilterService();
    filterService.reset();
    dispatcher = NotificationActivityDispatcher(
      db: dbHelper,
      filterService: filterService,
    );

    // Setup mock enrolled students in subject 901
    final db = await dbHelper.database;
    await db.delete('notifications');
    await db.delete('enrollments', where: 'subject_id = ?', whereArgs: [901]);
    await db.delete('subjects', where: 'id = ?', whereArgs: [901]);

    await db.insert('subjects', {
      'id': 901,
      'subject_code': 'CS301',
      'name': 'Software Engineering',
      'description': 'Advanced SWE principles',
      'teacher_id': 'teacher_smith',
      'created_at': DateTime.now().toIso8601String(),
    });

    await db.insert('enrollments', {
      'student_id': 'student_alice',
      'subject_id': 901,
      'enrolled_at': DateTime.now().toIso8601String(),
    });
    await db.insert('enrollments', {
      'student_id': 'student_bob',
      'subject_id': 901,
      'enrolled_at': DateTime.now().toIso8601String(),
    });
  });

  tearDown(() async {
    filterService.reset();
  });

  group('NotificationActivityDispatcher Role Routing & Deduplication', () {
    test('notifyNewAssignment dispatches to all enrolled students and deduplicates repeat triggers', () async {
      final notifIds = await dispatcher.notifyNewAssignment(
        assignmentId: 'assign_sprint_1',
        subjectId: 901,
        title: 'Sprint 1 User Stories',
        teacherId: 'teacher_smith',
        teacherName: 'Prof. Smith',
        dueDate: '2026-12-01T23:59:59Z',
      );

      expect(notifIds.length, 2, reason: 'Must notify both enrolled students Alice and Bob');

      final aliceNotifs = await dbHelper.getNotificationsForUser('student_alice');
      expect(aliceNotifs.length, 1);
      expect(aliceNotifs.first['type'], 'new_assignment');
      expect(aliceNotifs.first['title'], contains('Sprint 1 User Stories'));
      expect(aliceNotifs.first['message'], contains('Prof. Smith'));
      expect(aliceNotifs.first['target_route'], '/student/home');

      final bobNotifs = await dbHelper.getNotificationsForUser('student_bob');
      expect(bobNotifs.length, 1);

      // Immediate second call with identical parameters must be deduplicated
      final dupIds = await dispatcher.notifyNewAssignment(
        assignmentId: 'assign_sprint_1',
        subjectId: 901,
        title: 'Sprint 1 User Stories',
        teacherId: 'teacher_smith',
        teacherName: 'Prof. Smith',
        dueDate: '2026-12-01T23:59:59Z',
      );
      expect(dupIds.isEmpty, isTrue, reason: 'Duplicate assignment dispatches must be suppressed by filter engine');

      final aliceNotifsAfter = await dbHelper.getNotificationsForUser('student_alice');
      expect(aliceNotifsAfter.length, 1, reason: 'No new duplicate notification added');
    });

    test('notifyActivitySubmitted alerts teacher with student details', () async {
      final notifId = await dispatcher.notifyActivitySubmitted(
        assignmentId: 'assign_sprint_1',
        subjectId: 901,
        title: 'Sprint 1 User Stories',
        studentId: 'student_alice',
        studentName: 'Alice Green',
        teacherId: 'teacher_smith',
        isLate: false,
      );

      expect(notifId, isNotNull);

      final teacherNotifs = await dbHelper.getNotificationsForUser('teacher_smith');
      expect(teacherNotifs.length, 1);
      expect(teacherNotifs.first['type'], 'activity_submission');
      expect(teacherNotifs.first['message'], contains('Alice Green submitted'));
      expect(teacherNotifs.first['target_route'], '/teacher/dashboard');
    });

    test('notifyGradeReleased alerts student with score and teacher feedback', () async {
      final notifId = await dispatcher.notifyGradeReleased(
        assignmentId: 'assign_sprint_1',
        subjectId: 901,
        title: 'Sprint 1 User Stories',
        studentId: 'student_alice',
        grade: 95,
        totalPoints: 100,
        feedback: 'Excellent work on the acceptance criteria!',
        teacherId: 'teacher_smith',
        teacherName: 'Prof. Smith',
      );

      expect(notifId, isNotNull);

      final studentNotifs = await dbHelper.getNotificationsForUser('student_alice');
      expect(studentNotifs.length, 1);
      expect(studentNotifs.first['type'], 'grade_released');
      expect(studentNotifs.first['message'], contains('95/100'));
      expect(studentNotifs.first['message'], contains('acceptance criteria'));
      expect(studentNotifs.first['target_route'], '/student/history');
    });

    test('notifyResubmissionUnlocked alerts student that resubmission was allowed', () async {
      final notifId = await dispatcher.notifyResubmissionUnlocked(
        assignmentId: 'assign_sprint_1',
        subjectId: 901,
        title: 'Sprint 1 User Stories',
        studentId: 'student_bob',
        teacherId: 'teacher_smith',
        teacherName: 'Prof. Smith',
      );

      expect(notifId, isNotNull);

      final studentNotifs = await dbHelper.getNotificationsForUser('student_bob');
      expect(studentNotifs.length, 1);
      expect(studentNotifs.first['type'], 'resubmission_allowed');
      expect(studentNotifs.first['title'], contains('Resubmission Allowed'));
      expect(studentNotifs.first['target_route'], '/student/history');
    });

    test('notifyQuizAssigned alerts all assigned students', () async {
      final notifIds = await dispatcher.notifyQuizAssigned(
        quizId: 'quiz_midterm',
        subjectId: 901,
        title: 'Midterm SWE Exam',
        teacherId: 'teacher_smith',
        teacherName: 'Prof. Smith',
        studentIds: ['student_alice', 'student_bob'],
      );

      expect(notifIds.length, 2);

      final aliceNotifs = await dbHelper.getNotificationsForUser('student_alice');
      expect(aliceNotifs.first['type'], 'quiz_assigned');
      expect(aliceNotifs.first['title'], contains('Midterm SWE Exam'));
    });

    test('notifyQuizAttemptCompleted alerts student and teacher', () async {
      await dispatcher.notifyQuizAttemptCompleted(
        quizId: 'quiz_midterm',
        subjectId: 901,
        title: 'Midterm SWE Exam',
        studentId: 'student_alice',
        studentName: 'Alice Green',
        score: 18,
        totalQuestions: 20,
        teacherId: 'teacher_smith',
      );

      final aliceNotifs = await dbHelper.getNotificationsForUser('student_alice');
      expect(aliceNotifs.any((n) => n['type'] == 'quiz'), isTrue);

      final teacherNotifs = await dbHelper.getNotificationsForUser('teacher_smith');
      expect(teacherNotifs.any((n) => n['type'] == 'quiz_completed'), isTrue);
      expect(teacherNotifs.first['message'], contains('Alice Green completed "Midterm SWE Exam"'));
    });

    test('notifyAnnouncementPublished alerts target recipients', () async {
      final notifIds = await dispatcher.notifyAnnouncementPublished(
        announcementId: 'ann_holiday',
        title: 'University Holiday Schedule',
        message: 'Classes suspended on Friday.',
        authorId: 'admin_01',
        authorName: 'Registrar Office',
        targetUserIds: ['student_alice', 'student_bob'],
      );

      expect(notifIds.length, 2);

      final bobNotifs = await dbHelper.getNotificationsForUser('student_bob');
      expect(bobNotifs.any((n) => n['type'] == 'announcement'), isTrue);
      expect(bobNotifs.first['title'], contains('University Holiday Schedule'));
    });
  });
}
