import 'dart:convert';
import 'dart:ui' show Rect;
import 'package:archive/archive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/database/firestore_service.dart';
import '../domain/semester_archive_models.dart';

abstract class ISemesterRecordArchivingService {
  Future<List<StudentArchiveRecord>> fetchAllStudentRecords([String? schoolId]);
  Future<Uint8List> generatePdfArchive(List<StudentArchiveRecord> records);
  ArchiveVerificationResult verifyPdfArchive(
    Uint8List pdfBytes,
    int expectedStudentCount,
  );
  Future<Uint8List> generateExcelWorkbook(
    List<StudentArchiveRecord> records, {
    String? academicYear,
    String? semester,
  });
  Future<Uint8List> generateExcelZipArchive({
    List<StudentArchiveRecord>? records,
    String? academicYear,
    String? semester,
  });
  ArchiveVerificationResult verifyZipArchive(
    Uint8List zipBytes, [
    int expectedStudentCount = 0,
  ]);
}

class SemesterRecordArchivingService
    implements ISemesterRecordArchivingService {
  final FirestoreService _firestoreService;
  final DatabaseHelper _dbHelper;
  final FirebaseFirestore? firestore;
  final Database? database;

  SemesterRecordArchivingService({
    FirestoreService? firestoreService,
    DatabaseHelper? dbHelper,
    this.firestore,
    this.database,
  }) : _firestoreService = firestoreService ?? FirestoreService(),
       _dbHelper = dbHelper ?? DatabaseHelper();

  Future<Database> _getDatabase() async {
    final db = database;
    if (db != null) return db;
    return await _dbHelper.database;
  }

  @override
  Future<List<StudentArchiveRecord>> fetchAllStudentRecords([String? schoolId]) async {
    List<Map<String, dynamic>> rawStudents = [];
    List<Map<String, dynamic>> rawSubjects = [];
    List<Map<String, dynamic>> rawQuizzes = [];
    List<Map<String, dynamic>> rawQuizAttempts = [];
    List<Map<String, dynamic>> rawAssignments = [];
    List<Map<String, dynamic>> rawSubmissions = [];
    List<Map<String, dynamic>> rawProgress = [];

    final fs = firestore;

    // 1. Fetch Students from Firestore
    if (fs != null) {
      try {
        Query<Map<String, dynamic>> query = fs.collection('users').where('role', isEqualTo: 'student');
        if (schoolId != null && schoolId.isNotEmpty) {
          query = query.where('school_id', isEqualTo: schoolId);
        }
        final snap = await query.get();
        rawStudents = snap.docs.map((d) {
          final m = Map<String, dynamic>.from(d.data());
          m['id'] = d.id;
          return m;
        }).toList();
      } catch (e) {
        debugPrint(
          '[SemesterArchiving] Direct firestore student fetch error: $e',
        );
      }
    }

    if (rawStudents.isEmpty && _firestoreService.isAvailable) {
      try {
        final allUsers = await _firestoreService.fetchAllUsers();
        rawStudents = allUsers.where((u) {
          final role = u['role']?.toString().toLowerCase();
          final id = u['id']?.toString() ?? '';
          final sId = u['school_id']?.toString();
          final matchesSchool = schoolId == null ||
              schoolId.isEmpty ||
              sId == schoolId ||
              (sId == null && schoolId == 'sch_main');
          return (role == 'student' || id.startsWith('S-')) &&
              u['is_archived'] != true &&
              u['is_archived'] != 1 &&
              matchesSchool;
        }).toList();
      } catch (e) {
        debugPrint(
          '[SemesterArchiving] FirestoreService student fetch error: $e',
        );
      }
    }

    // Fallback to SQLite if Firestore students empty
    if (rawStudents.isEmpty) {
      final db = await _getDatabase();
      final hasSchool = schoolId != null && schoolId.isNotEmpty;
      final schoolWhere = hasSchool ? " AND (school_id = ? OR (school_id IS NULL AND ? = 'sch_main'))" : "";
      final schoolArgs = hasSchool ? [schoolId, schoolId] : <String>[];

      try {
        rawStudents = await db.query(
          'users',
          where:
              "(role = 'student' OR (role IS NULL AND id LIKE 'S-%')) AND (is_archived IS NULL OR is_archived = 0)$schoolWhere",
          whereArgs: schoolArgs.isNotEmpty ? schoolArgs : null,
          orderBy: 'full_name ASC',
        );
      } catch (_) {
        try {
          rawStudents = await db.query(
            'users',
            where: "(role = 'student' OR (role IS NULL AND id LIKE 'S-%'))$schoolWhere",
            whereArgs: schoolArgs.isNotEmpty ? schoolArgs : null,
          );
        } catch (_) {}
      }
    }

    // 2. Fetch Subjects & Academic Collections
    if (fs != null) {
      try {
        Query<Map<String, dynamic>> subQuery = fs.collection('subjects');
        if (schoolId != null && schoolId.isNotEmpty) {
          subQuery = subQuery.where('school_id', isEqualTo: schoolId);
        }
        final subSnap = await subQuery.get();
        rawSubjects = subSnap.docs
            .map((d) => {...d.data(), 'id': d.id})
            .toList();

        final qSnap = await fs.collection('quizzes').get();
        rawQuizzes = qSnap.docs.map((d) => {...d.data(), 'id': d.id}).toList();

        final qaSnap = await fs.collection('quiz_attempts').get();
        rawQuizAttempts = qaSnap.docs
            .map((d) => {...d.data(), 'id': d.id})
            .toList();

        final asgnSnap = await fs.collection('assignments').get();
        rawAssignments = asgnSnap.docs
            .map((d) => {...d.data(), 'id': d.id})
            .toList();

        final submissSnap = await fs.collection('submissions').get();
        rawSubmissions = submissSnap.docs
            .map((d) => {...d.data(), 'id': d.id})
            .toList();

        final progSnap = await fs.collection('student_progress').get();
        rawProgress = progSnap.docs
            .map((d) => {...d.data(), 'id': d.id})
            .toList();
      } catch (e) {
        debugPrint('[SemesterArchiving] Firestore collections read note: $e');
      }
    }

    // Fallback / supplement from SQLite
    if (rawSubjects.isEmpty ||
        rawQuizAttempts.isEmpty ||
        rawAssignments.isEmpty) {
      try {
        final db = await _getDatabase();
        if (rawSubjects.isEmpty) {
          if (schoolId != null && schoolId.isNotEmpty) {
            rawSubjects = await db.query(
              'subjects',
              where: "school_id = ? OR (school_id IS NULL AND ? = 'sch_main')",
              whereArgs: [schoolId, schoolId],
            );
          } else {
            rawSubjects = await db.query('subjects');
          }
        }
        if (rawQuizzes.isEmpty) {
          try {
            rawQuizzes = await db.query('quizzes');
          } catch (_) {}
        }
        if (rawQuizAttempts.isEmpty) {
          rawQuizAttempts = await db.query('quiz_attempts');
        }
        if (rawAssignments.isEmpty) {
          rawAssignments = await db.query('assignments');
        }
        if (rawSubmissions.isEmpty) {
          rawSubmissions = await db.query('submissions');
        }
        if (rawProgress.isEmpty) {
          try {
            rawProgress = await db.query('student_progress');
          } catch (_) {}
        }
      } catch (_) {}
    }

    final subjectsMap = <String, Map<String, dynamic>>{};
    for (final s in rawSubjects) {
      final sid = s['id'].toString();
      subjectsMap[sid] = s;
    }

    final quizzesMap = <String, Map<String, dynamic>>{};
    for (final q in rawQuizzes) {
      final qid = q['id'].toString();
      quizzesMap[qid] = q;
    }

    final assignmentsMap = <String, Map<String, dynamic>>{};
    for (final a in rawAssignments) {
      final aid = a['id'].toString();
      assignmentsMap[aid] = a;
    }

    final List<StudentArchiveRecord> archiveRecords = [];

    for (final student in rawStudents) {
      final sId = student['id'].toString();
      final fullName =
          student['full_name']?.toString() ??
          student['name']?.toString() ??
          student['username']?.toString() ??
          'Student';
      final email = student['email']?.toString() ?? '';
      final section = student['section']?.toString() ?? 'Unassigned';
      final gradeLevel =
          student['grade']?.toString() ??
          student['grade_level']?.toString() ??
          'N/A';
      final studentType = student['student_type']?.toString() ?? 'regular';
      final schoolId = student['school_id']?.toString() ?? '';
      final status = student['status']?.toString() ?? 'active';
      final specialNotes = student['special_notes']?.toString();

      final studentAttempts = rawQuizAttempts
          .where((a) => a['student_id']?.toString() == sId)
          .toList();
      final studentSubmissions = rawSubmissions
          .where((sub) => sub['student_id']?.toString() == sId)
          .toList();
      final studentCompletedLos = rawProgress
          .where(
            (p) =>
                p['student_id']?.toString() == sId &&
                (p['is_completed'] == 1 || p['is_completed'] == true),
          )
          .toList();

      // Gather involved subjects without orphaned records:
      // 1. Explicit enrolled_subjects on student document
      final involvedSubjectIds = <String>{};
      final enrolledField = student['enrolled_subjects'];
      if (enrolledField is List) {
        for (final item in enrolledField) {
          if (item != null) involvedSubjectIds.add(item.toString());
        }
      } else if (enrolledField is String && enrolledField.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(enrolledField);
          if (decoded is List) {
            for (final item in decoded) {
              if (item != null) involvedSubjectIds.add(item.toString());
            }
          }
        } catch (_) {
          involvedSubjectIds.add(enrolledField.trim());
        }
      }

      // 2. Subjects referenced by student's actual quiz attempts
      for (final a in studentAttempts) {
        if (a['subject_id'] != null) {
          involvedSubjectIds.add(a['subject_id'].toString());
        }
      }

      // 3. Subjects referenced by student's actual assignment submissions
      for (final sub in studentSubmissions) {
        if (sub['subject_id'] != null) {
          involvedSubjectIds.add(sub['subject_id'].toString());
        } else {
          final aId = sub['assignment_id']?.toString();
          if (aId != null && assignmentsMap.containsKey(aId)) {
            final subSubjectId = assignmentsMap[aId]!['subject_id']?.toString();
            if (subSubjectId != null) involvedSubjectIds.add(subSubjectId);
          }
        }
      }

      final List<SubjectGradeRecord> subjectRecords = [];

      for (final subId in involvedSubjectIds) {
        final subMeta = subjectsMap[subId] ?? {};
        final subName = subMeta['name']?.toString() ?? 'Subject $subId';
        final subCode = subMeta['subject_code']?.toString() ?? 'SUB-$subId';
        final teacher =
            subMeta['teacher_name']?.toString() ?? 'Faculty Instructor';

        final subjectAttempts = studentAttempts
            .where((a) => a['subject_id']?.toString() == subId)
            .toList();

        final subjectSubmissions = studentSubmissions.where((sub) {
          if (sub['subject_id']?.toString() == subId) return true;
          final aId = sub['assignment_id']?.toString();
          return aId != null &&
              assignmentsMap[aId]?['subject_id']?.toString() == subId;
        }).toList();

        final List<AssessmentItemRecord> subjectAssessments = [];

        // Build item records for quiz attempts
        for (final a in subjectAttempts) {
          final qId = a['quiz_id']?.toString() ?? '';
          final qMeta = quizzesMap[qId] ?? {};
          final qTitle =
              a['quiz_title']?.toString() ??
              qMeta['title']?.toString() ??
              'Quiz ($qId)';

          final score = (a['score'] as num?)?.toDouble() ?? 0.0;
          final totalQuestions =
              (a['total_questions'] as num?)?.toDouble() ??
              (qMeta['total_questions'] as num?)?.toDouble() ??
              (qMeta['max_score'] as num?)?.toDouble() ??
              10.0;

          double pct = 0.0;
          if (a['percentage'] is num) {
            pct = (a['percentage'] as num).toDouble();
          } else if (totalQuestions > 0) {
            pct = (score / totalQuestions) * 100.0;
          }

          DateTime ts = DateTime.now();
          final rawTs = a['created_at'] ?? a['timestamp'];
          if (rawTs is Timestamp) {
            ts = rawTs.toDate();
          } else if (rawTs != null) {
            ts = DateTime.tryParse(rawTs.toString()) ?? DateTime.now();
          }

          subjectAssessments.add(
            AssessmentItemRecord(
              itemType: 'Quiz',
              title: qTitle,
              maxPoints: totalQuestions,
              score: score,
              percentage: double.parse(pct.toStringAsFixed(2)),
              status: 'graded',
              timestamp: ts,
              subjectId: subId,
              subjectCode: subCode,
              subjectName: subName,
            ),
          );
        }

        // Build item records for assignment submissions
        for (final sub in subjectSubmissions) {
          final aId = sub['assignment_id']?.toString() ?? '';
          final aMeta = assignmentsMap[aId] ?? {};
          final aTitle =
              sub['title']?.toString() ??
              aMeta['title']?.toString() ??
              'Assignment ($aId)';

          final maxPoints =
              (aMeta['max_score'] as num?)?.toDouble() ??
              (aMeta['total_points'] as num?)?.toDouble() ??
              100.0;

          final score =
              (sub['grade'] as num?)?.toDouble() ??
              (sub['score'] as num?)?.toDouble() ??
              0.0;

          final pct = maxPoints > 0 ? (score / maxPoints) * 100.0 : score;
          final statusStr =
              sub['status']?.toString().toLowerCase() ?? 'submitted';
          final effectiveStatus = statusStr == 'graded' || sub['grade'] != null
              ? 'graded'
              : 'submitted';

          DateTime ts = DateTime.now();
          final rawTs =
              sub['submitted_at'] ?? sub['created_at'] ?? sub['timestamp'];
          if (rawTs is Timestamp) {
            ts = rawTs.toDate();
          } else if (rawTs != null) {
            ts = DateTime.tryParse(rawTs.toString()) ?? DateTime.now();
          }

          subjectAssessments.add(
            AssessmentItemRecord(
              itemType: 'Assignment',
              title: aTitle,
              maxPoints: maxPoints,
              score: score,
              percentage: double.parse(pct.toStringAsFixed(2)),
              status: effectiveStatus,
              timestamp: ts,
              subjectId: subId,
              subjectCode: subCode,
              subjectName: subName,
            ),
          );
        }

        final quizScores = subjectAssessments
            .where((item) => item.itemType == 'Quiz')
            .map((item) => item.percentage)
            .toList();

        final asgnGrades = subjectAssessments
            .where((item) => item.itemType == 'Assignment')
            .map((item) => item.percentage)
            .toList();

        double avgScore = 0.0;
        if (quizScores.isNotEmpty && asgnGrades.isNotEmpty) {
          final qAvg = quizScores.reduce((a, b) => a + b) / quizScores.length;
          final aAvg = asgnGrades.reduce((a, b) => a + b) / asgnGrades.length;
          avgScore = (qAvg + aAvg) / 2.0;
        } else if (quizScores.isNotEmpty) {
          avgScore = quizScores.reduce((a, b) => a + b) / quizScores.length;
        } else if (asgnGrades.isNotEmpty) {
          avgScore = asgnGrades.reduce((a, b) => a + b) / asgnGrades.length;
        }

        subjectRecords.add(
          SubjectGradeRecord(
            subjectId: subId,
            subjectName: subName,
            subjectCode: subCode,
            teacherName: teacher,
            quizScores: quizScores,
            assignmentGrades: asgnGrades,
            assessments: subjectAssessments,
            averageScore: double.parse(avgScore.toStringAsFixed(2)),
            isPassed: avgScore >= 75.0,
          ),
        );
      }

      final double gpa = subjectRecords.isNotEmpty
          ? double.parse(
              (subjectRecords
                          .map((s) => s.averageScore)
                          .reduce((a, b) => a + b) /
                      subjectRecords.length)
                  .toStringAsFixed(2),
            )
          : 0.0;

      final allAssessments = subjectRecords
          .expand((s) => s.assessments)
          .toList();
      final totalTaken = allAssessments.length;
      final totalPassed = allAssessments
          .where((item) => item.percentage >= 75.0)
          .length;
      final totalQuizzes = allAssessments
          .where((item) => item.itemType == 'Quiz')
          .length;
      final totalAssignments = allAssessments
          .where((item) => item.itemType == 'Assignment')
          .length;

      final achievements = AcademicAchievementRecord.fromMetrics(
        gpa: gpa,
        totalAssessmentsTaken: totalTaken,
        totalAssessmentsPassed: totalPassed,
        competenciesMasteredCount: studentCompletedLos.length,
        totalQuizzesCompleted: totalQuizzes,
        totalAssignmentsSubmitted: totalAssignments,
      );

      archiveRecords.add(
        StudentArchiveRecord(
          studentId: sId,
          fullName: fullName,
          email: email,
          section: section,
          gradeLevel: gradeLevel,
          studentType: studentType,
          schoolId: schoolId,
          status: status,
          specialNotes: specialNotes,
          grades: subjectRecords,
          achievements: achievements,
        ),
      );
    }

    archiveRecords.sort((a, b) => a.fullName.compareTo(b.fullName));
    return archiveRecords;
  }

  @override
  Future<Uint8List> generateExcelWorkbook(
    List<StudentArchiveRecord> records, {
    String? academicYear,
    String? semester,
  }) async {
    final xlsio.Workbook workbook = xlsio.Workbook();

    // ── Sheet 1: Student Personal Info ──────────────────────────────────────
    final xlsio.Worksheet sheet1 = workbook.worksheets[0];
    sheet1.name = 'Student Personal Info';
    sheet1.enableSheetCalculations();

    final List<String> sheet1Headers = [
      'Student ID',
      'Full Name',
      'Email',
      'Section',
      'Grade Level',
      'Student Type',
      'School ID',
      'Status',
    ];

    for (int col = 0; col < sheet1Headers.length; col++) {
      final cell = sheet1.getRangeByIndex(1, col + 1);
      cell.setText(sheet1Headers[col]);
      cell.cellStyle.bold = true;
      cell.cellStyle.backColor = '#0F172A';
      cell.cellStyle.fontColor = '#FFFFFF';
    }

    int rowIdx1 = 2;
    for (final s in records) {
      sheet1.getRangeByIndex(rowIdx1, 1).setText(s.studentId);
      sheet1.getRangeByIndex(rowIdx1, 2).setText(s.fullName);
      sheet1.getRangeByIndex(rowIdx1, 3).setText(s.email);
      sheet1.getRangeByIndex(rowIdx1, 4).setText(s.section);
      sheet1.getRangeByIndex(rowIdx1, 5).setText(s.gradeLevel);
      sheet1.getRangeByIndex(rowIdx1, 6).setText(s.studentType.toUpperCase());
      sheet1.getRangeByIndex(rowIdx1, 7).setText(s.schoolId);
      sheet1.getRangeByIndex(rowIdx1, 8).setText(s.status.toUpperCase());
      rowIdx1++;
    }

    // ── Sheet 2: Semester Grades & Achievements ─────────────────────────────
    final xlsio.Worksheet sheet2 = workbook.worksheets.addWithName(
      'Semester Grades & Achievements',
    );
    sheet2.enableSheetCalculations();

    final List<String> sheet2Headers = [
      'Student ID',
      'Full Name',
      'Section',
      'Grade Level',
      'GPA',
      'Honors Title',
      'Quizzes Taken',
      'Assignments Submitted',
      'Assessments Passed',
      'Per-Subject Final Grades',
    ];

    for (int col = 0; col < sheet2Headers.length; col++) {
      final cell = sheet2.getRangeByIndex(1, col + 1);
      cell.setText(sheet2Headers[col]);
      cell.cellStyle.bold = true;
      cell.cellStyle.backColor = '#0F172A';
      cell.cellStyle.fontColor = '#FFFFFF';
    }

    int rowIdx2 = 2;
    for (final s in records) {
      final perSubjectStr = s.grades.isEmpty
          ? 'No subjects enrolled'
          : s.grades
                .map(
                  (g) =>
                      '${g.subjectName} (${g.subjectCode}): ${g.averageScore.toStringAsFixed(1)}% [${g.isPassed ? "PASSED" : "FAILED"}]',
                )
                .join('; ');

      sheet2.getRangeByIndex(rowIdx2, 1).setText(s.studentId);
      sheet2.getRangeByIndex(rowIdx2, 2).setText(s.fullName);
      sheet2.getRangeByIndex(rowIdx2, 3).setText(s.section);
      sheet2.getRangeByIndex(rowIdx2, 4).setText(s.gradeLevel);
      sheet2.getRangeByIndex(rowIdx2, 5).setNumber(s.achievements.gpa);
      sheet2.getRangeByIndex(rowIdx2, 6).setText(s.achievements.honorsTitle);
      sheet2
          .getRangeByIndex(rowIdx2, 7)
          .setNumber(s.achievements.totalQuizzesCompleted.toDouble());
      sheet2
          .getRangeByIndex(rowIdx2, 8)
          .setNumber(s.achievements.totalAssignmentsSubmitted.toDouble());
      sheet2
          .getRangeByIndex(rowIdx2, 9)
          .setNumber(s.achievements.totalAssessmentsPassed.toDouble());
      sheet2.getRangeByIndex(rowIdx2, 10).setText(perSubjectStr);
      rowIdx2++;
    }

    // ── Sheet 3: Subjects, Assignments & Quizzes ────────────────────────────
    final xlsio.Worksheet sheet3 = workbook.worksheets.addWithName(
      'Subjects, Assignments & Quizzes',
    );
    sheet3.enableSheetCalculations();

    final List<String> sheet3Headers = [
      'Student ID',
      'Full Name',
      'Section',
      'Subject Code',
      'Subject Name',
      'Teacher Name',
      'Item Type',
      'Item Title',
      'Max Points',
      'Score',
      'Percentage',
      'Status',
      'Timestamp',
    ];

    for (int col = 0; col < sheet3Headers.length; col++) {
      final cell = sheet3.getRangeByIndex(1, col + 1);
      cell.setText(sheet3Headers[col]);
      cell.cellStyle.bold = true;
      cell.cellStyle.backColor = '#0F172A';
      cell.cellStyle.fontColor = '#FFFFFF';
    }

    int rowIdx3 = 2;
    for (final s in records) {
      if (s.grades.isEmpty) {
        sheet3.getRangeByIndex(rowIdx3, 1).setText(s.studentId);
        sheet3.getRangeByIndex(rowIdx3, 2).setText(s.fullName);
        sheet3.getRangeByIndex(rowIdx3, 3).setText(s.section);
        sheet3.getRangeByIndex(rowIdx3, 4).setText('N/A');
        sheet3.getRangeByIndex(rowIdx3, 5).setText('No Enrolled Subjects');
        sheet3.getRangeByIndex(rowIdx3, 6).setText('N/A');
        sheet3.getRangeByIndex(rowIdx3, 7).setText('None');
        sheet3.getRangeByIndex(rowIdx3, 8).setText('None');
        sheet3.getRangeByIndex(rowIdx3, 9).setNumber(0);
        sheet3.getRangeByIndex(rowIdx3, 10).setNumber(0);
        sheet3.getRangeByIndex(rowIdx3, 11).setNumber(0);
        sheet3.getRangeByIndex(rowIdx3, 12).setText('N/A');
        sheet3.getRangeByIndex(rowIdx3, 13).setText('');
        rowIdx3++;
      } else {
        for (final grade in s.grades) {
          if (grade.assessments.isEmpty) {
            sheet3.getRangeByIndex(rowIdx3, 1).setText(s.studentId);
            sheet3.getRangeByIndex(rowIdx3, 2).setText(s.fullName);
            sheet3.getRangeByIndex(rowIdx3, 3).setText(s.section);
            sheet3.getRangeByIndex(rowIdx3, 4).setText(grade.subjectCode);
            sheet3.getRangeByIndex(rowIdx3, 5).setText(grade.subjectName);
            sheet3.getRangeByIndex(rowIdx3, 6).setText(grade.teacherName);
            sheet3.getRangeByIndex(rowIdx3, 7).setText('Enrolled Subject');
            sheet3.getRangeByIndex(rowIdx3, 8).setText('No Graded Items');
            sheet3.getRangeByIndex(rowIdx3, 9).setNumber(0);
            sheet3.getRangeByIndex(rowIdx3, 10).setNumber(0);
            sheet3.getRangeByIndex(rowIdx3, 11).setNumber(grade.averageScore);
            sheet3
                .getRangeByIndex(rowIdx3, 12)
                .setText(grade.isPassed ? 'PASSED' : 'PENDING');
            sheet3.getRangeByIndex(rowIdx3, 13).setText('');
            rowIdx3++;
          } else {
            for (final item in grade.assessments) {
              sheet3.getRangeByIndex(rowIdx3, 1).setText(s.studentId);
              sheet3.getRangeByIndex(rowIdx3, 2).setText(s.fullName);
              sheet3.getRangeByIndex(rowIdx3, 3).setText(s.section);
              sheet3.getRangeByIndex(rowIdx3, 4).setText(grade.subjectCode);
              sheet3.getRangeByIndex(rowIdx3, 5).setText(grade.subjectName);
              sheet3.getRangeByIndex(rowIdx3, 6).setText(grade.teacherName);
              sheet3.getRangeByIndex(rowIdx3, 7).setText(item.itemType);
              sheet3.getRangeByIndex(rowIdx3, 8).setText(item.title);
              sheet3.getRangeByIndex(rowIdx3, 9).setNumber(item.maxPoints);
              sheet3.getRangeByIndex(rowIdx3, 10).setNumber(item.score);
              sheet3.getRangeByIndex(rowIdx3, 11).setNumber(item.percentage);
              sheet3.getRangeByIndex(rowIdx3, 12).setText(item.status);
              sheet3
                  .getRangeByIndex(rowIdx3, 13)
                  .setText(
                    item.timestamp
                        .toIso8601String()
                        .substring(0, 19)
                        .replaceAll('T', ' '),
                  );
              rowIdx3++;
            }
          }
        }
      }
    }

    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();
    return Uint8List.fromList(bytes);
  }

  @override
  Future<Uint8List> generateExcelZipArchive({
    List<StudentArchiveRecord>? records,
    String? academicYear,
    String? semester,
  }) async {
    final studentRecords = records ?? await fetchAllStudentRecords();
    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final ay = (academicYear ?? 'AY2025-2026').replaceAll(' ', '_');
    final sem = (semester ?? '1stSemester').replaceAll(' ', '_');

    final archive = Archive();

    // 1. Generate Institution-Wide Master Workbook
    final masterBytes = await generateExcelWorkbook(
      studentRecords,
      academicYear: ay,
      semester: sem,
    );
    final masterFileName = 'CampusRecords_${ay}_${sem}_$dateStr.xlsx';
    archive.addFile(
      ArchiveFile(masterFileName, masterBytes.length, masterBytes),
    );

    // 2. Generate Section-Grouped Workbooks
    final sectionsMap = <String, List<StudentArchiveRecord>>{};
    for (final r in studentRecords) {
      final sec = r.section.trim().isEmpty ? 'Unassigned' : r.section.trim();
      sectionsMap.putIfAbsent(sec, () => []).add(r);
    }

    for (final entry in sectionsMap.entries) {
      final sectionRecords = entry.value;
      final sectionBytes = await generateExcelWorkbook(
        sectionRecords,
        academicYear: ay,
        semester: sem,
      );
      final sanitizedSection = entry.key.replaceAll(RegExp(r'[^\w\-]'), '_');
      final sectionFileName =
          'By_Section/CampusRecords_${sanitizedSection}_$dateStr.xlsx';
      archive.addFile(
        ArchiveFile(sectionFileName, sectionBytes.length, sectionBytes),
      );
    }

    final zipBytes = ZipEncoder().encode(archive);
    return Uint8List.fromList(zipBytes);
  }

  @override
  ArchiveVerificationResult verifyZipArchive(
    Uint8List zipBytes, [
    int expectedStudentCount = 0,
  ]) {
    if (expectedStudentCount < 0) {
      return ArchiveVerificationResult(
        isValid: false,
        studentCount: expectedStudentCount,
        byteLength: zipBytes.length,
        fileCount: 0,
        checksum: sha256.convert(zipBytes).toString(),
        errorMessage: 'Invalid expected student count: $expectedStudentCount',
        zipBytes: zipBytes,
      );
    }

    if (zipBytes.length < 4) {
      return ArchiveVerificationResult(
        isValid: false,
        studentCount: 0,
        byteLength: zipBytes.length,
        fileCount: 0,
        checksum: sha256.convert(zipBytes).toString(),
        errorMessage: 'ZIP byte buffer is empty or too short (< 4 bytes)',
        zipBytes: zipBytes,
      );
    }

    // Check magic bytes PK\x03\x04
    if (zipBytes[0] != 0x50 ||
        zipBytes[1] != 0x4B ||
        zipBytes[2] != 0x03 ||
        zipBytes[3] != 0x04) {
      return ArchiveVerificationResult(
        isValid: false,
        studentCount: 0,
        byteLength: zipBytes.length,
        fileCount: 0,
        checksum: sha256.convert(zipBytes).toString(),
        errorMessage: 'Invalid ZIP header: magic bytes PK\\x03\\x04 not found',
        zipBytes: zipBytes,
      );
    }

    try {
      final archive = ZipDecoder().decodeBytes(zipBytes);
      final xlsxFiles = archive.files
          .where((f) => f.name.endsWith('.xlsx'))
          .toList();

      if (xlsxFiles.isEmpty) {
        return ArchiveVerificationResult(
          isValid: false,
          studentCount: 0,
          byteLength: zipBytes.length,
          fileCount: 0,
          checksum: sha256.convert(zipBytes).toString(),
          errorMessage: 'ZIP archive contains zero .xlsx workbook files',
          zipBytes: zipBytes,
        );
      }

      for (final f in xlsxFiles) {
        if (f.size == 0) {
          return ArchiveVerificationResult(
            isValid: false,
            studentCount: 0,
            byteLength: zipBytes.length,
            fileCount: xlsxFiles.length,
            checksum: sha256.convert(zipBytes).toString(),
            errorMessage: 'Empty workbook file entry found: ${f.name}',
            zipBytes: zipBytes,
          );
        }
      }

      final checksum = sha256.convert(zipBytes).toString();
      return ArchiveVerificationResult(
        isValid: true,
        studentCount: expectedStudentCount,
        byteLength: zipBytes.length,
        fileCount: xlsxFiles.length,
        checksum: checksum,
        errorMessage: null,
        zipBytes: zipBytes,
      );
    } catch (e) {
      return ArchiveVerificationResult(
        isValid: false,
        studentCount: 0,
        byteLength: zipBytes.length,
        fileCount: 0,
        checksum: sha256.convert(zipBytes).toString(),
        errorMessage: 'Corrupt or unparseable ZIP archive: $e',
        zipBytes: zipBytes,
      );
    }
  }

  @override
  Future<Uint8List> generatePdfArchive(
    List<StudentArchiveRecord> records,
  ) async {
    final PdfDocument document = PdfDocument();
    document.pageSettings.margins.all = 36;
    document.pageSettings.size = PdfPageSize.a4;

    document.documentInformation.title = 'AIRAMP Semester-End Academic Archive';
    document.documentInformation.subject =
        'AIRAMP_STUDENT_COUNT:${records.length}';
    document.documentInformation.author = 'AIRAMP Campus Admin';

    final primaryBrush = PdfSolidBrush(PdfColor(15, 23, 42));
    final textDarkBrush = PdfSolidBrush(PdfColor(30, 41, 59));
    final whiteBrush = PdfSolidBrush(PdfColor(255, 255, 255));
    final passBrush = PdfSolidBrush(PdfColor(22, 101, 52));
    final failBrush = PdfSolidBrush(PdfColor(185, 28, 28));

    final titleFont = PdfStandardFont(
      PdfFontFamily.helvetica,
      16,
      style: PdfFontStyle.bold,
    );
    final headerFont = PdfStandardFont(
      PdfFontFamily.helvetica,
      11,
      style: PdfFontStyle.bold,
    );
    final regularFont = PdfStandardFont(PdfFontFamily.helvetica, 9);
    final regularBold = PdfStandardFont(
      PdfFontFamily.helvetica,
      9,
      style: PdfFontStyle.bold,
    );
    final smallFont = PdfStandardFont(PdfFontFamily.helvetica, 8);

    if (records.isEmpty) {
      final page = document.pages.add();
      final pSize = page.getClientSize();
      page.graphics.drawRectangle(
        brush: primaryBrush,
        bounds: Rect.fromLTWH(0, 0, pSize.width, 45),
      );
      page.graphics.drawString(
        'AIRA ACADEMIC MANAGEMENT SYSTEM',
        titleFont,
        brush: whiteBrush,
        bounds: Rect.fromLTWH(10, 12, pSize.width - 20, 25),
      );
      page.graphics.drawString(
        'No student records found for archiving.',
        regularFont,
        brush: textDarkBrush,
        bounds: Rect.fromLTWH(0, 70, pSize.width, 20),
      );
    } else {
      for (final student in records) {
        final page = document.pages.add();
        final pSize = page.getClientSize();

        // Institutional Top Header
        page.graphics.drawRectangle(
          brush: primaryBrush,
          bounds: Rect.fromLTWH(0, 0, pSize.width, 45),
        );
        page.graphics.drawString(
          'AIRA ACADEMIC MANAGEMENT SYSTEM',
          titleFont,
          brush: whiteBrush,
          bounds: Rect.fromLTWH(12, 8, pSize.width - 24, 20),
        );
        page.graphics.drawString(
          'OFFICIAL SEMESTER-END ACADEMIC RECORD ARCHIVE | PERMANENT INSTITUTIONAL LEDGER',
          smallFont,
          brush: whiteBrush,
          bounds: Rect.fromLTWH(12, 28, pSize.width - 24, 15),
        );

        // Student Information Card
        double currentY = 55;
        page.graphics.drawRectangle(
          brush: PdfSolidBrush(PdfColor(241, 245, 249)),
          pen: PdfPen(PdfColor(203, 213, 225), width: 1),
          bounds: Rect.fromLTWH(0, currentY, pSize.width, 50),
        );
        page.graphics.drawString(
          student.fullName.toUpperCase(),
          headerFont,
          brush: textDarkBrush,
          bounds: Rect.fromLTWH(10, currentY + 6, pSize.width - 20, 16),
        );
        page.graphics.drawString(
          'Student ID: ${student.studentId}   |   Section: ${student.section}   |   Grade Level: ${student.gradeLevel}   |   Type: ${student.studentType.toUpperCase()}',
          regularFont,
          brush: textDarkBrush,
          bounds: Rect.fromLTWH(10, currentY + 28, pSize.width - 20, 14),
        );

        // Academic Achievement Summary Card
        currentY += 58;
        page.graphics.drawRectangle(
          brush: PdfSolidBrush(PdfColor(248, 250, 252)),
          pen: PdfPen(PdfColor(226, 232, 240), width: 1),
          bounds: Rect.fromLTWH(0, currentY, pSize.width, 36),
        );
        page.graphics.drawString(
          'GPA: ${student.achievements.gpa.toStringAsFixed(2)}%   |   Honors: ${student.achievements.honorsTitle}   |   Assessments: ${student.achievements.totalAssessmentsPassed}/${student.achievements.totalAssessmentsTaken} Passed   |   Mastery: ${student.achievements.competenciesMasteredCount} LOs',
          regularBold,
          brush: primaryBrush,
          bounds: Rect.fromLTWH(10, currentY + 10, pSize.width - 20, 16),
        );

        // Subject Grades Transcript Table
        currentY += 46;
        final grid = PdfGrid();
        grid.columns.add(count: 6);
        grid.headers.add(1);

        final headerRow = grid.headers[0];
        headerRow.cells[0].value = 'Code';
        headerRow.cells[1].value = 'Subject Name';
        headerRow.cells[2].value = 'Teacher';
        headerRow.cells[3].value = 'Quizzes';
        headerRow.cells[4].value = 'Activities';
        headerRow.cells[5].value = 'Final Grade';

        headerRow.style = PdfGridCellStyle(
          backgroundBrush: primaryBrush,
          textBrush: whiteBrush,
          font: regularBold,
          cellPadding: PdfPaddings(left: 6, right: 6, top: 4, bottom: 4),
        );

        if (student.grades.isEmpty) {
          final row = grid.rows.add();
          row.cells[0].value = '-';
          row.cells[1].value = 'No enrolled subjects recorded for this term.';
          row.cells[2].value = '-';
          row.cells[3].value = '-';
          row.cells[4].value = '-';
          row.cells[5].value = 'N/A';
        } else {
          for (int i = 0; i < student.grades.length; i++) {
            final g = student.grades[i];
            final row = grid.rows.add();
            row.cells[0].value = g.subjectCode;
            row.cells[1].value = g.subjectName;
            row.cells[2].value = g.teacherName;
            row.cells[3].value = g.quizScores.isEmpty
                ? 'N/A'
                : '${g.quizAverage.toStringAsFixed(1)}%';
            row.cells[4].value = g.assignmentGrades.isEmpty
                ? 'N/A'
                : '${g.assignmentAverage.toStringAsFixed(1)}%';
            row.cells[5].value =
                '${g.averageScore.toStringAsFixed(1)}% (${g.isPassed ? "PASSED" : "FAILED"})';

            row.style = PdfGridCellStyle(
              backgroundBrush: i.isEven
                  ? PdfSolidBrush(PdfColor(255, 255, 255))
                  : PdfSolidBrush(PdfColor(248, 250, 252)),
              textBrush: g.isPassed ? passBrush : failBrush,
              font: regularFont,
              cellPadding: PdfPaddings(left: 6, right: 6, top: 4, bottom: 4),
            );
          }
        }

        grid.draw(
          page: page,
          bounds: Rect.fromLTWH(
            0,
            currentY,
            pSize.width,
            pSize.height - currentY - 30,
          ),
          format: PdfLayoutFormat(layoutType: PdfLayoutType.paginate),
        );

        // Security / Institutional Certification Footer
        page.graphics.drawString(
          'CERTIFIED AUTHENTIC BY CAMPUS REGISTRAR & SYSTEM ADMINISTRATION • SECURE SHA-256 DIGITAL LEDGER',
          smallFont,
          brush: textDarkBrush,
          bounds: Rect.fromLTWH(0, pSize.height - 20, pSize.width, 15),
        );
      }
    }

    final bytes = document.saveSync();
    document.dispose();
    return Uint8List.fromList(bytes);
  }

  @override
  ArchiveVerificationResult verifyPdfArchive(
    Uint8List pdfBytes,
    int expectedStudentCount,
  ) {
    if (pdfBytes.length < 5) {
      return ArchiveVerificationResult(
        isValid: false,
        studentCount: 0,
        byteLength: pdfBytes.length,
        checksum: sha256.convert(pdfBytes).toString(),
        errorMessage: 'PDF byte buffer is empty or too short (< 5 bytes)',
        pdfBytes: pdfBytes,
      );
    }

    final magicBytes = String.fromCharCodes(pdfBytes.sublist(0, 5));
    if (magicBytes != '%PDF-') {
      return ArchiveVerificationResult(
        isValid: false,
        studentCount: 0,
        byteLength: pdfBytes.length,
        checksum: sha256.convert(pdfBytes).toString(),
        errorMessage:
            'Invalid PDF magic bytes: missing %PDF- file header (found $magicBytes)',
        pdfBytes: pdfBytes,
      );
    }

    if (pdfBytes.length <= 1024) {
      return ArchiveVerificationResult(
        isValid: false,
        studentCount: 0,
        byteLength: pdfBytes.length,
        checksum: sha256.convert(pdfBytes).toString(),
        errorMessage:
            'PDF file size too small (${pdfBytes.length} bytes <= 1024 bytes minimum threshold)',
        pdfBytes: pdfBytes,
      );
    }

    if (expectedStudentCount < 0) {
      return ArchiveVerificationResult(
        isValid: false,
        studentCount: expectedStudentCount,
        byteLength: pdfBytes.length,
        checksum: sha256.convert(pdfBytes).toString(),
        errorMessage: 'Invalid expected student count: $expectedStudentCount',
        pdfBytes: pdfBytes,
      );
    }

    int pageCount = 0;
    int? archiveStudentCount;

    try {
      final doc = PdfDocument(inputBytes: pdfBytes);
      pageCount = doc.pages.count;
      final subject = doc.documentInformation.subject;
      if (subject.startsWith('AIRAMP_STUDENT_COUNT:')) {
        archiveStudentCount = int.tryParse(
          subject.substring('AIRAMP_STUDENT_COUNT:'.length),
        );
      }
      doc.dispose();

      if (pageCount == 0) {
        return ArchiveVerificationResult(
          isValid: false,
          studentCount: 0,
          byteLength: pdfBytes.length,
          checksum: sha256.convert(pdfBytes).toString(),
          errorMessage: 'PDF document contains 0 pages',
          pdfBytes: pdfBytes,
        );
      }
    } catch (e) {
      return ArchiveVerificationResult(
        isValid: false,
        studentCount: 0,
        byteLength: pdfBytes.length,
        checksum: sha256.convert(pdfBytes).toString(),
        errorMessage: 'Corrupt or unparseable PDF document: $e',
        pdfBytes: pdfBytes,
      );
    }

    if (archiveStudentCount != null &&
        archiveStudentCount != expectedStudentCount) {
      return ArchiveVerificationResult(
        isValid: false,
        studentCount: archiveStudentCount,
        byteLength: pdfBytes.length,
        checksum: sha256.convert(pdfBytes).toString(),
        errorMessage:
            'Student count mismatch: archive contains $archiveStudentCount students, expected $expectedStudentCount',
        pdfBytes: pdfBytes,
      );
    }

    final checksum = sha256.convert(pdfBytes).toString();
    return ArchiveVerificationResult(
      isValid: true,
      studentCount: expectedStudentCount,
      byteLength: pdfBytes.length,
      fileCount: pageCount,
      checksum: checksum,
      errorMessage: null,
      pdfBytes: pdfBytes,
    );
  }
}
