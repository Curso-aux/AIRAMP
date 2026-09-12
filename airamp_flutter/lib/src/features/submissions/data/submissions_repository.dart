import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_helper.dart';

class Assignment {
  final int id;
  final String title;
  final String? description;
  final int subjectId;
  final String teacherId;
  final String? teacherName;
  final String? dueDate;
  final int totalPoints;
  final String submissionType; // 'link', 'file', 'both'
  final String status;
  final String createdAt;
  final String? subjectName;
  final String? subjectCode;
  final int submissionCount;
  final int gradedCount;

  // Student specific context (if fetched for student)
  final int? submissionId;
  final String? studentSubmissionStatus;
  final double? studentGrade;
  final String? studentFeedback;
  final String? studentContentLink;
  final String? studentFileName;
  final int? studentFileSize;

  const Assignment({
    required this.id,
    required this.title,
    this.description,
    required this.subjectId,
    required this.teacherId,
    this.teacherName,
    this.dueDate,
    this.totalPoints = 100,
    this.submissionType = 'both',
    this.status = 'active',
    required this.createdAt,
    this.subjectName,
    this.subjectCode,
    this.submissionCount = 0,
    this.gradedCount = 0,
    this.submissionId,
    this.studentSubmissionStatus,
    this.studentGrade,
    this.studentFeedback,
    this.studentContentLink,
    this.studentFileName,
    this.studentFileSize,
  });

  factory Assignment.fromMap(Map<String, dynamic> map) {
    return Assignment(
      id: map['id'] as int,
      title: map['title'] as String? ?? 'Untitled Assignment',
      description: map['description'] as String?,
      subjectId: map['subject_id'] as int? ?? 0,
      teacherId: map['teacher_id'] as String? ?? '',
      teacherName: map['teacher_name'] as String?,
      dueDate: map['due_date'] as String?,
      totalPoints: (map['total_points'] as num?)?.toInt() ?? 100,
      submissionType: map['submission_type'] as String? ?? 'both',
      status: map['status'] as String? ?? 'active',
      createdAt: map['created_at'] as String? ?? '',
      subjectName: map['subject_name'] as String?,
      subjectCode: map['subject_code'] as String?,
      submissionCount: (map['submission_count'] as num?)?.toInt() ?? 0,
      gradedCount: (map['graded_count'] as num?)?.toInt() ?? 0,
      submissionId: map['submission_id'] as int?,
      studentSubmissionStatus: map['submission_status'] as String?,
      studentGrade: (map['grade'] as num?)?.toDouble(),
      studentFeedback: map['feedback'] as String?,
      studentContentLink: map['content_link'] as String?,
      studentFileName: map['file_name'] as String?,
      studentFileSize: (map['file_size'] as num?)?.toInt(),
    );
  }
}

class Submission {
  final int id;
  final int assignmentId;
  final String studentId;
  final String? studentName;
  final String? studentEmail;
  final String? studentSection;
  final String? studentGradeLevel;
  final String submissionType;
  final String? contentLink;
  final String? fileName;
  final int? fileSize;
  final String? filePath;
  final String? notes;
  final String submittedAt;
  final String status;
  final double? grade;
  final String? feedback;
  final String? gradedAt;
  final String? gradedBy;

  const Submission({
    required this.id,
    required this.assignmentId,
    required this.studentId,
    this.studentName,
    this.studentEmail,
    this.studentSection,
    this.studentGradeLevel,
    required this.submissionType,
    this.contentLink,
    this.fileName,
    this.fileSize,
    this.filePath,
    this.notes,
    required this.submittedAt,
    this.status = 'submitted',
    this.grade,
    this.feedback,
    this.gradedAt,
    this.gradedBy,
  });

  factory Submission.fromMap(Map<String, dynamic> map) {
    return Submission(
      id: map['id'] as int,
      assignmentId: map['assignment_id'] as int,
      studentId: map['student_id'] as String,
      studentName: map['student_name'] as String? ?? map['full_name'] as String?,
      studentEmail: map['email'] as String?,
      studentSection: map['section'] as String?,
      studentGradeLevel: map['student_grade_level'] as String? ?? map['grade'] as String?,
      submissionType: map['submission_type'] as String? ?? 'link',
      contentLink: map['content_link'] as String?,
      fileName: map['file_name'] as String?,
      fileSize: (map['file_size'] as num?)?.toInt(),
      filePath: map['file_path'] as String?,
      notes: map['notes'] as String?,
      submittedAt: map['submitted_at'] as String? ?? '',
      status: map['status'] as String? ?? 'submitted',
      grade: (map['grade'] is num) ? (map['grade'] as num).toDouble() : double.tryParse(map['grade']?.toString() ?? ''),
      feedback: map['feedback'] as String?,
      gradedAt: map['graded_at'] as String?,
      gradedBy: map['graded_by'] as String?,
    );
  }
}

class SubmissionsRepository {
  final DatabaseHelper _dbHelper;

  SubmissionsRepository(this._dbHelper);

  Future<Assignment?> getAssignmentById(int id) async {
    final map = await _dbHelper.getAssignmentById(id);
    if (map == null) return null;
    return Assignment.fromMap(map);
  }

  Future<List<Assignment>> getAssignmentsForSubject(int subjectId) async {
    final list = await _dbHelper.getAssignmentsForSubject(subjectId);
    return list.map((m) => Assignment.fromMap(m)).toList();
  }

  Future<List<Assignment>> getAssignmentsForStudent(String studentId, {int? subjectId}) async {
    final list = await _dbHelper.getAssignmentsForStudent(studentId, subjectId: subjectId);
    return list.map((m) => Assignment.fromMap(m)).toList();
  }

  Future<Submission?> getSubmission(int assignmentId, String studentId) async {
    final map = await _dbHelper.getSubmissionForAssignment(assignmentId, studentId);
    if (map == null) return null;
    return Submission.fromMap(map);
  }

  Future<List<Submission>> getSubmissionsForAssignment(int assignmentId) async {
    final list = await _dbHelper.getSubmissionsForAssignment(assignmentId);
    return list.map((m) => Submission.fromMap(m)).toList();
  }

  Future<int> createAssignment({
    required String title,
    String? description,
    required int subjectId,
    required String teacherId,
    String? teacherName,
    String? dueDate,
    int totalPoints = 100,
    String submissionType = 'both',
  }) {
    return _dbHelper.createAssignment(
      title: title,
      description: description,
      subjectId: subjectId,
      teacherId: teacherId,
      teacherName: teacherName,
      dueDate: dueDate,
      totalPoints: totalPoints,
      submissionType: submissionType,
    );
  }

  Future<int> submitAssignment({
    required int assignmentId,
    required String studentId,
    String? studentName,
    required String submissionType,
    String? contentLink,
    String? fileName,
    int? fileSize,
    String? filePath,
    String? notes,
  }) {
    return _dbHelper.submitAssignment(
      assignmentId: assignmentId,
      studentId: studentId,
      studentName: studentName,
      submissionType: submissionType,
      contentLink: contentLink,
      fileName: fileName,
      fileSize: fileSize,
      filePath: filePath,
      notes: notes,
    );
  }

  Future<int> gradeSubmission({
    required int submissionId,
    required double grade,
    String? feedback,
    String? gradedBy,
  }) {
    return _dbHelper.gradeSubmission(
      submissionId: submissionId,
      grade: grade,
      feedback: feedback,
      gradedBy: gradedBy,
    );
  }

  Future<int> deleteAssignment(int id) {
    return _dbHelper.deleteAssignment(id);
  }
}

// Providers
final submissionsRepositoryProvider = Provider<SubmissionsRepository>((ref) {
  return SubmissionsRepository(DatabaseHelper());
});

final assignmentDetailProvider = FutureProvider.family<Assignment?, int>((ref, assignmentId) async {
  final repo = ref.watch(submissionsRepositoryProvider);
  return repo.getAssignmentById(assignmentId);
});

final studentSubmissionProvider = FutureProvider.family<Submission?, ({int assignmentId, String studentId})>((ref, arg) async {
  final repo = ref.watch(submissionsRepositoryProvider);
  return repo.getSubmission(arg.assignmentId, arg.studentId);
});

final subjectAssignmentsProvider = FutureProvider.family<List<Assignment>, int>((ref, subjectId) async {
  final repo = ref.watch(submissionsRepositoryProvider);
  return repo.getAssignmentsForSubject(subjectId);
});

final studentAssignmentsProvider = FutureProvider.family<List<Assignment>, ({String studentId, int? subjectId})>((ref, arg) async {
  final repo = ref.watch(submissionsRepositoryProvider);
  return repo.getAssignmentsForStudent(arg.studentId, subjectId: arg.subjectId);
});

final assignmentSubmissionsProvider = FutureProvider.family<List<Submission>, int>((ref, assignmentId) async {
  final repo = ref.watch(submissionsRepositoryProvider);
  return repo.getSubmissionsForAssignment(assignmentId);
});
