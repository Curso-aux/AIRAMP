import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:airamp_flutter/src/features/admin/data/semester_record_archiving_service.dart';
import 'package:airamp_flutter/src/features/admin/data/semester_selective_purge_service.dart';
import 'package:airamp_flutter/src/features/admin/domain/semester_archive_models.dart';
import 'package:airamp_flutter/src/features/admin/presentation/controllers/semester_renewal_controller.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
  });

  group('R1: Relational Data Fetching & Mapping (No Orphaned Records)', () {
    late Database testDb;

    setUp(() async {
      testDb = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE users (
              id TEXT PRIMARY KEY,
              full_name TEXT,
              name TEXT,
              username TEXT,
              email TEXT,
              role TEXT,
              grade TEXT,
              grade_level TEXT,
              section TEXT,
              student_type TEXT,
              school_id TEXT,
              status TEXT,
              is_archived INTEGER DEFAULT 0,
              special_notes TEXT,
              enrolled_subjects TEXT,
              password TEXT,
              password_salt TEXT,
              enrolled_courses INTEGER DEFAULT 0,
              updated_at TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE subjects (
              id TEXT PRIMARY KEY,
              name TEXT,
              subject_code TEXT,
              teacher_name TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE quizzes (
              id TEXT PRIMARY KEY,
              title TEXT,
              subject_id TEXT,
              total_questions INTEGER,
              max_score REAL
            )
          ''');
          await db.execute('''
            CREATE TABLE quiz_attempts (
              id TEXT PRIMARY KEY,
              quiz_id TEXT,
              student_id TEXT,
              subject_id TEXT,
              score REAL,
              total_questions INTEGER,
              percentage REAL,
              created_at TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE assignments (
              id TEXT PRIMARY KEY,
              title TEXT,
              subject_id TEXT,
              max_score REAL,
              total_points REAL
            )
          ''');
          await db.execute('''
            CREATE TABLE submissions (
              id TEXT PRIMARY KEY,
              assignment_id TEXT,
              student_id TEXT,
              subject_id TEXT,
              grade REAL,
              score REAL,
              status TEXT,
              submitted_at TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE student_progress (
              id TEXT PRIMARY KEY,
              student_id TEXT,
              is_completed INTEGER DEFAULT 0
            )
          ''');
          await db.execute('''
            CREATE TABLE system_audit_logs (
              id TEXT PRIMARY KEY,
              action TEXT NOT NULL,
              details TEXT,
              actor_id TEXT,
              actor_name TEXT,
              school_id TEXT,
              created_at TEXT,
              previous_semester TEXT,
              new_semester TEXT
            )
          ''');
        },
      );

      // Seed Student 1: Enrolled in Math and Science with attempts and submissions
      await testDb.insert('users', {
        'id': 'S-100-0001',
        'full_name': 'Juan Dela Cruz',
        'email': 'juan.delacruz@campus.edu',
        'role': 'student',
        'grade_level': 'Grade 10',
        'section': '10-Rizal',
        'student_type': 'regular',
        'school_id': 'sch_main',
        'status': 'active',
        'enrolled_subjects': jsonEncode(['SUBJ-MATH10', 'SUBJ-SCI10']),
        'password': 'hash_pwd_juan',
        'password_salt': 'salt_juan',
      });

      // Seed Student 2: Enrolled only in English, no other subjects
      await testDb.insert('users', {
        'id': 'S-100-0002',
        'full_name': 'Maria Clara',
        'email': 'maria.clara@campus.edu',
        'role': 'student',
        'grade_level': 'Grade 10',
        'section': '10-Bonifacio',
        'student_type': 'scholar',
        'school_id': 'sch_main',
        'status': 'active',
        'enrolled_subjects': jsonEncode(['SUBJ-ENG10']),
        'password': 'hash_pwd_maria',
        'password_salt': 'salt_maria',
      });

      // Seed Student 3: New student with NO enrolled subjects and NO attempts
      await testDb.insert('users', {
        'id': 'S-100-0003',
        'full_name': 'Pedro Penduko',
        'email': 'pedro.penduko@campus.edu',
        'role': 'student',
        'grade_level': 'Grade 10',
        'section': '10-Bonifacio',
        'student_type': 'regular',
        'school_id': 'sch_main',
        'status': 'active',
        'enrolled_subjects': '[]',
        'password': 'hash_pwd_pedro',
        'password_salt': 'salt_pedro',
      });

      // Seed Teachers and Admins (should not be in student archive)
      await testDb.insert('users', {
        'id': 'T-200-0001',
        'full_name': 'Prof. Einstein',
        'email': 'einstein@campus.edu',
        'role': 'teacher',
        'school_id': 'sch_main',
        'status': 'active',
      });
      await testDb.insert('users', {
        'id': 'A-001-0001',
        'full_name': 'Campus Admin User',
        'email': 'admin@campus.edu',
        'role': 'admin',
        'school_id': 'sch_main',
        'status': 'active',
      });

      // Seed Subjects
      await testDb.insert('subjects', {
        'id': 'SUBJ-MATH10',
        'name': 'Mathematics 10',
        'subject_code': 'MATH10',
        'teacher_name': 'Mr. Pythagoras',
      });
      await testDb.insert('subjects', {
        'id': 'SUBJ-SCI10',
        'name': 'Science 10',
        'subject_code': 'SCI10',
        'teacher_name': 'Ms. Curie',
      });
      await testDb.insert('subjects', {
        'id': 'SUBJ-ENG10',
        'name': 'English 10',
        'subject_code': 'ENG10',
        'teacher_name': 'Mr. Shakespeare',
      });
      await testDb.insert('subjects', {
        'id': 'SUBJ-HIST10',
        'name': 'History 10',
        'subject_code': 'HIST10',
        'teacher_name': 'Mr. Herodotus',
      });

      // Seed Quizzes and Attempts
      await testDb.insert('quizzes', {
        'id': 'QUIZ-M1',
        'title': 'Quadratic Equations Quiz',
        'subject_id': 'SUBJ-MATH10',
        'total_questions': 20,
        'max_score': 20.0,
      });
      await testDb.insert('quiz_attempts', {
        'id': 'QA-001',
        'quiz_id': 'QUIZ-M1',
        'student_id': 'S-100-0001',
        'subject_id': 'SUBJ-MATH10',
        'score': 19.0,
        'total_questions': 20,
        'percentage': 95.0,
        'created_at': '2026-10-15T08:30:00Z',
      });

      // Seed Assignments and Submissions
      await testDb.insert('assignments', {
        'id': 'ASGN-M1',
        'title': 'Parabola Problem Set',
        'subject_id': 'SUBJ-MATH10',
        'max_score': 100.0,
        'total_points': 100.0,
      });
      await testDb.insert('submissions', {
        'id': 'SUB-001',
        'assignment_id': 'ASGN-M1',
        'student_id': 'S-100-0001',
        'subject_id': 'SUBJ-MATH10',
        'grade': 90.0,
        'score': 90.0,
        'status': 'graded',
        'submitted_at': '2026-10-20T14:00:00Z',
      });

      // Seed Orphaned Quiz Attempt (references non-existent student S-999-9999)
      await testDb.insert('quiz_attempts', {
        'id': 'QA-ORPHAN',
        'quiz_id': 'QUIZ-M1',
        'student_id': 'S-999-9999',
        'subject_id': 'SUBJ-MATH10',
        'score': 10.0,
        'total_questions': 20,
        'percentage': 50.0,
        'created_at': '2026-10-15T08:30:00Z',
      });

      // Seed student_progress
      await testDb.insert('student_progress', {
        'id': 'PROG-1',
        'student_id': 'S-100-0001',
        'is_completed': 1,
      });
      await testDb.insert('student_progress', {
        'id': 'PROG-2',
        'student_id': 'S-100-0001',
        'is_completed': 1,
      });
    });

    tearDown(() async {
      await testDb.close();
    });

    test('fetchAllStudentRecords joins student profiles to enrolled subjects without orphans', () async {
      final archivingService = SemesterRecordArchivingService(database: testDb);
      final records = await archivingService.fetchAllStudentRecords();

      // Only students S-100-0001, S-100-0002, S-100-0003 are returned (no teachers, admins, or orphan IDs)
      expect(records.length, equals(3));
      final ids = records.map((r) => r.studentId).toSet();
      expect(ids, containsAll(['S-100-0001', 'S-100-0002', 'S-100-0003']));
      expect(ids, isNot(contains('T-200-0001')));
      expect(ids, isNot(contains('A-001-0001')));
      expect(ids, isNot(contains('S-999-9999')));

      // Student 1 check
      final s1 = records.firstWhere((r) => r.studentId == 'S-100-0001');
      expect(s1.fullName, equals('Juan Dela Cruz'));
      expect(s1.email, equals('juan.delacruz@campus.edu'));
      expect(s1.section, equals('10-Rizal'));
      expect(s1.gradeLevel, equals('Grade 10'));
      expect(s1.studentType, equals('regular'));
      expect(s1.grades.length, equals(2)); // Math and Science

      final mathGrade = s1.grades.firstWhere((g) => g.subjectId == 'SUBJ-MATH10');
      expect(mathGrade.subjectName, equals('Mathematics 10'));
      expect(mathGrade.teacherName, equals('Mr. Pythagoras'));
      expect(mathGrade.quizAverage, equals(95.0));
      expect(mathGrade.assignmentAverage, equals(90.0));
      expect(mathGrade.averageScore, equals(92.5));
      expect(mathGrade.isPassed, isTrue);
      expect(mathGrade.assessments.length, equals(2)); // 1 quiz + 1 assignment

      final quizItem = mathGrade.assessments.firstWhere((a) => a.itemType == 'Quiz');
      expect(quizItem.title, equals('Quadratic Equations Quiz'));
      expect(quizItem.score, equals(19.0));
      expect(quizItem.maxPoints, equals(20.0));
      expect(quizItem.percentage, equals(95.0));
      expect(quizItem.status, equals('graded'));

      final asgnItem = mathGrade.assessments.firstWhere((a) => a.itemType == 'Assignment');
      expect(asgnItem.title, equals('Parabola Problem Set'));
      expect(asgnItem.score, equals(90.0));
      expect(asgnItem.maxPoints, equals(100.0));
      expect(asgnItem.percentage, equals(90.0));
      expect(asgnItem.status, equals('graded'));

      // Student 2 check (enrolled only in English)
      final s2 = records.firstWhere((r) => r.studentId == 'S-100-0002');
      expect(s2.grades.length, equals(1));
      expect(s2.grades.first.subjectId, equals('SUBJ-ENG10'));

      // Student 3 check (no enrolled subjects, NO arbitrary .take(3) fallback)
      final s3 = records.firstWhere((r) => r.studentId == 'S-100-0003');
      expect(s3.grades, isEmpty, reason: 'Must not arbitrarily assign 3 subjects to students with 0 enrolled subjects');
      expect(s3.achievements.gpa, equals(0.0));
    });
  });

  group('R2: Multi-Sheet Excel (.xlsx) Generation & ZIP Packaging', () {
    late List<StudentArchiveRecord> sampleRecords;
    late SemesterRecordArchivingService service;

    setUp(() {
      service = SemesterRecordArchivingService();

      sampleRecords = [
        StudentArchiveRecord(
          studentId: 'S-100-0001',
          fullName: 'Juan Dela Cruz',
          email: 'juan@campus.edu',
          section: '10-Rizal',
          gradeLevel: 'Grade 10',
          studentType: 'regular',
          schoolId: 'sch_main',
          status: 'active',
          grades: [
            SubjectGradeRecord(
              subjectId: 'SUBJ-MATH10',
              subjectName: 'Mathematics 10',
              subjectCode: 'MATH10',
              teacherName: 'Mr. Pythagoras',
              quizScores: const [95.0],
              assignmentGrades: const [90.0],
              averageScore: 92.5,
              isPassed: true,
              assessments: [
                AssessmentItemRecord(
                  itemType: 'Quiz',
                  title: 'Quadratic Equations Quiz',
                  maxPoints: 20.0,
                  score: 19.0,
                  percentage: 95.0,
                  status: 'graded',
                  timestamp: DateTime(2026, 10, 15),
                  subjectId: 'SUBJ-MATH10',
                  subjectCode: 'MATH10',
                  subjectName: 'Mathematics 10',
                ),
              ],
            ),
          ],
          achievements: AcademicAchievementRecord.fromMetrics(
            gpa: 92.5,
            totalAssessmentsTaken: 2,
            totalAssessmentsPassed: 2,
            competenciesMasteredCount: 4,
            totalQuizzesCompleted: 1,
            totalAssignmentsSubmitted: 1,
          ),
        ),
        StudentArchiveRecord(
          studentId: 'S-100-0002',
          fullName: 'Maria Clara',
          email: 'maria@campus.edu',
          section: '10-Bonifacio',
          gradeLevel: 'Grade 10',
          studentType: 'scholar',
          schoolId: 'sch_main',
          status: 'active',
          grades: const [],
          achievements: AcademicAchievementRecord.fromMetrics(
            gpa: 98.5,
            totalAssessmentsTaken: 1,
            totalAssessmentsPassed: 1,
            competenciesMasteredCount: 5,
            totalQuizzesCompleted: 1,
            totalAssignmentsSubmitted: 0,
          ),
        ),
      ];
    });

    test('generateExcelWorkbook produces structured .xlsx workbook with 3 distinct required sheets', () async {
      final xlsxBytes = await service.generateExcelWorkbook(
        sampleRecords,
        academicYear: 'AY2025-2026',
        semester: '1st Semester',
      );

      expect(xlsxBytes, isNotNull);
      expect(xlsxBytes.length, greaterThan(100));

      // Test parsing: we can read the raw zip entries inside xlsx (since .xlsx is an OpenXML ZIP)
      final xlsxArchive = ZipDecoder().decodeBytes(xlsxBytes);
      final entryNames = xlsxArchive.files.map((f) => f.name).toList();
      expect(entryNames, contains('xl/workbook.xml'));

      // Check sheet definitions in workbook.xml
      final workbookXml = utf8.decode(
        xlsxArchive.files.firstWhere((f) => f.name == 'xl/workbook.xml').content as List<int>,
      );
      expect(workbookXml, contains('Student Personal Info'));
      expect(workbookXml, contains('Semester Grades &amp; Achievements'));
      expect(workbookXml, contains('Subjects, Assignments &amp; Quizzes'));
    });

    test('generateExcelZipArchive packages Master and per-section workbooks into valid .zip', () async {
      final zipBytes = await service.generateExcelZipArchive(
        records: sampleRecords,
        academicYear: 'AY2025-2026',
        semester: '1st Semester',
      );

      expect(zipBytes, isNotNull);
      expect(zipBytes.length, greaterThan(200));

      // Magic bytes PK\x03\x04
      expect(zipBytes[0], equals(0x50)); // 'P'
      expect(zipBytes[1], equals(0x4B)); // 'K'
      expect(zipBytes[2], equals(0x03));
      expect(zipBytes[3], equals(0x04));

      // Decode ZIP archive
      final archive = ZipDecoder().decodeBytes(zipBytes);
      final fileNames = archive.files.map((f) => f.name).toList();

      // Master workbook
      expect(
        fileNames.any((name) => name.startsWith('CampusRecords_AY2025-2026_1st_Semester_') && name.endsWith('.xlsx')),
        isTrue,
      );

      // Grouped Section workbooks
      expect(
        fileNames.any((name) => name.contains('10-Rizal') && name.endsWith('.xlsx')),
        isTrue,
      );
      expect(
        fileNames.any((name) => name.contains('10-Bonifacio') && name.endsWith('.xlsx')),
        isTrue,
      );

      // Verify each workbook has non-zero size
      for (final file in archive.files) {
        expect(file.size, greaterThan(0));
      }
    });

    test('verifyZipArchive validates magic bytes, entries, SHA-256 checksum, and catches corrupt buffers', () async {
      final zipBytes = await service.generateExcelZipArchive(
        records: sampleRecords,
        academicYear: 'AY2025-2026',
        semester: '1st Semester',
      );

      final validResult = service.verifyZipArchive(zipBytes, sampleRecords.length);
      expect(validResult.isValid, isTrue);
      expect(validResult.studentCount, equals(sampleRecords.length));
      expect(validResult.byteLength, equals(zipBytes.length));
      expect(validResult.fileCount, greaterThanOrEqualTo(3)); // Master + 2 sections
      expect(validResult.checksum, equals(sha256.convert(zipBytes).toString()));
      expect(validResult.errorMessage, isNull);

      // Corrupted header test
      final corruptHeaderBytes = Uint8List.fromList(zipBytes);
      corruptHeaderBytes[0] = 0x00; // Destroy 'P'
      final headerResult = service.verifyZipArchive(corruptHeaderBytes, sampleRecords.length);
      expect(headerResult.isValid, isFalse);
      expect(headerResult.errorMessage, contains('magic bytes'));

      // Too short buffer test
      final shortBytes = Uint8List.fromList([0x50, 0x4B]);
      final shortResult = service.verifyZipArchive(shortBytes, sampleRecords.length);
      expect(shortResult.isValid, isFalse);
      expect(shortResult.errorMessage, contains('too short'));

      // Non-xlsx archive test
      final dummyArchive = Archive();
      dummyArchive.addFile(ArchiveFile('readme.txt', 4, utf8.encode('test')));
      final nonXlsxZip = Uint8List.fromList(ZipEncoder().encode(dummyArchive));
      final nonXlsxResult = service.verifyZipArchive(nonXlsxZip, sampleRecords.length);
      expect(nonXlsxResult.isValid, isFalse);
      expect(nonXlsxResult.errorMessage, contains('zero .xlsx workbook files'));
    });

    test('verifyZipArchive fails on negative expected student count', () async {
      final zipBytes = await service.generateExcelZipArchive(
        records: sampleRecords,
        academicYear: 'AY2025-2026',
        semester: '1st Semester',
      );

      final result = service.verifyZipArchive(zipBytes, -1);
      expect(result.isValid, isFalse);
      expect(result.studentCount, equals(-1));
      expect(result.errorMessage, contains('Invalid expected student count'));
    });
  });

  group('R3 & R4: Selective Reset Guardrails & Semester Rollover Audit Trail', () {
    late Database testDb;

    setUp(() async {
      testDb = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE users (
              id TEXT PRIMARY KEY,
              full_name TEXT,
              role TEXT,
              section TEXT,
              grade_level TEXT,
              student_type TEXT,
              is_archived INTEGER DEFAULT 0,
              enrolled_subjects TEXT,
              enrolled_courses INTEGER DEFAULT 0,
              password TEXT,
              password_salt TEXT,
              updated_at TEXT
            )
          ''');
          await db.execute('CREATE TABLE subjects (id TEXT PRIMARY KEY, name TEXT)');
          await db.execute('CREATE TABLE quizzes (id TEXT PRIMARY KEY, title TEXT)');
          await db.execute('CREATE TABLE quiz_attempts (id TEXT PRIMARY KEY, score REAL)');
          await db.execute('CREATE TABLE assignments (id TEXT PRIMARY KEY, title TEXT)');
          await db.execute('CREATE TABLE submissions (id TEXT PRIMARY KEY, grade REAL)');
          await db.execute('CREATE TABLE student_progress (id TEXT PRIMARY KEY, is_completed INTEGER)');
          await db.execute('''
            CREATE TABLE system_audit_logs (
              id TEXT PRIMARY KEY,
              action TEXT NOT NULL,
              details TEXT,
              actor_id TEXT,
              actor_name TEXT,
              school_id TEXT,
              created_at TEXT,
              previous_semester TEXT,
              new_semester TEXT
            )
          ''');
        },
      );

      // Seed student, teacher, admin accounts
      await testDb.insert('users', {
        'id': 'S-100-0001',
        'full_name': 'Student One',
        'role': 'student',
        'enrolled_courses': 3,
        'enrolled_subjects': '["SUBJ-1", "SUBJ-2"]',
        'password': 'hash_pwd_s1',
        'password_salt': 'salt_s1',
      });
      await testDb.insert('users', {
        'id': 'T-200-0001',
        'full_name': 'Teacher One',
        'role': 'teacher',
        'enrolled_courses': 0,
        'enrolled_subjects': '[]',
        'password': 'hash_pwd_t1',
        'password_salt': 'salt_t1',
      });
      await testDb.insert('users', {
        'id': 'A-001-0001',
        'full_name': 'Admin One',
        'role': 'admin',
        'enrolled_courses': 0,
        'enrolled_subjects': '[]',
        'password': 'hash_pwd_a1',
        'password_salt': 'salt_a1',
      });

      // Seed academic records to be purged
      await testDb.insert('subjects', {'id': 'SUBJ-1', 'name': 'Math'});
      await testDb.insert('quizzes', {'id': 'QUIZ-1', 'title': 'Quiz 1'});
      await testDb.insert('quiz_attempts', {'id': 'QA-1', 'score': 90.0});
      await testDb.insert('assignments', {'id': 'ASGN-1', 'title': 'Assignment 1'});
      await testDb.insert('submissions', {'id': 'SUB-1', 'grade': 85.0});
      await testDb.insert('student_progress', {'id': 'PROG-1', 'is_completed': 1});
    });

    tearDown(() async {
      await testDb.close();
    });

    test('executeSelectivePurge clears transient data, retains user accounts, and writes rollover audit record', () async {
      final purgeService = SemesterSelectivePurgeService(database: testDb);

      final summary = await purgeService.executeSelectivePurge(
        adminId: 'A-001-0001',
        schoolId: 'sch_main',
        previousSemester: '1st Semester AY 2025-2026',
        newSemester: '2nd Semester AY 2025-2026',
      );

      expect(summary, isNotNull);
      expect(summary.preservedUsersCount, equals(3));

      // Transient collections purged
      expect(Sqflite.firstIntValue(await testDb.rawQuery('SELECT COUNT(*) FROM subjects')), equals(0));
      expect(Sqflite.firstIntValue(await testDb.rawQuery('SELECT COUNT(*) FROM quizzes')), equals(0));
      expect(Sqflite.firstIntValue(await testDb.rawQuery('SELECT COUNT(*) FROM quiz_attempts')), equals(0));
      expect(Sqflite.firstIntValue(await testDb.rawQuery('SELECT COUNT(*) FROM assignments')), equals(0));
      expect(Sqflite.firstIntValue(await testDb.rawQuery('SELECT COUNT(*) FROM submissions')), equals(0));
      expect(Sqflite.firstIntValue(await testDb.rawQuery('SELECT COUNT(*) FROM student_progress')), equals(0));

      // Core user accounts 100% preserved
      final allUsers = await testDb.query('users', orderBy: 'id ASC');
      expect(allUsers.length, equals(3));

      final student = allUsers.firstWhere((u) => u['id'] == 'S-100-0001');
      expect(student['password'], equals('hash_pwd_s1'));
      expect(student['password_salt'], equals('salt_s1'));

      final teacher = allUsers.firstWhere((u) => u['id'] == 'T-200-0001');
      expect(teacher['password'], equals('hash_pwd_t1'));

      final admin = allUsers.firstWhere((u) => u['id'] == 'A-001-0001');
      expect(admin['password'], equals('hash_pwd_a1'));

      // Rollover Audit Log recorded
      final auditLogs = await testDb.query(
        'system_audit_logs',
        where: "action = 'SEMESTER_ROLLOVER'",
      );
      expect(auditLogs.length, equals(1));
      final rolloverLog = auditLogs.first;
      expect(rolloverLog['actor_id'], equals('A-001-0001'));
      expect(rolloverLog['details'], contains('1st Semester AY 2025-2026'));
      expect(rolloverLog['details'], contains('2nd Semester AY 2025-2026'));
    });

    test('Controller enforce pre-reset lock until archive is generated and verified', () async {
      final archivingService = SemesterRecordArchivingService(database: testDb);
      final purgeService = SemesterSelectivePurgeService(database: testDb);

      final container = ProviderContainer(
        overrides: [
          semesterArchivingServiceProvider.overrideWithValue(archivingService),
          semesterPurgeServiceProvider.overrideWithValue(purgeService),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(semesterRenewalControllerProvider.notifier);

      // Initially locked
      expect(container.read(semesterRenewalControllerProvider).isResetUnlocked, isFalse);

      // Attempting purge while locked throws StateError
      expect(
        () => notifier.executeReset(adminId: 'A-001-0001', schoolId: 'sch_main'),
        throwsA(isA<StateError>()),
      );

      // Generate and verify Excel ZIP archive
      final result = await notifier.generateAndDownloadExcelZipArchive(
        academicYear: 'AY2025-2026',
        semester: '1st Semester',
      );
      expect(result, isNotNull);
      expect(result!.isValid, isTrue);

      // Now unlocked
      expect(container.read(semesterRenewalControllerProvider).isResetUnlocked, isTrue);

      // Reset executes cleanly
      final purgeSummary = await notifier.executeReset(
        adminId: 'A-001-0001',
        schoolId: 'sch_main',
        previousSemester: '1st Semester AY 2025-2026',
        newSemester: '2nd Semester AY 2025-2026',
      );

      expect(purgeSummary.preservedUsersCount, equals(3));
    });
  });
}
