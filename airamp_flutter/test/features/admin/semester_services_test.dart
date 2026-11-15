// ignore_for_file: subtype_of_sealed_class
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart' show Sqflite;
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'package:airamp_flutter/src/core/database/firestore_service.dart';
import 'package:airamp_flutter/src/features/admin/domain/semester_archive_models.dart';
import 'package:airamp_flutter/src/features/admin/data/semester_record_archiving_service.dart';
import 'package:airamp_flutter/src/features/admin/data/semester_selective_purge_service.dart';

/// Test double simulating Firestore WriteBatch without invoking native SDK bindings.
class TestWriteBatch implements WriteBatch {
  int commitCalls = 0;
  int operationsInCurrentBatch = 0;
  final void Function(int opsCount)? onCommit;

  TestWriteBatch({this.onCommit});

  @override
  Future<void> commit() async {
    commitCalls++;
    onCommit?.call(operationsInCurrentBatch);
    operationsInCurrentBatch = 0;
  }

  @override
  void delete(DocumentReference document) {
    operationsInCurrentBatch++;
  }

  @override
  void set<T>(DocumentReference<T> document, T data, [SetOptions? options]) {
    operationsInCurrentBatch++;
  }

  @override
  void update<T>(DocumentReference<T> document, T data) {
    operationsInCurrentBatch++;
  }
}

/// Test double simulating DocumentReference without network dependencies.
class TestDocumentReference implements DocumentReference {
  final String _path;
  TestDocumentReference([this._path = 'collection/doc']);

  @override
  String get id => _path.split('/').last;

  @override
  String get path => _path;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
  });

  group('Domain Models & Honors Classification Rules', () {
    test('AcademicAchievementRecord computes correct DepEd honors classifications', () {
      expect(AcademicAchievementRecord.computeHonorsTitle(98.5), 'With Highest Honors');
      expect(AcademicAchievementRecord.computeHonorsTitle(98.0), 'With Highest Honors');
      expect(AcademicAchievementRecord.computeHonorsTitle(97.9), 'With High Honors');
      expect(AcademicAchievementRecord.computeHonorsTitle(95.0), 'With High Honors');
      expect(AcademicAchievementRecord.computeHonorsTitle(94.9), 'With Honors');
      expect(AcademicAchievementRecord.computeHonorsTitle(90.0), 'With Honors');
      expect(AcademicAchievementRecord.computeHonorsTitle(89.9), 'Passed');
      expect(AcademicAchievementRecord.computeHonorsTitle(75.0), 'Passed');
      expect(AcademicAchievementRecord.computeHonorsTitle(74.9), 'Did Not Meet Expectations');
      expect(AcademicAchievementRecord.computeHonorsTitle(65.0), 'Did Not Meet Expectations');
      expect(AcademicAchievementRecord.computeHonorsTitle(0.0), 'Did Not Meet Expectations');
    });

    test('AcademicAchievementRecord serialization and metrics initialization', () {
      final record = AcademicAchievementRecord.fromMetrics(
        gpa: 96.25,
        totalAssessmentsTaken: 12,
        totalAssessmentsPassed: 11,
        competenciesMasteredCount: 8,
      );

      expect(record.gpa, 96.25);
      expect(record.honorsTitle, 'With High Honors');
      expect(record.totalAssessmentsTaken, 12);
      expect(record.totalAssessmentsPassed, 11);
      expect(record.competenciesMasteredCount, 8);

      final map = record.toMap();
      final reconstituted = AcademicAchievementRecord.fromMap(map);

      expect(reconstituted.gpa, 96.25);
      expect(reconstituted.honorsTitle, 'With High Honors');
      expect(reconstituted.totalAssessmentsTaken, 12);
      expect(reconstituted.totalAssessmentsPassed, 11);
      expect(reconstituted.competenciesMasteredCount, 8);
    });

    test('SubjectGradeRecord averages and serialization', () {
      const grade = SubjectGradeRecord(
        subjectId: 'sub_101',
        subjectName: 'Advanced Computer Programming',
        subjectCode: 'CS-301',
        teacherName: 'Prof. Alan Turing',
        quizScores: [90.0, 95.0, 85.0], // avg 90.0
        assignmentGrades: [100.0, 90.0], // avg 95.0
        averageScore: 92.5,
        isPassed: true,
      );

      expect(grade.quizAverage, 90.0);
      expect(grade.assignmentAverage, 95.0);
      expect(grade.averageScore, 92.5);
      expect(grade.isPassed, isTrue);

      final map = grade.toMap();
      final reconstituted = SubjectGradeRecord.fromMap(map);

      expect(reconstituted.subjectId, 'sub_101');
      expect(reconstituted.subjectCode, 'CS-301');
      expect(reconstituted.quizScores.length, 3);
      expect(reconstituted.assignmentGrades.length, 2);
      expect(reconstituted.averageScore, 92.5);
      expect(reconstituted.isPassed, isTrue);
    });

    test('StudentArchiveRecord full transcript serialization', () {
      final student = StudentArchiveRecord(
        studentId: 'S-100-0042',
        fullName: 'Juan Dela Cruz',
        section: 'St. Peter',
        gradeLevel: 'Grade 11',
        studentType: 'regular',
        specialNotes: 'Honor student candidate',
        grades: const [
          SubjectGradeRecord(
            subjectId: '1',
            subjectName: 'Mathematics',
            subjectCode: 'MATH-11',
            teacherName: 'Ms. Smith',
            quizScores: [95.0],
            assignmentGrades: [98.0],
            averageScore: 96.5,
            isPassed: true,
          ),
        ],
        achievements: AcademicAchievementRecord.fromMetrics(
          gpa: 96.5,
          totalAssessmentsTaken: 2,
          totalAssessmentsPassed: 2,
          competenciesMasteredCount: 3,
        ),
      );

      final map = student.toMap();
      final reconstituted = StudentArchiveRecord.fromMap(map);

      expect(reconstituted.studentId, 'S-100-0042');
      expect(reconstituted.fullName, 'Juan Dela Cruz');
      expect(reconstituted.section, 'St. Peter');
      expect(reconstituted.grades.length, 1);
      expect(reconstituted.achievements.honorsTitle, 'With High Honors');
    });

    test('PurgeSummary metrics calculation and serialization', () {
      final executed = DateTime.utc(2026, 11, 15, 12, 0, 0);
      final summary = PurgeSummary(
        deletedSubjectsCount: 15,
        deletedModulesCount: 45,
        deletedQuizzesCount: 30,
        deletedAttemptsCount: 250,
        deletedAssignmentsCount: 20,
        deletedSubmissionsCount: 180,
        preservedUsersCount: 120,
        executedAt: executed,
        deletedFlashcardsCount: 10,
        deletedSchedulesCount: 8,
        deletedEnrollmentKeysCount: 5,
        resetStudentEnrollmentsCount: 85,
      );

      expect(summary.totalDeletedAcademicRecords, 15 + 45 + 30 + 250 + 20 + 180 + 10 + 8 + 5);
      expect(summary.preservedUsersCount, 120);

      final map = summary.toMap();
      final reconstituted = PurgeSummary.fromMap(map);

      expect(reconstituted.deletedSubjectsCount, 15);
      expect(reconstituted.deletedModulesCount, 45);
      expect(reconstituted.deletedQuizzesCount, 30);
      expect(reconstituted.deletedAttemptsCount, 250);
      expect(reconstituted.deletedAssignmentsCount, 20);
      expect(reconstituted.deletedSubmissionsCount, 180);
      expect(reconstituted.preservedUsersCount, 120);
      expect(reconstituted.executedAt.toIso8601String(), executed.toIso8601String());
    });
  });

  group('PDF Archiving & Integrity Verification Service', () {
    late SemesterRecordArchivingService archivingService;

    setUp(() {
      archivingService = SemesterRecordArchivingService();
    });

    test('generatePdfArchive compiles valid PDF bytes with headers, transcript table and metadata', () async {
      final records = [
        StudentArchiveRecord(
          studentId: 'S-100-0001',
          fullName: 'Alice Walker',
          section: 'Grade 11 - Einstein',
          gradeLevel: 'Grade 11',
          grades: const [
            SubjectGradeRecord(
              subjectId: 'sub_1',
              subjectName: 'General Physics 1',
              subjectCode: 'PHYS-101',
              teacherName: 'Dr. Bohr',
              quizScores: [92.0, 96.0],
              assignmentGrades: [95.0],
              averageScore: 94.5,
              isPassed: true,
            ),
            SubjectGradeRecord(
              subjectId: 'sub_2',
              subjectName: 'Calculus',
              subjectCode: 'CALC-101',
              teacherName: 'Prof. Newton',
              quizScores: [98.0, 100.0],
              assignmentGrades: [99.0],
              averageScore: 99.0,
              isPassed: true,
            ),
          ],
          achievements: AcademicAchievementRecord.fromMetrics(
            gpa: 96.75,
            totalAssessmentsTaken: 5,
            totalAssessmentsPassed: 5,
            competenciesMasteredCount: 6,
          ),
        ),
        StudentArchiveRecord(
          studentId: 'S-100-0002',
          fullName: 'Bob Martinez',
          section: 'Grade 12 - Tesla',
          gradeLevel: 'Grade 12',
          grades: const [
            SubjectGradeRecord(
              subjectId: 'sub_3',
              subjectName: 'Oral Communication',
              subjectCode: 'COMM-101',
              teacherName: 'Ms. Dickinson',
              quizScores: [82.0, 84.0],
              assignmentGrades: [80.0],
              averageScore: 81.5,
              isPassed: true,
            ),
          ],
          achievements: AcademicAchievementRecord.fromMetrics(
            gpa: 81.5,
            totalAssessmentsTaken: 3,
            totalAssessmentsPassed: 3,
            competenciesMasteredCount: 4,
          ),
        ),
        StudentArchiveRecord(
          studentId: 'S-100-0003',
          fullName: 'Charlie Davis',
          section: 'Grade 11 - Curie',
          gradeLevel: 'Grade 11',
          grades: const [],
          achievements: AcademicAchievementRecord.fromMetrics(
            gpa: 0.0,
            totalAssessmentsTaken: 0,
            totalAssessmentsPassed: 0,
            competenciesMasteredCount: 0,
          ),
        ),
      ];

      final pdfBytes = await archivingService.generatePdfArchive(records);

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(1024), reason: 'PDF must exceed 1KB');

      // Magic bytes check (%PDF-)
      final magic = String.fromCharCodes(pdfBytes.sublist(0, 5));
      expect(magic, '%PDF-');

      // Verify parseable using Syncfusion
      final doc = PdfDocument(inputBytes: pdfBytes);
      expect(doc.pages.count, greaterThanOrEqualTo(3));
      doc.dispose();
    });

    test('generatePdfArchive produces valid institutional document on empty student roster', () async {
      final pdfBytes = await archivingService.generatePdfArchive([]);
      expect(pdfBytes.length, greaterThan(1024));

      final magic = String.fromCharCodes(pdfBytes.sublist(0, 5));
      expect(magic, '%PDF-');

      final doc = PdfDocument(inputBytes: pdfBytes);
      expect(doc.pages.count, 1);
      doc.dispose();
    });

    test('verifyPdfArchive successfully validates genuine archive', () async {
      final records = [
        StudentArchiveRecord(
          studentId: 'S-100-0001',
          fullName: 'Jane Doe',
          section: 'A',
          gradeLevel: '11',
          grades: const [],
          achievements: AcademicAchievementRecord.fromMetrics(
            gpa: 88.0,
            totalAssessmentsTaken: 1,
            totalAssessmentsPassed: 1,
            competenciesMasteredCount: 1,
          ),
        ),
        StudentArchiveRecord(
          studentId: 'S-100-0002',
          fullName: 'John Smith',
          section: 'B',
          gradeLevel: '12',
          grades: const [],
          achievements: AcademicAchievementRecord.fromMetrics(
            gpa: 91.0,
            totalAssessmentsTaken: 2,
            totalAssessmentsPassed: 2,
            competenciesMasteredCount: 2,
          ),
        ),
      ];

      final pdfBytes = await archivingService.generatePdfArchive(records);
      final result = archivingService.verifyPdfArchive(pdfBytes, 2);

      expect(result.isValid, isTrue);
      expect(result.studentCount, 2);
      expect(result.byteLength, pdfBytes.length);
      expect(result.checksum, sha256.convert(pdfBytes).toString());
      expect(result.errorMessage, isNull);
    });

    test('verifyPdfArchive fails on corrupted or short byte buffer', () {
      final shortBytes = Uint8List.fromList([1, 2, 3]);
      final result = archivingService.verifyPdfArchive(shortBytes, 1);

      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('too short'));
    });

    test('verifyPdfArchive fails on missing %PDF- magic bytes header', () {
      final nonPdfBytes = Uint8List.fromList(List.filled(2048, 65)); // 2KB of 'A'
      final result = archivingService.verifyPdfArchive(nonPdfBytes, 1);

      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('Invalid PDF magic bytes'));
    });

    test('verifyPdfArchive fails when buffer is <= 1024 bytes', () {
      final header = '%PDF-'.codeUnits;
      final smallBuffer = Uint8List.fromList([...header, ...List.filled(500, 32)]);
      final result = archivingService.verifyPdfArchive(smallBuffer, 1);

      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('size too small'));
    });

    test('verifyPdfArchive fails on negative expected student count', () async {
      final pdfBytes = await archivingService.generatePdfArchive([]);
      final result = archivingService.verifyPdfArchive(pdfBytes, -1);

      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('Invalid expected student count'));
    });

    test('verifyPdfArchive fails on student count mismatch', () async {
      final records = [
        StudentArchiveRecord(
          studentId: 'S-100-0001',
          fullName: 'Student 1',
          section: 'Section 1',
          gradeLevel: '10',
          grades: const [],
          achievements: AcademicAchievementRecord.fromMetrics(
            gpa: 85.0,
            totalAssessmentsTaken: 1,
            totalAssessmentsPassed: 1,
            competenciesMasteredCount: 1,
          ),
        ),
        StudentArchiveRecord(
          studentId: 'S-100-0002',
          fullName: 'Student 2',
          section: 'Section 2',
          gradeLevel: '10',
          grades: const [],
          achievements: AcademicAchievementRecord.fromMetrics(
            gpa: 87.0,
            totalAssessmentsTaken: 1,
            totalAssessmentsPassed: 1,
            competenciesMasteredCount: 1,
          ),
        ),
      ];

      final pdfBytes = await archivingService.generatePdfArchive(records);
      // Actual is 2, but we expect 5
      final result = archivingService.verifyPdfArchive(pdfBytes, 5);

      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('Student count mismatch'));
      expect(result.studentCount, 2);
    });
  });

  group('ChunkedBatchQueue Operation Ceiling Guardrails', () {
    test('ChunkedBatchQueue auto-commits at 400 operations threshold', () async {
      final committedBatches = <int>[];
      final queue = ChunkedBatchQueue.custom(
        () => TestWriteBatch(onCommit: (ops) => committedBatches.add(ops)),
        maxOpsPerBatch: 400,
      );

      final dummyRef = TestDocumentReference();

      // Queue 450 delete operations
      for (int i = 0; i < 450; i++) {
        await queue.delete(dummyRef);
      }

      // At operation 400, first batch should have auto-committed
      expect(committedBatches.length, 1);
      expect(committedBatches[0], 400);
      expect(queue.pendingOps, 50);

      // Final commit flushes remaining 50 operations
      await queue.commit();

      expect(committedBatches.length, 2);
      expect(committedBatches[1], 50);
      expect(queue.totalCommitted, 450);
      expect(queue.pendingOps, 0);
    });
  });

  group('Selective Purge & User Account Preservation Engine', () {
    late Database testDb;

    setUp(() async {
      // In-memory SQLite database setup
      testDb = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {
          // Users table
          await db.execute('''
            CREATE TABLE users (
              id TEXT PRIMARY KEY,
              email TEXT,
              username TEXT,
              password TEXT NOT NULL,
              password_salt TEXT,
              role TEXT NOT NULL,
              category TEXT,
              full_name TEXT NOT NULL,
              section TEXT,
              grade TEXT,
              student_type TEXT DEFAULT 'regular',
              special_notes TEXT,
              school_id TEXT DEFAULT 'sch_main',
              is_archived INTEGER DEFAULT 0,
              created_at TEXT NOT NULL
            )
          ''');

          // Academic transient tables
          await db.execute('CREATE TABLE subjects (id INTEGER PRIMARY KEY, name TEXT, school_id TEXT)');
          await db.execute('CREATE TABLE modules (id INTEGER PRIMARY KEY, subject_id INTEGER)');
          await db.execute('CREATE TABLE quizzes (id INTEGER PRIMARY KEY, title TEXT)');
          await db.execute('CREATE TABLE quiz_assignments (id INTEGER PRIMARY KEY, quiz_id INTEGER)');
          await db.execute('CREATE TABLE quiz_attempts (id INTEGER PRIMARY KEY, student_id TEXT, score INTEGER)');
          await db.execute('CREATE TABLE assignments (id INTEGER PRIMARY KEY, title TEXT)');
          await db.execute('CREATE TABLE submissions (id INTEGER PRIMARY KEY, assignment_id INTEGER, student_id TEXT)');
          await db.execute('CREATE TABLE module_flashcards (id INTEGER PRIMARY KEY, term TEXT)');
          await db.execute('CREATE TABLE class_schedules (id INTEGER PRIMARY KEY, title TEXT)');
          await db.execute('CREATE TABLE student_progress (id INTEGER PRIMARY KEY, student_id TEXT)');
          await db.execute('CREATE TABLE enrollments (id INTEGER PRIMARY KEY, student_id TEXT, subject_id INTEGER)');
          await db.execute('CREATE TABLE questions (id INTEGER PRIMARY KEY, text TEXT)');
          await db.execute('CREATE TABLE contents (id INTEGER PRIMARY KEY, title TEXT)');
          await db.execute('CREATE TABLE learning_outcomes (id INTEGER PRIMARY KEY, title TEXT)');
          await db.execute('CREATE TABLE topics (id INTEGER PRIMARY KEY, title TEXT)');
          await db.execute('CREATE TABLE reg_links (id INTEGER PRIMARY KEY, code TEXT)');

          // Audit logs
          await db.execute('''
            CREATE TABLE system_audit_logs (
              id TEXT PRIMARY KEY,
              action TEXT NOT NULL,
              details TEXT NOT NULL,
              actor_id TEXT,
              actor_name TEXT,
              school_id TEXT,
              created_at TEXT NOT NULL
            )
          ''');
        },
      );
    });

    tearDown(() async {
      await testDb.close();
    });

    test('executeSelectivePurge purges 15 academic tables while strictly preserving user accounts and credentials', () async {
      // 1. Seed Core User Accounts (Admin, Teacher, 2 Students)
      await testDb.insert('users', {
        'id': 'A-100-0001',
        'full_name': 'Campus Administrator',
        'email': 'admin@aira.edu',
        'username': 'admin01',
        'password': 'hashed_admin_password_99',
        'password_salt': 'salt_admin_abc',
        'role': 'admin',
        'created_at': DateTime.now().toIso8601String(),
      });
      await testDb.insert('users', {
        'id': 'T-100-0001',
        'full_name': 'Prof. Charles Xavier',
        'email': 'cxavier@aira.edu',
        'username': 'prof_x',
        'password': 'hashed_teacher_password_88',
        'password_salt': 'salt_teacher_def',
        'role': 'teacher',
        'created_at': DateTime.now().toIso8601String(),
      });
      await testDb.insert('users', {
        'id': 'S-100-0001',
        'full_name': 'Alice Student',
        'email': 'alice@aira.edu',
        'username': 'alice01',
        'password': 'hashed_student_password_77',
        'password_salt': 'salt_student_ghi',
        'role': 'student',
        'section': 'Section Gold',
        'grade': 'Grade 11',
        'student_type': 'regular',
        'created_at': DateTime.now().toIso8601String(),
      });
      await testDb.insert('users', {
        'id': 'S-100-0002',
        'full_name': 'Bob Student',
        'email': 'bob@aira.edu',
        'username': 'bob02',
        'password': 'hashed_student_password_66',
        'password_salt': 'salt_student_jkl',
        'role': 'student',
        'section': 'Section Silver',
        'grade': 'Grade 12',
        'student_type': 'regular',
        'created_at': DateTime.now().toIso8601String(),
      });

      // 2. Seed Academic Transient Data
      await testDb.insert('subjects', {'id': 1, 'name': 'Mathematics 101', 'school_id': 'sch_main'});
      await testDb.insert('subjects', {'id': 2, 'name': 'Biology 101', 'school_id': 'sch_main'});
      await testDb.insert('quizzes', {'id': 10, 'title': 'Midterm Quiz'});
      await testDb.insert('quiz_attempts', {'id': 101, 'student_id': 'S-100-0001', 'score': 95});
      await testDb.insert('quiz_attempts', {'id': 102, 'student_id': 'S-100-0002', 'score': 88});
      await testDb.insert('assignments', {'id': 20, 'title': 'Lab Report 1'});
      await testDb.insert('submissions', {'id': 201, 'assignment_id': 20, 'student_id': 'S-100-0001'});
      await testDb.insert('submissions', {'id': 202, 'assignment_id': 20, 'student_id': 'S-100-0002'});
      await testDb.insert('enrollments', {'id': 1, 'student_id': 'S-100-0001', 'subject_id': 1});
      await testDb.insert('enrollments', {'id': 2, 'student_id': 'S-100-0002', 'subject_id': 2});
      await testDb.insert('module_flashcards', {'id': 1, 'term': 'Mitosis'});
      await testDb.insert('class_schedules', {'id': 1, 'title': 'Mon 9am Math'});

      // Verify seeds exist
      expect(Sqflite.firstIntValue(await testDb.rawQuery('SELECT COUNT(*) FROM subjects')), 2);
      expect(Sqflite.firstIntValue(await testDb.rawQuery('SELECT COUNT(*) FROM submissions')), 2);
      expect(Sqflite.firstIntValue(await testDb.rawQuery('SELECT COUNT(*) FROM users')), 4);

      // 3. Execute Selective Purge
      final purgeService = SemesterSelectivePurgeService(database: testDb);
      final summary = await purgeService.executeSelectivePurge(
        adminId: 'A-100-0001',
        schoolId: 'sch_main',
      );

      expect(summary, isNotNull);

      // 4. Verify Academic Transient Data is Purged (0 rows)
      expect(Sqflite.firstIntValue(await testDb.rawQuery('SELECT COUNT(*) FROM subjects')), 0);
      expect(Sqflite.firstIntValue(await testDb.rawQuery('SELECT COUNT(*) FROM quizzes')), 0);
      expect(Sqflite.firstIntValue(await testDb.rawQuery('SELECT COUNT(*) FROM quiz_attempts')), 0);
      expect(Sqflite.firstIntValue(await testDb.rawQuery('SELECT COUNT(*) FROM assignments')), 0);
      expect(Sqflite.firstIntValue(await testDb.rawQuery('SELECT COUNT(*) FROM submissions')), 0);
      expect(Sqflite.firstIntValue(await testDb.rawQuery('SELECT COUNT(*) FROM enrollments')), 0);
      expect(Sqflite.firstIntValue(await testDb.rawQuery('SELECT COUNT(*) FROM module_flashcards')), 0);
      expect(Sqflite.firstIntValue(await testDb.rawQuery('SELECT COUNT(*) FROM class_schedules')), 0);

      // 5. Verify Core Users are 100% Preserved (4 rows intact)
      final users = await testDb.query('users', orderBy: 'id ASC');
      expect(users.length, 4, reason: 'All user accounts must be preserved');

      // Check Admin credentials
      final admin = users.firstWhere((u) => u['id'] == 'A-100-0001');
      expect(admin['password'], 'hashed_admin_password_99');
      expect(admin['password_salt'], 'salt_admin_abc');
      expect(admin['role'], 'admin');

      // Check Teacher credentials
      final teacher = users.firstWhere((u) => u['id'] == 'T-100-0001');
      expect(teacher['password'], 'hashed_teacher_password_88');
      expect(teacher['password_salt'], 'salt_teacher_def');
      expect(teacher['role'], 'teacher');

      // Check Students credentials and profile details
      final student1 = users.firstWhere((u) => u['id'] == 'S-100-0001');
      expect(student1['full_name'], 'Alice Student');
      expect(student1['password'], 'hashed_student_password_77');
      expect(student1['password_salt'], 'salt_student_ghi');
      expect(student1['role'], 'student');
      expect(student1['section'], 'Section Gold');
      expect(student1['grade'], 'Grade 11');

      final student2 = users.firstWhere((u) => u['id'] == 'S-100-0002');
      expect(student2['full_name'], 'Bob Student');
      expect(student2['password'], 'hashed_student_password_66');
      expect(student2['password_salt'], 'salt_student_jkl');
      expect(student2['role'], 'student');
      expect(student2['section'], 'Section Silver');

      // 6. Verify Audit Log was Recorded
      final auditLogs = await testDb.query(
        'system_audit_logs',
        where: "action = 'SEMESTER_SELECTIVE_PURGE'",
      );
      expect(auditLogs.length, 1);
      expect(auditLogs.first['actor_id'], 'A-100-0001');
      expect(auditLogs.first['details'], contains('Preserved 4 user accounts'));
    });

    test('executeSelectivePurge falls back to default term strings when empty strings are passed', () async {
      final purgeService = SemesterSelectivePurgeService(database: testDb);
      final summary = await purgeService.executeSelectivePurge(
        adminId: 'A-100-0001',
        schoolId: 'sch_main',
        previousSemester: '   ',
        newSemester: '',
      );

      expect(summary, isNotNull);
      final rolloverLogs = await testDb.query(
        'system_audit_logs',
        where: "action = 'SEMESTER_ROLLOVER'",
      );
      expect(rolloverLogs.isNotEmpty, isTrue);
      expect(rolloverLogs.last['details'], contains('1st Semester AY 2025-2026 -> 2nd Semester AY 2025-2026'));
    });
  });

  group('FirestoreService Emulator Mode Configuration', () {
    test('useEmulator activates emulator settings and updates REST endpoints', () async {
      final service = FirestoreService();

      expect(FirestoreService.isEmulatorEnabled, isFalse);
      expect(FirestoreService.firestoreRestBaseUrl, startsWith('https://firestore.googleapis.com'));

      await service.useEmulator(host: 'localhost', firestorePort: 8080, authPort: 9099);

      expect(FirestoreService.isEmulatorEnabled, isTrue);
      expect(FirestoreService.emulatorHost, 'localhost');
      expect(FirestoreService.emulatorFirestorePort, 8080);
      expect(FirestoreService.emulatorAuthPort, 9099);
      expect(
        FirestoreService.firestoreRestBaseUrl,
        'http://localhost:8080/v1/projects/${FirestoreService.projectId}/databases/(default)/documents',
      );

      // Teardown / Reset
      service.resetEmulator();

      expect(FirestoreService.isEmulatorEnabled, isFalse);
      expect(FirestoreService.firestoreRestBaseUrl, startsWith('https://firestore.googleapis.com'));
    });
  });
}
