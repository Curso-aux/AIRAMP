import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:airamp_flutter/src/core/database/database_helper.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('Database v14 schema has student and teacher tables', () async {
    final helper = DatabaseHelper();
    final db = await helper.database;

    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('enrollments', 'student_progress', 'quiz_attempts')",
    );

    final tableNames = tables.map((t) => t['name'] as String).toSet();
    expect(tableNames.contains('enrollments'), isTrue);
    expect(tableNames.contains('student_progress'), isTrue);
    expect(tableNames.contains('quiz_attempts'), isTrue);
  });

  test('Database v14 has seeded subjects, topics, LOs, and questions', () async {
    final helper = DatabaseHelper();
    final db = await helper.database;

    final subjects = await db.query('subjects');
    expect(subjects.isNotEmpty, isTrue);

    final cs101 = subjects.firstWhere((s) => s['subject_code'] == 'CS101', orElse: () => {});
    expect(cs101.isNotEmpty, isTrue);

    final questions = await db.query('questions');
    expect(questions.isNotEmpty, isTrue);
  });

  test('Student enrollment, quiz attempt recording, and teacher score query flow', () async {
    final helper = DatabaseHelper();
    final db = await helper.database;
    const testStudentId = 'test_student_flow_1';

    // Insert student user so JOIN users works
    await db.insert(
      'users',
      {
        'id': testStudentId,
        'email': 'flow_student@test.com',
        'password': 'Password123',
        'role': 'student',
        'full_name': 'Flow Test Student',
        'section': 'STEM B',
        'grade': 'Grade 11',
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // 1. Check available subjects
    final available = await helper.getAvailableSubjects(testStudentId);
    expect(available.isNotEmpty, isTrue);
    final subjectId = available.first['id'] as int;

    // 2. Enroll
    await helper.enrollSubject(testStudentId, subjectId);
    final enrolled = await helper.getEnrolledSubjects(testStudentId);
    expect(enrolled.any((s) => s['id'] == subjectId), isTrue);

    // 3. Check LO quiz
    final topics = await db.query('topics', where: 'subject_id = ?', whereArgs: [subjectId]);
    expect(topics.isNotEmpty, isTrue);
    final los = await db.query('learning_outcomes', where: 'topic_id = ?', whereArgs: [topics.first['id'] as int]);
    expect(los.isNotEmpty, isTrue);
    final loId = los.first['id'] as int;

    final loQuiz = await helper.getLoQuiz(loId);
    expect(loQuiz, isNotNull);
    final questions = loQuiz!['questions'] as List<dynamic>;
    expect(questions.isNotEmpty, isTrue);

    // 4. Record Quiz Attempt
    await helper.recordQuizAttempt(
      studentId: testStudentId,
      loId: loId,
      subjectId: subjectId,
      score: questions.length,
      totalQuestions: questions.length,
      percentage: 100.0,
      isPassed: true,
      durationSeconds: 120,
    );

    // 5. Verify Student Progress Summary
    final progress = await helper.getStudentProgressSummary(testStudentId);
    expect(progress['totalAttempts'], greaterThanOrEqualTo(1));
    expect(progress['passedAttempts'], greaterThanOrEqualTo(1));

    // 6. Verify Student Quiz Attempts
    final attempts = await helper.getStudentQuizAttempts(testStudentId);
    expect(attempts.any((a) => a['lo_id'] == loId && a['student_id'] == testStudentId), isTrue);

    // 7. Verify Teacher Scores Query
    final teacherScores = await helper.getAllQuizScores();
    expect(teacherScores.any((s) => s['student_id'] == testStudentId), isTrue);

    // 8. Unenroll
    await helper.unenrollSubject(testStudentId, subjectId);
    final enrolledAfter = await helper.getEnrolledSubjects(testStudentId);
    expect(enrolledAfter.any((s) => s['id'] == subjectId), isFalse);
  });
}
