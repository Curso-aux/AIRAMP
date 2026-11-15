// Contract-Compliant Models and Opaque-Box Semester Renewal Service Engine
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:crypto/crypto.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'mock_semester_firestore_gateway.dart';

class SubjectGradeRecord {
  final String subjectId;
  final String subjectName;
  final double? quizAverage;
  final double? assignmentAverage;
  final double? finalGrade;

  const SubjectGradeRecord({
    required this.subjectId,
    required this.subjectName,
    this.quizAverage,
    this.assignmentAverage,
    this.finalGrade,
  });

  Map<String, dynamic> toMap() => {
        'subject_id': subjectId,
        'subject_name': subjectName,
        'quiz_average': quizAverage,
        'assignment_average': assignmentAverage,
        'final_grade': finalGrade,
      };
}

class AcademicAchievementRecord {
  final int totalQuizzesCompleted;
  final int totalAssignmentsSubmitted;
  final double gpa;
  final List<String> honorsOrAwards;

  const AcademicAchievementRecord({
    required this.totalQuizzesCompleted,
    required this.totalAssignmentsSubmitted,
    required this.gpa,
    required this.honorsOrAwards,
  });

  Map<String, dynamic> toMap() => {
        'total_quizzes_completed': totalQuizzesCompleted,
        'total_assignments_submitted': totalAssignmentsSubmitted,
        'gpa': gpa,
        'honors_or_awards': honorsOrAwards,
      };
}

class StudentArchiveRecord {
  final String studentId;
  final String fullName;
  final String section;
  final String gradeLevel;
  final String studentType;
  final List<SubjectGradeRecord> grades;
  final AcademicAchievementRecord achievements;

  const StudentArchiveRecord({
    required this.studentId,
    required this.fullName,
    required this.section,
    required this.gradeLevel,
    required this.studentType,
    required this.grades,
    required this.achievements,
  });

  Map<String, dynamic> toMap() => {
        'student_id': studentId,
        'full_name': fullName,
        'section': section,
        'grade_level': gradeLevel,
        'student_type': studentType,
        'grades': grades.map((g) => g.toMap()).toList(),
        'achievements': achievements.toMap(),
      };
}

class ArchiveVerificationResult {
  final bool isValid;
  final int studentCount;
  final int byteLength;
  final int pageCount;
  final String checksum;
  final String? errorMessage;
  final Uint8List pdfBytes;

  const ArchiveVerificationResult({
    required this.isValid,
    required this.studentCount,
    required this.byteLength,
    required this.pageCount,
    required this.checksum,
    this.errorMessage,
    required this.pdfBytes,
  });
}

class PurgeSummary {
  final int deletedSubjectsCount;
  final int deletedModulesCount;
  final int deletedQuizzesCount;
  final int deletedAttemptsCount;
  final int deletedAssignmentsCount;
  final int deletedSubmissionsCount;
  final int deletedFlashcardsCount;
  final int deletedSchedulesCount;
  final int deletedKeysCount;
  final int deletedLinksCount;
  final int preservedUsersCount;
  final DateTime executedAt;

  const PurgeSummary({
    required this.deletedSubjectsCount,
    required this.deletedModulesCount,
    required this.deletedQuizzesCount,
    required this.deletedAttemptsCount,
    required this.deletedAssignmentsCount,
    required this.deletedSubmissionsCount,
    required this.deletedFlashcardsCount,
    required this.deletedSchedulesCount,
    required this.deletedKeysCount,
    required this.deletedLinksCount,
    required this.preservedUsersCount,
    required this.executedAt,
  });

  int get totalDeletedRecords =>
      deletedSubjectsCount +
      deletedModulesCount +
      deletedQuizzesCount +
      deletedAttemptsCount +
      deletedAssignmentsCount +
      deletedSubmissionsCount +
      deletedFlashcardsCount +
      deletedSchedulesCount +
      deletedKeysCount +
      deletedLinksCount;

  Map<String, dynamic> toMap() => {
        'deleted_subjects': deletedSubjectsCount,
        'deleted_modules': deletedModulesCount,
        'deleted_quizzes': deletedQuizzesCount,
        'deleted_attempts': deletedAttemptsCount,
        'deleted_assignments': deletedAssignmentsCount,
        'deleted_submissions': deletedSubmissionsCount,
        'deleted_flashcards': deletedFlashcardsCount,
        'deleted_schedules': deletedSchedulesCount,
        'deleted_keys': deletedKeysCount,
        'deleted_links': deletedLinksCount,
        'preserved_users': preservedUsersCount,
        'total_deleted': totalDeletedRecords,
        'executed_at': executedAt.toUtc().toIso8601String(),
      };
}

class SemesterRenewalState {
  final bool isArchiveGenerating;
  final bool isArchiveVerified;
  final ArchiveVerificationResult? verificationResult;
  final bool isResetUnlocked;
  final bool isPurging;
  final PurgeSummary? purgeSummary;
  final String? errorMessage;

  const SemesterRenewalState({
    this.isArchiveGenerating = false,
    this.isArchiveVerified = false,
    this.verificationResult,
    this.isResetUnlocked = false,
    this.isPurging = false,
    this.purgeSummary,
    this.errorMessage,
  });

  SemesterRenewalState copyWith({
    bool? isArchiveGenerating,
    bool? isArchiveVerified,
    ArchiveVerificationResult? verificationResult,
    bool? isResetUnlocked,
    bool? isPurging,
    PurgeSummary? purgeSummary,
    String? errorMessage,
  }) {
    final verified = isArchiveVerified ?? this.isArchiveVerified;
    final res = verificationResult ?? this.verificationResult;
    final unlocked = isResetUnlocked ?? (verified && (res?.isValid == true));

    return SemesterRenewalState(
      isArchiveGenerating: isArchiveGenerating ?? this.isArchiveGenerating,
      isArchiveVerified: verified,
      verificationResult: res,
      isResetUnlocked: unlocked,
      isPurging: isPurging ?? this.isPurging,
      purgeSummary: purgeSummary ?? this.purgeSummary,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class SemesterRenewalService {
  final ISemesterFirestoreGateway gateway;
  static int _auditLogCounter = 0;

  const SemesterRenewalService(this.gateway);

  /// Queries all students, quiz attempts, and submissions to construct institutional archive records.
  Future<List<StudentArchiveRecord>> fetchAllStudentRecords() async {
    final users = await gateway.getCollection('users');
    final students = users.where((u) => u['role'] == 'student').toList();

    final allAttempts = await gateway.getCollection('quiz_attempts');
    final allSubmissions = await gateway.getCollection('submissions');
    final allSubjects = await gateway.getCollection('subjects');

    final subjectMap = {
      for (final s in allSubjects) s['id'] as String: s['name'] as String? ?? 'Subject'
    };

    final records = <StudentArchiveRecord>[];

    for (final student in students) {
      final studentId = student['id'] as String;
      final studentAttempts = allAttempts.where((a) => a['student_id'] == studentId).toList();
      final studentSubmissions = allSubmissions.where((s) => s['student_id'] == studentId).toList();

      // Group by subject
      final subjectIds = <String>{
        ...studentAttempts.map((a) => a['subject_id'] as String? ?? ''),
        ...studentSubmissions.map((s) => s['subject_id'] as String? ?? ''),
      }..remove('');

      final grades = <SubjectGradeRecord>[];
      for (final subjId in subjectIds) {
        final subAttempts = studentAttempts.where((a) => a['subject_id'] == subjId).toList();
        final subSubs = studentSubmissions.where((s) => s['subject_id'] == subjId).toList();

        double? quizAvg;
        if (subAttempts.isNotEmpty) {
          final total = subAttempts.fold<double>(0.0, (acc, a) => acc + ((a['score'] as num?)?.toDouble() ?? 0.0));
          quizAvg = total / subAttempts.length;
        }

        double? asgAvg;
        if (subSubs.isNotEmpty) {
          final total = subSubs.fold<double>(0.0, (acc, s) => acc + ((s['grade'] as num?)?.toDouble() ?? 0.0));
          asgAvg = total / subSubs.length;
        }

        double? finalGrade;
        if (quizAvg != null && asgAvg != null) {
          finalGrade = (quizAvg * 0.5) + (asgAvg * 0.5);
        } else {
          finalGrade = quizAvg ?? asgAvg;
        }

        grades.add(SubjectGradeRecord(
          subjectId: subjId,
          subjectName: subjectMap[subjId] ?? subjId,
          quizAverage: quizAvg,
          assignmentAverage: asgAvg,
          finalGrade: finalGrade,
        ));
      }

      // Calculate achievements
      final completedQuizzes = studentAttempts.where((a) => a['is_completed'] == 1 || a['is_completed'] == true).length;
      final submittedAsgs = studentSubmissions.length;
      double overallGpa = 0.0;
      if (grades.isNotEmpty) {
        final totalGrades = grades.fold<double>(0.0, (acc, g) => acc + (g.finalGrade ?? 0.0));
        overallGpa = totalGrades / grades.length;
      }

      final honors = <String>[];
      if (overallGpa >= 90.0) {
        honors.add('Academic Excellence Award');
      }
      if (completedQuizzes >= 3) {
        honors.add('Perfect Quiz Completion');
      }

      records.add(StudentArchiveRecord(
        studentId: studentId,
        fullName: student['full_name'] as String? ?? 'Unknown Student',
        section: student['section'] as String? ?? 'Unassigned',
        gradeLevel: student['grade_level'] as String? ?? 'N/A',
        studentType: student['student_type'] as String? ?? 'regular',
        grades: grades,
        achievements: AcademicAchievementRecord(
          totalQuizzesCompleted: completedQuizzes,
          totalAssignmentsSubmitted: submittedAsgs,
          gpa: overallGpa,
          honorsOrAwards: honors,
        ),
      ));
    }

    return records;
  }

  /// Compiles structured institutional PDF records using syncfusion_flutter_pdf.
  Future<Uint8List> generatePdfArchive(List<StudentArchiveRecord> records) async {
    final document = PdfDocument();
    document.pageSettings.margins.all = 36; // 0.5 inch

    final fontHeader = PdfStandardFont(PdfFontFamily.helvetica, 16, style: PdfFontStyle.bold);
    final fontSubheader = PdfStandardFont(PdfFontFamily.helvetica, 12, style: PdfFontStyle.bold);
    final fontRegular = PdfStandardFont(PdfFontFamily.helvetica, 10);
    final fontBold = PdfStandardFont(PdfFontFamily.helvetica, 10, style: PdfFontStyle.bold);

    for (final student in records) {
      final page = document.pages.add();
      final graphics = page.graphics;
      final pageSize = page.getClientSize();

      double y = 0;

      // Institutional Header
      graphics.drawString(
        'AIRAMP INSTITUTIONAL ACADEMIC ARCHIVE',
        fontHeader,
        bounds: Rect.fromLTWH(0, y, pageSize.width, 24),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );
      y += 24;

      graphics.drawString(
        'Permanent Semester-End Student Record',
        fontSubheader,
        bounds: Rect.fromLTWH(0, y, pageSize.width, 18),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );
      y += 24;

      // Divider line
      graphics.drawLine(
        PdfPen(PdfColor(100, 100, 100), width: 1.5),
        Offset(0, y),
        Offset(pageSize.width, y),
      );
      y += 12;

      // Student Information Section
      graphics.drawString('STUDENT PROFILE', fontBold, bounds: Rect.fromLTWH(0, y, pageSize.width, 16));
      y += 18;

      graphics.drawString('Institutional ID: ${student.studentId}', fontRegular, bounds: Rect.fromLTWH(0, y, 250, 14));
      graphics.drawString('Full Name: ${student.fullName}', fontRegular, bounds: Rect.fromLTWH(260, y, 250, 14));
      y += 16;

      graphics.drawString('Section: ${student.section}', fontRegular, bounds: Rect.fromLTWH(0, y, 250, 14));
      graphics.drawString('Grade Level: ${student.gradeLevel}', fontRegular, bounds: Rect.fromLTWH(260, y, 250, 14));
      y += 16;

      graphics.drawString('Student Type: ${student.studentType}', fontRegular, bounds: Rect.fromLTWH(0, y, 250, 14));
      y += 24;

      // Grades Table
      graphics.drawString('COMPLETED SEMESTER GRADES', fontBold, bounds: Rect.fromLTWH(0, y, pageSize.width, 16));
      y += 18;

      final grid = PdfGrid();
      grid.columns.add(count: 4);
      grid.headers.add(1);
      final headerRow = grid.headers[0];
      headerRow.cells[0].value = 'Subject Name';
      headerRow.cells[1].value = 'Quiz Avg';
      headerRow.cells[2].value = 'Assignment Avg';
      headerRow.cells[3].value = 'Final Grade';

      headerRow.style = PdfGridRowStyle(
        backgroundBrush: PdfSolidBrush(PdfColor(220, 230, 242)),
        textPen: PdfPen(PdfColor(0, 0, 0)),
        font: fontBold,
      );

      for (final grade in student.grades) {
        final row = grid.rows.add();
        row.cells[0].value = grade.subjectName;
        row.cells[1].value = grade.quizAverage != null ? grade.quizAverage!.toStringAsFixed(1) : 'N/A';
        row.cells[2].value = grade.assignmentAverage != null ? grade.assignmentAverage!.toStringAsFixed(1) : 'N/A';
        row.cells[3].value = grade.finalGrade != null ? grade.finalGrade!.toStringAsFixed(1) : 'N/A';
      }

      if (student.grades.isEmpty) {
        final row = grid.rows.add();
        row.cells[0].value = 'No completed subject records for this term';
        row.cells[1].value = '-';
        row.cells[2].value = '-';
        row.cells[3].value = '-';
      }

      final gridResult = grid.draw(page: page, bounds: Rect.fromLTWH(0, y, pageSize.width, 0));
      y = (gridResult?.bounds.bottom ?? y) + 20;

      // Academic Achievements Section
      graphics.drawString('ACADEMIC ACHIEVEMENTS & SUMMARY', fontBold, bounds: Rect.fromLTWH(0, y, pageSize.width, 16));
      y += 18;

      graphics.drawString('Total Quizzes Completed: ${student.achievements.totalQuizzesCompleted}', fontRegular, bounds: Rect.fromLTWH(0, y, 250, 14));
      graphics.drawString('Assignments Submitted: ${student.achievements.totalAssignmentsSubmitted}', fontRegular, bounds: Rect.fromLTWH(260, y, 250, 14));
      y += 16;

      graphics.drawString('Term GPA: ${student.achievements.gpa.toStringAsFixed(2)}', fontBold, bounds: Rect.fromLTWH(0, y, 250, 14));
      y += 16;

      final honorsText = student.achievements.honorsOrAwards.isNotEmpty
          ? student.achievements.honorsOrAwards.join(', ')
          : 'None recorded';
      graphics.drawString('Honors & Awards: $honorsText', fontRegular, bounds: Rect.fromLTWH(0, y, pageSize.width, 14));
    }

    final bytes = document.saveSync();
    document.dispose();
    return Uint8List.fromList(bytes);
  }

  /// Validates binary integrity, header signatures (%PDF-), page count, and expected student coverage.
  ArchiveVerificationResult verifyPdfArchive(Uint8List pdfBytes, int expectedStudentCount) {
    if (pdfBytes.isEmpty) {
      return ArchiveVerificationResult(
        isValid: false,
        studentCount: 0,
        byteLength: 0,
        pageCount: 0,
        checksum: '',
        errorMessage: 'Archive buffer is empty (0 bytes)',
        pdfBytes: pdfBytes,
      );
    }

    // Binary Signature Check: %PDF- (0x25, 0x50, 0x44, 0x46, 0x2D)
    if (pdfBytes.length < 5 ||
        pdfBytes[0] != 0x25 || // '%'
        pdfBytes[1] != 0x50 || // 'P'
        pdfBytes[2] != 0x44 || // 'D'
        pdfBytes[3] != 0x46 || // 'F'
        pdfBytes[4] != 0x2D) { // '-'
      return ArchiveVerificationResult(
        isValid: false,
        studentCount: 0,
        byteLength: pdfBytes.lengthInBytes,
        pageCount: 0,
        checksum: sha256.convert(pdfBytes).toString(),
        errorMessage: 'Invalid PDF magic bytes: header does not begin with %PDF-',
        pdfBytes: pdfBytes,
      );
    }

    // Load into Syncfusion parser to verify internal structure and page count
    int pageCount = 0;
    try {
      final doc = PdfDocument(inputBytes: pdfBytes);
      pageCount = doc.pages.count;
      doc.dispose();
    } catch (e) {
      return ArchiveVerificationResult(
        isValid: false,
        studentCount: 0,
        byteLength: pdfBytes.lengthInBytes,
        pageCount: 0,
        checksum: sha256.convert(pdfBytes).toString(),
        errorMessage: 'PDF structure corrupted: $e',
        pdfBytes: pdfBytes,
      );
    }

    if (expectedStudentCount > 0 && pageCount < expectedStudentCount) {
      return ArchiveVerificationResult(
        isValid: false,
        studentCount: pageCount,
        byteLength: pdfBytes.lengthInBytes,
        pageCount: pageCount,
        checksum: sha256.convert(pdfBytes).toString(),
        errorMessage: 'Archive page count ($pageCount) is less than expected student count ($expectedStudentCount)',
        pdfBytes: pdfBytes,
      );
    }

    final checksum = sha256.convert(pdfBytes).toString();
    return ArchiveVerificationResult(
      isValid: true,
      studentCount: expectedStudentCount,
      byteLength: pdfBytes.lengthInBytes,
      pageCount: pageCount,
      checksum: checksum,
      errorMessage: null,
      pdfBytes: pdfBytes,
    );
  }

  /// Verifies admin re-authentication password against stored salt and SHA-256 hash.
  Future<bool> verifyAdminCredentials({
    required String adminId,
    required String password,
  }) async {
    final admin = await gateway.getDocument('users', adminId);
    if (admin == null) return false;

    final storedHash = admin['password'] as String?;
    final salt = admin['password_salt'] as String?;
    if (storedHash == null) return false;

    if (salt == null || salt.isEmpty) {
      return password == storedHash;
    }

    final computed = sha256.convert(utf8.encode('$password::$salt')).toString();
    return computed == storedHash;
  }

  /// Executes selective database purge of transient academic data in batches <= 400 operations.
  /// Preserves user accounts, credentials, and base profiles (resetting student enrollment fields).
  Future<PurgeSummary> executeSelectivePurge({
    required String adminId,
    required String schoolId,
    required String adminPassword,
    required bool scopeReviewed,
    required bool acknowledgementChecked,
    required String confirmationPhrase,
    required bool isResetUnlocked,
  }) async {
    // Guardrail 1: Administrative reset trigger must be unlocked
    if (!isResetUnlocked) {
      throw StateError(
        'Semester reset is locked. Archive generation and verification must succeed before reset.',
      );
    }

    // Guardrail 2: Multi-step confirmation validation
    if (!scopeReviewed) {
      throw StateError('Confirmation sequence error: Data scope must be reviewed.');
    }
    if (!acknowledgementChecked) {
      throw StateError('Confirmation sequence error: Irreversibility acknowledgement must be checked.');
    }
    if (confirmationPhrase != 'CONFIRM SEMESTER RESET') {
      throw StateError('Confirmation sequence error: Confirmation phrase mismatch.');
    }

    // Guardrail 3: Admin re-authentication
    final isAuthenticated = await verifyAdminCredentials(
      adminId: adminId,
      password: adminPassword,
    );
    if (!isAuthenticated) {
      throw StateError('Administrative re-authentication failed: Invalid credentials.');
    }

    // Selective Purge: Transient collections
    final transientCollections = [
      'subjects',
      'modules',
      'quizzes',
      'quiz_assignments',
      'quiz_attempts',
      'assignments',
      'submissions',
      'module_flashcards',
      'class_schedules',
      'enrollment_keys',
      'reg_links',
    ];

    int delSubjects = 0;
    int delModules = 0;
    int delQuizzes = 0;
    int delAttempts = 0;
    int delAssignments = 0;
    int delSubmissions = 0;
    int delFlashcards = 0;
    int delSchedules = 0;
    int delKeys = 0;
    int delLinks = 0;

    // Collect all delete operations
    final deleteOperations = <FirestoreBatchOperation>[];

    for (final colName in transientCollections) {
      final docs = await gateway.getCollection(colName);
      for (final doc in docs) {
        final id = doc['id'] as String;
        deleteOperations.add(FirestoreBatchOperation.delete(colName, id));

        switch (colName) {
          case 'subjects':
            delSubjects++;
            break;
          case 'modules':
            delModules++;
            break;
          case 'quizzes':
            delQuizzes++;
            break;
          case 'quiz_assignments':
            break;
          case 'quiz_attempts':
            delAttempts++;
            break;
          case 'assignments':
            delAssignments++;
            break;
          case 'submissions':
            delSubmissions++;
            break;
          case 'module_flashcards':
            delFlashcards++;
            break;
          case 'class_schedules':
            delSchedules++;
            break;
          case 'enrollment_keys':
            delKeys++;
            break;
          case 'reg_links':
            delLinks++;
            break;
        }
      }
    }

    // Update students to reset enrollment fields (preserve account, clear subjects)
    final allUsers = await gateway.getCollection('users');
    final updateOperations = <FirestoreBatchOperation>[];
    for (final user in allUsers) {
      if (user['role'] == 'student') {
        updateOperations.add(FirestoreBatchOperation.update(
          'users',
          user['id'] as String,
          {
            'enrolled_subjects': <String>[],
            'enrolled_courses': 0,
          },
        ));
      }
    }

    // Chunk all operations into batches of <= 400 operations (guarding against Firestore's 500 limit)
    const int batchChunkSize = 400;
    final allOps = [...deleteOperations, ...updateOperations];

    for (var i = 0; i < allOps.length; i += batchChunkSize) {
      final end = (i + batchChunkSize < allOps.length) ? i + batchChunkSize : allOps.length;
      final chunk = allOps.sublist(i, end);
      await gateway.commitBatch(chunk);
    }

    final usersAfter = await gateway.getCollection('users');
    final summary = PurgeSummary(
      deletedSubjectsCount: delSubjects,
      deletedModulesCount: delModules,
      deletedQuizzesCount: delQuizzes,
      deletedAttemptsCount: delAttempts,
      deletedAssignmentsCount: delAssignments,
      deletedSubmissionsCount: delSubmissions,
      deletedFlashcardsCount: delFlashcards,
      deletedSchedulesCount: delSchedules,
      deletedKeysCount: delKeys,
      deletedLinksCount: delLinks,
      preservedUsersCount: usersAfter.length,
      executedAt: DateTime.now().toUtc(),
    );

    // Append audit log event with monotonic sequence suffix to prevent Windows clock tick collisions
    final auditSuffix = '${DateTime.now().microsecondsSinceEpoch}_${_auditLogCounter++}';
    await gateway.setDocument(
      'system_audit_logs',
      'AUDIT-$auditSuffix',
      {
        'event': 'SEMESTER_SELECTIVE_PURGE',
        'admin_id': adminId,
        'school_id': schoolId,
        'timestamp': summary.executedAt.toIso8601String(),
        'summary': summary.toMap(),
      },
    );

    return summary;
  }
}
