import 'dart:typed_data';

/// Represents an individual graded item (Quiz attempt or Assignment submission).
class AssessmentItemRecord {
  final String itemType; // 'Quiz' | 'Assignment'
  final String title;
  final double maxPoints;
  final double score;
  final double percentage;
  final String status; // 'graded' | 'submitted' | 'missing'
  final DateTime timestamp;
  final String? subjectId;
  final String? subjectCode;
  final String? subjectName;

  const AssessmentItemRecord({
    required this.itemType,
    required this.title,
    required this.maxPoints,
    required this.score,
    required this.percentage,
    required this.status,
    required this.timestamp,
    this.subjectId,
    this.subjectCode,
    this.subjectName,
  });

  Map<String, dynamic> toMap() => {
        'item_type': itemType,
        'title': title,
        'max_points': maxPoints,
        'score': score,
        'percentage': percentage,
        'status': status,
        'timestamp': timestamp.toIso8601String(),
        'subject_id': subjectId,
        'subject_code': subjectCode,
        'subject_name': subjectName,
      };

  factory AssessmentItemRecord.fromMap(Map<String, dynamic> map) {
    return AssessmentItemRecord(
      itemType: map['item_type']?.toString() ?? 'Quiz',
      title: map['title']?.toString() ?? 'Untitled Assessment',
      maxPoints: (map['max_points'] as num?)?.toDouble() ?? 100.0,
      score: (map['score'] as num?)?.toDouble() ?? 0.0,
      percentage: (map['percentage'] as num?)?.toDouble() ?? 0.0,
      status: map['status']?.toString() ?? 'graded',
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      subjectId: map['subject_id']?.toString(),
      subjectCode: map['subject_code']?.toString(),
      subjectName: map['subject_name']?.toString(),
    );
  }
}

/// Represents a student's completed academic performance in an individual subject.
class SubjectGradeRecord {
  final String subjectId;
  final String subjectName;
  final String subjectCode;
  final String teacherName;
  final List<double> quizScores;
  final List<double> assignmentGrades;
  final List<AssessmentItemRecord> assessments;
  final double averageScore;
  final bool isPassed;

  const SubjectGradeRecord({
    required this.subjectId,
    required this.subjectName,
    required this.subjectCode,
    required this.teacherName,
    this.quizScores = const [],
    this.assignmentGrades = const [],
    this.assessments = const [],
    required this.averageScore,
    required this.isPassed,
  });

  double get quizAverage => quizScores.isEmpty
      ? 0.0
      : quizScores.reduce((a, b) => a + b) / quizScores.length;

  double get assignmentAverage => assignmentGrades.isEmpty
      ? 0.0
      : assignmentGrades.reduce((a, b) => a + b) / assignmentGrades.length;

  double get finalGrade => averageScore;

  Map<String, dynamic> toMap() => {
        'subject_id': subjectId,
        'subject_name': subjectName,
        'subject_code': subjectCode,
        'teacher_name': teacherName,
        'quiz_scores': quizScores,
        'assignment_grades': assignmentGrades,
        'assessments': assessments.map((a) => a.toMap()).toList(),
        'average_score': averageScore,
        'is_passed': isPassed,
      };

  factory SubjectGradeRecord.fromMap(Map<String, dynamic> map) {
    return SubjectGradeRecord(
      subjectId: map['subject_id']?.toString() ?? '',
      subjectName: map['subject_name']?.toString() ?? '',
      subjectCode: map['subject_code']?.toString() ?? '',
      teacherName: map['teacher_name']?.toString() ?? 'Unassigned',
      quizScores: (map['quiz_scores'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          const [],
      assignmentGrades: (map['assignment_grades'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          const [],
      assessments: (map['assessments'] as List<dynamic>?)
              ?.map((e) => AssessmentItemRecord.fromMap(e as Map<String, dynamic>))
              .toList() ??
          const [],
      averageScore: (map['average_score'] as num?)?.toDouble() ?? 0.0,
      isPassed: map['is_passed'] == true || map['is_passed'] == 1,
    );
  }
}

/// Represents the holistic academic achievements and honors for a student for the semester.
class AcademicAchievementRecord {
  final double gpa;
  final int totalAssessmentsTaken;
  final int totalAssessmentsPassed;
  final int competenciesMasteredCount;
  final String honorsTitle;
  final int totalQuizzesCompleted;
  final int totalAssignmentsSubmitted;

  const AcademicAchievementRecord({
    required this.gpa,
    required this.totalAssessmentsTaken,
    required this.totalAssessmentsPassed,
    required this.competenciesMasteredCount,
    required this.honorsTitle,
    this.totalQuizzesCompleted = 0,
    this.totalAssignmentsSubmitted = 0,
  });

  static String computeHonorsTitle(double gpa) {
    if (gpa >= 98.0) return 'With Highest Honors';
    if (gpa >= 95.0) return 'With High Honors';
    if (gpa >= 90.0) return 'With Honors';
    if (gpa >= 75.0) return 'Passed';
    return 'Did Not Meet Expectations';
  }

  factory AcademicAchievementRecord.fromMetrics({
    required double gpa,
    required int totalAssessmentsTaken,
    required int totalAssessmentsPassed,
    required int competenciesMasteredCount,
    int totalQuizzesCompleted = 0,
    int totalAssignmentsSubmitted = 0,
  }) {
    return AcademicAchievementRecord(
      gpa: gpa,
      totalAssessmentsTaken: totalAssessmentsTaken,
      totalAssessmentsPassed: totalAssessmentsPassed,
      competenciesMasteredCount: competenciesMasteredCount,
      honorsTitle: computeHonorsTitle(gpa),
      totalQuizzesCompleted: totalQuizzesCompleted,
      totalAssignmentsSubmitted: totalAssignmentsSubmitted,
    );
  }

  Map<String, dynamic> toMap() => {
        'gpa': gpa,
        'total_assessments_taken': totalAssessmentsTaken,
        'total_assessments_passed': totalAssessmentsPassed,
        'competencies_mastered_count': competenciesMasteredCount,
        'honors_title': honorsTitle,
        'total_quizzes_completed': totalQuizzesCompleted,
        'total_assignments_submitted': totalAssignmentsSubmitted,
      };

  factory AcademicAchievementRecord.fromMap(Map<String, dynamic> map) {
    final gpaVal = (map['gpa'] as num?)?.toDouble() ?? 0.0;
    return AcademicAchievementRecord(
      gpa: gpaVal,
      totalAssessmentsTaken:
          (map['total_assessments_taken'] as num?)?.toInt() ?? 0,
      totalAssessmentsPassed:
          (map['total_assessments_passed'] as num?)?.toInt() ?? 0,
      competenciesMasteredCount:
          (map['competencies_mastered_count'] as num?)?.toInt() ?? 0,
      honorsTitle:
          map['honors_title']?.toString() ?? computeHonorsTitle(gpaVal),
      totalQuizzesCompleted:
          (map['total_quizzes_completed'] as num?)?.toInt() ?? 0,
      totalAssignmentsSubmitted:
          (map['total_assignments_submitted'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Complete student personal profile and semester transcript record.
class StudentArchiveRecord {
  final String studentId;
  final String fullName;
  final String section;
  final String gradeLevel;
  final String studentType;
  final String email;
  final String schoolId;
  final String status;
  final String? specialNotes;
  final List<SubjectGradeRecord> grades;
  final AcademicAchievementRecord achievements;

  const StudentArchiveRecord({
    required this.studentId,
    required this.fullName,
    required this.section,
    required this.gradeLevel,
    this.studentType = 'regular',
    this.email = '',
    this.schoolId = '',
    this.status = 'active',
    this.specialNotes,
    this.grades = const [],
    required this.achievements,
  });

  double get gpa => achievements.gpa;

  List<AssessmentItemRecord> get assessments =>
      grades.expand((g) => g.assessments).toList();

  Map<String, dynamic> toMap() => {
        'student_id': studentId,
        'full_name': fullName,
        'section': section,
        'grade_level': gradeLevel,
        'student_type': studentType,
        'email': email,
        'school_id': schoolId,
        'status': status,
        'special_notes': specialNotes,
        'grades': grades.map((g) => g.toMap()).toList(),
        'achievements': achievements.toMap(),
      };

  factory StudentArchiveRecord.fromMap(Map<String, dynamic> map) {
    return StudentArchiveRecord(
      studentId: map['student_id']?.toString() ?? '',
      fullName: map['full_name']?.toString() ?? '',
      section: map['section']?.toString() ?? 'Unassigned',
      gradeLevel: map['grade_level']?.toString() ?? 'N/A',
      studentType: map['student_type']?.toString() ?? 'regular',
      email: map['email']?.toString() ?? '',
      schoolId: map['school_id']?.toString() ?? '',
      status: map['status']?.toString() ?? 'active',
      specialNotes: map['special_notes']?.toString(),
      grades: (map['grades'] as List<dynamic>?)
              ?.map(
                  (g) => SubjectGradeRecord.fromMap(g as Map<String, dynamic>))
              .toList() ??
          const [],
      achievements: map['achievements'] != null
          ? AcademicAchievementRecord.fromMap(
              map['achievements'] as Map<String, dynamic>)
          : AcademicAchievementRecord.fromMetrics(
              gpa: 0.0,
              totalAssessmentsTaken: 0,
              totalAssessmentsPassed: 0,
              competenciesMasteredCount: 0,
            ),
    );
  }
}

/// Cryptographic and binary verification output for generated archive PDF or ZIP documents.
class ArchiveVerificationResult {
  final bool isValid;
  final int studentCount;
  final int byteLength;
  final int fileCount;
  final String checksum;
  final String? errorMessage;
  final Uint8List? pdfBytes;
  final Uint8List? zipBytes;

  const ArchiveVerificationResult({
    required this.isValid,
    required this.studentCount,
    required this.byteLength,
    this.fileCount = 1,
    required this.checksum,
    this.errorMessage,
    this.pdfBytes,
    this.zipBytes,
  });

  String get sha256Checksum => checksum;
  int get pageCount => fileCount;

  Map<String, dynamic> toMap() => {
        'is_valid': isValid,
        'student_count': studentCount,
        'byte_length': byteLength,
        'file_count': fileCount,
        'checksum': checksum,
        'error_message': errorMessage,
      };
}

/// Summary metrics generated upon executing a selective semester purge.
class PurgeSummary {
  final int deletedSubjectsCount;
  final int deletedModulesCount;
  final int deletedQuizzesCount;
  final int deletedAttemptsCount;
  final int deletedAssignmentsCount;
  final int deletedSubmissionsCount;
  final int preservedUsersCount;
  final DateTime executedAt;

  // Optional extended diagnostic breakdown
  final int deletedFlashcardsCount;
  final int deletedSchedulesCount;
  final int deletedEnrollmentKeysCount;
  final int resetStudentEnrollmentsCount;

  const PurgeSummary({
    required this.deletedSubjectsCount,
    required this.deletedModulesCount,
    required this.deletedQuizzesCount,
    required this.deletedAttemptsCount,
    required this.deletedAssignmentsCount,
    required this.deletedSubmissionsCount,
    required this.preservedUsersCount,
    required this.executedAt,
    this.deletedFlashcardsCount = 0,
    this.deletedSchedulesCount = 0,
    this.deletedEnrollmentKeysCount = 0,
    this.resetStudentEnrollmentsCount = 0,
  });

  int get totalDeletedAcademicRecords =>
      deletedSubjectsCount +
      deletedModulesCount +
      deletedQuizzesCount +
      deletedAttemptsCount +
      deletedAssignmentsCount +
      deletedSubmissionsCount +
      deletedFlashcardsCount +
      deletedSchedulesCount +
      deletedEnrollmentKeysCount;

  Map<String, dynamic> toMap() {
    return {
      'deleted_subjects_count': deletedSubjectsCount,
      'deleted_modules_count': deletedModulesCount,
      'deleted_quizzes_count': deletedQuizzesCount,
      'deleted_attempts_count': deletedAttemptsCount,
      'deleted_assignments_count': deletedAssignmentsCount,
      'deleted_submissions_count': deletedSubmissionsCount,
      'preserved_users_count': preservedUsersCount,
      'executed_at': executedAt.toIso8601String(),
      'deleted_flashcards_count': deletedFlashcardsCount,
      'deleted_schedules_count': deletedSchedulesCount,
      'deleted_enrollment_keys_count': deletedEnrollmentKeysCount,
      'reset_student_enrollments_count': resetStudentEnrollmentsCount,
    };
  }

  factory PurgeSummary.fromMap(Map<String, dynamic> map) {
    return PurgeSummary(
      deletedSubjectsCount:
          (map['deleted_subjects_count'] as num?)?.toInt() ?? 0,
      deletedModulesCount:
          (map['deleted_modules_count'] as num?)?.toInt() ?? 0,
      deletedQuizzesCount:
          (map['deleted_quizzes_count'] as num?)?.toInt() ?? 0,
      deletedAttemptsCount:
          (map['deleted_attempts_count'] as num?)?.toInt() ?? 0,
      deletedAssignmentsCount:
          (map['deleted_assignments_count'] as num?)?.toInt() ?? 0,
      deletedSubmissionsCount:
          (map['deleted_submissions_count'] as num?)?.toInt() ?? 0,
      preservedUsersCount:
          (map['preserved_users_count'] as num?)?.toInt() ?? 0,
      executedAt: map['executed_at'] != null
          ? DateTime.tryParse(map['executed_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      deletedFlashcardsCount:
          (map['deleted_flashcards_count'] as num?)?.toInt() ?? 0,
      deletedSchedulesCount:
          (map['deleted_schedules_count'] as num?)?.toInt() ?? 0,
      deletedEnrollmentKeysCount:
          (map['deleted_enrollment_keys_count'] as num?)?.toInt() ?? 0,
      resetStudentEnrollmentsCount:
          (map['reset_student_enrollments_count'] as num?)?.toInt() ?? 0,
    );
  }
}
