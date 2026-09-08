import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:airamp_flutter/src/core/database/database_helper.dart';
import 'package:airamp_flutter/src/features/auth/data/auth_repository.dart';

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final db = await DatabaseHelper().database;
    await db.delete('users', where: "email = ?", whereArgs: ['alex.sapphire@school.edu']);
    await db.delete('reg_links', where: "code = ?", whereArgs: ['TEST-KEY-SAPPHIRE']);
    await db.delete('sections', where: "name = ?", whereArgs: ['Sapphire']);
  });

  group('Tri-Role Connection & Academic Lifecycle End-to-End Test', () {
    final dbHelper = DatabaseHelper();
    final authRepo = AuthRepository();

    test('1. Admin exact student counts and section setup', () async {
      final db = await dbHelper.database;

      // 1. Check exact counts query
      final countsBefore = await dbHelper.getExactStudentCounts();
      expect(countsBefore['total'], isNotNull);
      expect(countsBefore['total'], greaterThanOrEqualTo(1)); // at least seeded student_1
      final initialTotal = countsBefore['total'] as int;

      // 2. Admin creates a new section and enrollment registration key
      await db.insert('sections', {
        'name': 'Sapphire',
        'description': 'Grade 10 Sapphire Section',
        'grade': 'Grade 10',
        'room': 'Room 401',
        'student_count': 0,
        'created_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      const testKey = 'TEST-KEY-SAPPHIRE';
      await dbHelper.generateEnrollmentKey(
        code: testKey,
        section: 'Sapphire',
        maxUses: 10,
      );

      final keys = await dbHelper.getEnrollmentKeysList();
      expect(keys.any((k) => k['code'] == testKey), isTrue);

      // 3. Student registers using the enrollment key
      final studentRes = await authRepo.register(
        fullName: 'Alex Sapphire Student',
        email: 'alex.sapphire@school.edu',
        password: 'Password@123',
        role: 'student',
        sectionCode: testKey,
      );

      final newStudent = studentRes['user'];
      expect(newStudent['id'], isNotNull);
      expect(newStudent['section'], 'Sapphire');

      // 4. Verify Admin exact count incremented
      final countsAfter = await dbHelper.getExactStudentCounts();
      expect(countsAfter['total'], initialTotal + 1);
      final sectionCounts = countsAfter['sectionCounts'] as Map<String, int>;
      expect(sectionCounts['Sapphire'], greaterThanOrEqualTo(1));

      // 5. Verify registration key used_count incremented
      final updatedKeys = await dbHelper.getEnrollmentKeysList();
      final sapphireKey = updatedKeys.firstWhere((k) => k['code'] == testKey);
      expect(sapphireKey['used_count'], 1);

      // 6. Verify section student_count incremented
      final sectionRow = await db.query('sections', where: 'name = ?', whereArgs: ['Sapphire']);
      expect(sectionRow.first['student_count'], 1);
    });

    test('2. Student auto-enrolled in subjects and visible in Teacher roster', () async {
      const teacherId = 'teacher_1';
      final studentId = 'student_test_tri_2';

      final db = await dbHelper.database;
      // Insert student in Emerald section
      await db.insert('users', {
        'id': studentId,
        'email': 'tri.emerald@test.com',
        'password': 'Password123',
        'role': 'student',
        'full_name': 'Emerald Tri Student',
        'section': 'Emerald',
        'grade': 'Grade 10',
        'created_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // Auto-enroll student into Grade 10 subjects
      await dbHelper.autoEnrollStudentBySection(studentId, 'Emerald', 'Grade 10');

      // Check student enrolled subjects
      final enrolled = await dbHelper.getEnrolledSubjects(studentId);
      expect(enrolled.isNotEmpty, isTrue);

      // Check Teacher's roster includes this student
      final teacherStudents = await dbHelper.getStudentsForTeacher(teacherId);
      expect(teacherStudents.any((s) => s['id'] == studentId), isTrue);

      final studentInRoster = teacherStudents.firstWhere((s) => s['id'] == studentId);
      expect(studentInRoster['completed_los'], 0);
      expect(studentInRoster['enrolled_subjects'], greaterThanOrEqualTo(1));
    });

    test('3. Dynamic Quiz taking and real-time score propagation across Teacher and Admin', () async {
      const teacherId = 'teacher_1';
      const studentId = 'student_test_tri_3';

      final db = await dbHelper.database;
      // Insert student and enroll in teacher's subject
      await db.insert('users', {
        'id': studentId,
        'email': 'tri.quiz@test.com',
        'password': 'Password123',
        'role': 'student',
        'full_name': 'Quiz Runner Student',
        'section': 'Emerald',
        'grade': 'Grade 10',
        'created_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      final teacherSubjects = await dbHelper.getSubjectsForTeacher(teacherId);
      expect(teacherSubjects.isNotEmpty, isTrue);
      final subjectId = teacherSubjects.first['id'] as int;

      await dbHelper.enrollSubject(studentId, subjectId);

      // Find an LO with a quiz
      final topics = await db.query('topics', where: 'subject_id = ?', whereArgs: [subjectId]);
      expect(topics.isNotEmpty, isTrue);
      final los = await db.query('learning_outcomes', where: 'topic_id = ?', whereArgs: [topics.first['id'] as int]);
      expect(los.isNotEmpty, isTrue);
      final loId = los.first['id'] as int;

      final loQuiz = await dbHelper.getLoQuiz(loId);
      expect(loQuiz, isNotNull);
      final questions = (loQuiz!['questions'] as List).cast<Map<String, dynamic>>();
      final totalQ = questions.isNotEmpty ? questions.length : 5;

      // Student records quiz attempt (100% score, passed)
      await dbHelper.recordQuizAttempt(
        studentId: studentId,
        loId: loId,
        subjectId: subjectId,
        score: totalQ,
        totalQuestions: totalQ,
        percentage: 100.0,
        isPassed: true,
        durationSeconds: 95,
      );

      // A. Verify Student Progress
      final progress = await dbHelper.getStudentProgressSummary(studentId);
      expect(progress['passedAttempts'], greaterThanOrEqualTo(1));
      expect(progress['completed'], greaterThanOrEqualTo(1));

      // B. Verify Teacher Live Dashboard Stats
      final teacherStats = await dbHelper.getTeacherDashboardStats(teacherId);
      expect(teacherStats['totalAttempts'], greaterThanOrEqualTo(1));
      expect(teacherStats['passedAttempts'], greaterThanOrEqualTo(1));
      expect(teacherStats['passRate'], greaterThan(0));

      final recentAttempts = teacherStats['recentAttempts'] as List<dynamic>;
      expect(recentAttempts.any((a) => a['student_id'] == studentId), isTrue);

      // C. Verify Teacher Student Roster shows completed LO
      final roster = await dbHelper.getStudentsForTeacher(teacherId);
      final studentRosterEntry = roster.firstWhere((s) => s['id'] == studentId);
      expect(studentRosterEntry['completed_los'], greaterThanOrEqualTo(1));

      // D. Verify Teacher Score View
      final allScores = await dbHelper.getAllQuizScores();
      expect(allScores.any((s) => s['student_id'] == studentId), isTrue);

      // E. Verify Admin Analytics Rollup
      final adminAnalytics = await dbHelper.getAdminAnalyticsSummary();
      expect(adminAnalytics['totalAttempts'], greaterThanOrEqualTo(1));
      expect(adminAnalytics['passedAttempts'], greaterThanOrEqualTo(1));
    });
  });
}
