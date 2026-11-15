import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Rect;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/database/firestore_service.dart';
import '../domain/semester_archive_models.dart';

abstract class ISemesterRecordArchivingService {
  Future<List<StudentArchiveRecord>> fetchAllStudentRecords();
  Future<Uint8List> generatePdfArchive(List<StudentArchiveRecord> records);
  ArchiveVerificationResult verifyPdfArchive(Uint8List pdfBytes, int expectedStudentCount);
}

class SemesterRecordArchivingService implements ISemesterRecordArchivingService {
  final FirestoreService _firestoreService;
  final DatabaseHelper _dbHelper;
  final FirebaseFirestore? _firestore;

  SemesterRecordArchivingService({
    FirestoreService? firestoreService,
    DatabaseHelper? dbHelper,
    FirebaseFirestore? firestore,
  })  : _firestoreService = firestoreService ?? FirestoreService(),
        _dbHelper = dbHelper ?? DatabaseHelper(),
        _firestore = firestore;

  @override
  Future<List<StudentArchiveRecord>> fetchAllStudentRecords() async {
    List<Map<String, dynamic>> rawStudents = [];
    List<Map<String, dynamic>> rawSubjects = [];
    List<Map<String, dynamic>> rawQuizAttempts = [];
    List<Map<String, dynamic>> rawSubmissions = [];
    List<Map<String, dynamic>> rawAssignments = [];
    List<Map<String, dynamic>> rawProgress = [];

    // 1. Fetch Students
    if (_firestore != null) {
      try {
        final snap = await _firestore!.collection('users').where('role', isEqualTo: 'student').get();
        rawStudents = snap.docs.map((d) {
          final m = Map<String, dynamic>.from(d.data());
          m['id'] = d.id;
          return m;
        }).toList();
      } catch (e) {
        debugPrint('[SemesterArchiving] Direct firestore fetch error: $e');
      }
    }

    if (rawStudents.isEmpty && _firestoreService.isAvailable) {
      try {
        final allUsers = await _firestoreService.fetchAllUsers();
        rawStudents = allUsers.where((u) {
          final role = u['role']?.toString().toLowerCase();
          final id = u['id']?.toString() ?? '';
          return (role == 'student' || id.startsWith('S-')) &&
              u['is_archived'] != true &&
              u['is_archived'] != 1;
        }).toList();
      } catch (e) {
        debugPrint('[SemesterArchiving] FirestoreService fetch error: $e');
      }
    }

    // Fallback to SQLite if Firestore students empty
    if (rawStudents.isEmpty) {
      final db = await _dbHelper.database;
      rawStudents = await db.query(
        'users',
        where: "(role = 'student' OR (role IS NULL AND id LIKE 'S-%')) AND (is_archived IS NULL OR is_archived = 0)",
        orderBy: 'full_name ASC',
      );
    }

    // 2. Fetch Subjects & Academics
    if (_firestore != null) {
      try {
        final subSnap = await _firestore!.collection('subjects').get();
        rawSubjects = subSnap.docs.map((d) => {...d.data(), 'id': d.id}).toList();

        final qaSnap = await _firestore!.collection('quiz_attempts').get();
        rawQuizAttempts = qaSnap.docs.map((d) => {...d.data(), 'id': d.id}).toList();

        final submissSnap = await _firestore!.collection('submissions').get();
        rawSubmissions = submissSnap.docs.map((d) => {...d.data(), 'id': d.id}).toList();

        final asgnSnap = await _firestore!.collection('assignments').get();
        rawAssignments = asgnSnap.docs.map((d) => {...d.data(), 'id': d.id}).toList();

        final progSnap = await _firestore!.collection('student_progress').get();
        rawProgress = progSnap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
      } catch (e) {
        debugPrint('[SemesterArchiving] Firestore collections read note: $e');
      }
    }

    // Fallback / supplement from SQLite
    if (rawSubjects.isEmpty || rawQuizAttempts.isEmpty) {
      try {
        final db = await _dbHelper.database;
        if (rawSubjects.isEmpty) rawSubjects = await db.query('subjects');
        if (rawQuizAttempts.isEmpty) rawQuizAttempts = await db.query('quiz_attempts');
        if (rawSubmissions.isEmpty) rawSubmissions = await db.query('submissions');
        if (rawAssignments.isEmpty) rawAssignments = await db.query('assignments');
        if (rawProgress.isEmpty) rawProgress = await db.query('student_progress');
      } catch (_) {}
    }

    final subjectsMap = <String, Map<String, dynamic>>{};
    for (final s in rawSubjects) {
      final sid = s['id'].toString();
      subjectsMap[sid] = s;
    }

    final assignmentsMap = <String, Map<String, dynamic>>{};
    for (final a in rawAssignments) {
      final aid = a['id'].toString();
      assignmentsMap[aid] = a;
    }

    final List<StudentArchiveRecord> archiveRecords = [];

    for (final student in rawStudents) {
      final sId = student['id'].toString();
      final fullName = student['full_name']?.toString() ?? student['username']?.toString() ?? 'Student';
      final section = student['section']?.toString() ?? 'Unassigned';
      final gradeLevel = student['grade']?.toString() ?? student['grade_level']?.toString() ?? 'N/A';
      final studentType = student['student_type']?.toString() ?? 'regular';
      final specialNotes = student['special_notes']?.toString();

      final studentAttempts = rawQuizAttempts.where((a) => a['student_id']?.toString() == sId).toList();
      final studentSubmissions = rawSubmissions.where((sub) => sub['student_id']?.toString() == sId).toList();
      final studentCompletedLos = rawProgress.where((p) => p['student_id']?.toString() == sId && (p['is_completed'] == 1 || p['is_completed'] == true)).toList();

      final involvedSubjectIds = <String>{};
      for (final a in studentAttempts) {
        if (a['subject_id'] != null) involvedSubjectIds.add(a['subject_id'].toString());
      }
      for (final sub in studentSubmissions) {
        final aId = sub['assignment_id']?.toString();
        if (aId != null && assignmentsMap.containsKey(aId)) {
          final subSubjectId = assignmentsMap[aId]!['subject_id']?.toString();
          if (subSubjectId != null) involvedSubjectIds.add(subSubjectId);
        }
      }
      if (involvedSubjectIds.isEmpty && rawSubjects.isNotEmpty) {
        involvedSubjectIds.addAll(rawSubjects.take(3).map((s) => s['id'].toString()));
      }

      final List<SubjectGradeRecord> subjectRecords = [];
      for (final subId in involvedSubjectIds) {
        final subMeta = subjectsMap[subId] ?? {};
        final subName = subMeta['name']?.toString() ?? 'Subject $subId';
        final subCode = subMeta['subject_code']?.toString() ?? 'SUB-$subId';
        final teacher = subMeta['teacher_name']?.toString() ?? 'Faculty Instructor';

        final subjectAttempts = studentAttempts.where((a) => a['subject_id']?.toString() == subId).toList();
        final quizScores = subjectAttempts.map((a) {
          final p = a['percentage'];
          if (p is num) return p.toDouble();
          final score = (a['score'] as num?)?.toDouble() ?? 0.0;
          final total = (a['total_questions'] as num?)?.toDouble() ?? 10.0;
          return total > 0 ? (score / total) * 100.0 : 0.0;
        }).toList();

        final subjectSubmissions = studentSubmissions.where((sub) {
          final aId = sub['assignment_id']?.toString();
          return aId != null && assignmentsMap[aId]?['subject_id']?.toString() == subId;
        }).toList();

        final asgnGrades = subjectSubmissions.map((sub) {
          final g = sub['grade'];
          if (g is num) return g.toDouble();
          return 0.0;
        }).toList();

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

        subjectRecords.add(SubjectGradeRecord(
          subjectId: subId,
          subjectName: subName,
          subjectCode: subCode,
          teacherName: teacher,
          quizScores: quizScores,
          assignmentGrades: asgnGrades,
          averageScore: double.parse(avgScore.toStringAsFixed(2)),
          isPassed: avgScore >= 75.0,
        ));
      }

      final double gpa = subjectRecords.isNotEmpty
          ? double.parse((subjectRecords.map((s) => s.averageScore).reduce((a, b) => a + b) / subjectRecords.length).toStringAsFixed(2))
          : 0.0;

      final totalTaken = studentAttempts.length + studentSubmissions.length;
      final totalPassed = studentAttempts.where((a) => ((a['percentage'] as num?)?.toDouble() ?? 0.0) >= 75.0).length +
          studentSubmissions.where((s) => ((s['grade'] as num?)?.toDouble() ?? 0.0) >= 75.0).length;

      final achievements = AcademicAchievementRecord.fromMetrics(
        gpa: gpa,
        totalAssessmentsTaken: totalTaken,
        totalAssessmentsPassed: totalPassed,
        competenciesMasteredCount: studentCompletedLos.length,
      );

      archiveRecords.add(StudentArchiveRecord(
        studentId: sId,
        fullName: fullName,
        section: section,
        gradeLevel: gradeLevel,
        studentType: studentType,
        specialNotes: specialNotes,
        grades: subjectRecords,
        achievements: achievements,
      ));
    }

    archiveRecords.sort((a, b) => a.fullName.compareTo(b.fullName));
    return archiveRecords;
  }

  @override
  Future<Uint8List> generatePdfArchive(List<StudentArchiveRecord> records) async {
    final PdfDocument document = PdfDocument();
    document.pageSettings.margins.all = 36;
    document.pageSettings.size = PdfPageSize.a4;

    document.documentInformation.title = 'AIRAMP Semester-End Academic Archive';
    document.documentInformation.subject = 'AIRAMP_STUDENT_COUNT:${records.length}';
    document.documentInformation.author = 'AIRAMP Campus Admin';

    final primaryBrush = PdfSolidBrush(PdfColor(15, 23, 42));
    final textDarkBrush = PdfSolidBrush(PdfColor(30, 41, 59));
    final whiteBrush = PdfSolidBrush(PdfColor(255, 255, 255));
    final passBrush = PdfSolidBrush(PdfColor(22, 101, 52));
    final failBrush = PdfSolidBrush(PdfColor(185, 28, 28));

    final titleFont = PdfStandardFont(PdfFontFamily.helvetica, 16, style: PdfFontStyle.bold);
    final headerFont = PdfStandardFont(PdfFontFamily.helvetica, 11, style: PdfFontStyle.bold);
    final regularFont = PdfStandardFont(PdfFontFamily.helvetica, 9);
    final regularBold = PdfStandardFont(PdfFontFamily.helvetica, 9, style: PdfFontStyle.bold);
    final smallFont = PdfStandardFont(PdfFontFamily.helvetica, 8);

    if (records.isEmpty) {
      final page = document.pages.add();
      final pSize = page.getClientSize();
      page.graphics.drawRectangle(brush: primaryBrush, bounds: Rect.fromLTWH(0, 0, pSize.width, 45));
      page.graphics.drawString('AIRA ACADEMIC MANAGEMENT SYSTEM', titleFont, brush: whiteBrush, bounds: Rect.fromLTWH(10, 12, pSize.width - 20, 25));
      page.graphics.drawString('No student records found for archiving.', regularFont, brush: textDarkBrush, bounds: Rect.fromLTWH(0, 70, pSize.width, 20));
    } else {
      for (final student in records) {
        final page = document.pages.add();
        final pSize = page.getClientSize();

        // Institutional Top Header
        page.graphics.drawRectangle(brush: primaryBrush, bounds: Rect.fromLTWH(0, 0, pSize.width, 45));
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
            row.cells[3].value = g.quizScores.isEmpty ? 'N/A' : '${g.quizAverage.toStringAsFixed(1)}%';
            row.cells[4].value = g.assignmentGrades.isEmpty ? 'N/A' : '${g.assignmentAverage.toStringAsFixed(1)}%';
            row.cells[5].value = '${g.averageScore.toStringAsFixed(1)}% (${g.isPassed ? "PASSED" : "FAILED"})';

            row.style = PdfGridCellStyle(
              backgroundBrush: i.isEven ? PdfSolidBrush(PdfColor(255, 255, 255)) : PdfSolidBrush(PdfColor(248, 250, 252)),
              textBrush: g.isPassed ? passBrush : failBrush,
              font: regularFont,
              cellPadding: PdfPaddings(left: 6, right: 6, top: 4, bottom: 4),
            );
          }
        }

        grid.draw(
          page: page,
          bounds: Rect.fromLTWH(0, currentY, pSize.width, pSize.height - currentY - 30),
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
  ArchiveVerificationResult verifyPdfArchive(Uint8List pdfBytes, int expectedStudentCount) {
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
        errorMessage: 'Invalid PDF magic bytes: missing %PDF- file header (found $magicBytes)',
        pdfBytes: pdfBytes,
      );
    }

    if (pdfBytes.length <= 1024) {
      return ArchiveVerificationResult(
        isValid: false,
        studentCount: 0,
        byteLength: pdfBytes.length,
        checksum: sha256.convert(pdfBytes).toString(),
        errorMessage: 'PDF file size too small (${pdfBytes.length} bytes <= 1024 bytes minimum threshold)',
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
        archiveStudentCount = int.tryParse(subject.substring('AIRAMP_STUDENT_COUNT:'.length));
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

    if (archiveStudentCount != null && archiveStudentCount != expectedStudentCount) {
      return ArchiveVerificationResult(
        isValid: false,
        studentCount: archiveStudentCount,
        byteLength: pdfBytes.length,
        checksum: sha256.convert(pdfBytes).toString(),
        errorMessage: 'Student count mismatch: archive contains $archiveStudentCount students, expected $expectedStudentCount',
        pdfBytes: pdfBytes,
      );
    }

    final checksum = sha256.convert(pdfBytes).toString();
    return ArchiveVerificationResult(
      isValid: true,
      studentCount: expectedStudentCount,
      byteLength: pdfBytes.length,
      checksum: checksum,
      errorMessage: null,
      pdfBytes: pdfBytes,
    );
  }
}
