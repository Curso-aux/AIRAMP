import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_helper.dart';
import '../../auth/application/auth_provider.dart';
import '../../admin/data/admin_repository.dart';
import '../../teacher/data/teacher_repository.dart';

// --- Student Enrolled Courses ---
final studentCoursesProvider = NotifierProvider<StudentCoursesNotifier, List<Map<String, dynamic>>>(() {
  return StudentCoursesNotifier();
});

class StudentCoursesNotifier extends Notifier<List<Map<String, dynamic>>> {
  @override
  List<Map<String, dynamic>> build() {
    _loadCourses();
    return [];
  }

  String _getStudentId() {
    final user = ref.watch(authProvider);
    return user?.id ?? 'student_1';
  }

  Future<void> _loadCourses() async {
    final studentId = _getStudentId();
    final results = await DatabaseHelper().getEnrolledSubjects(studentId);
    if (!ref.mounted) return;
    state = results;
  }

  Future<void> reload() async {
    await _loadCourses();
  }

  Future<void> enrollCourse(int subjectId) async {
    final studentId = _getStudentId();
    await DatabaseHelper().enrollSubject(studentId, subjectId);
    await _loadCourses();
    ref.invalidate(availableCoursesProvider);
    ref.invalidate(studentProgressProvider);
  }

  Future<void> unenrollCourse(int subjectId) async {
    final studentId = _getStudentId();
    await DatabaseHelper().unenrollSubject(studentId, subjectId);
    await _loadCourses();
    ref.invalidate(availableCoursesProvider);
    ref.invalidate(studentProgressProvider);
  }
}

// --- Available Courses for Student ---
final availableCoursesProvider = NotifierProvider<AvailableCoursesNotifier, List<Map<String, dynamic>>>(() {
  return AvailableCoursesNotifier();
});

class AvailableCoursesNotifier extends Notifier<List<Map<String, dynamic>>> {
  @override
  List<Map<String, dynamic>> build() {
    _loadAvailable();
    return [];
  }

  String _getStudentId() {
    final user = ref.watch(authProvider);
    return user?.id ?? 'student_1';
  }

  Future<void> _loadAvailable() async {
    final studentId = _getStudentId();
    final results = await DatabaseHelper().getAvailableSubjects(studentId);
    if (!ref.mounted) return;
    state = results;
  }

  Future<void> reload() async {
    await _loadAvailable();
  }
}

// --- Student Progress Summary ---
final studentProgressProvider = NotifierProvider<StudentProgressNotifier, Map<String, dynamic>>(() {
  return StudentProgressNotifier();
});

class StudentProgressNotifier extends Notifier<Map<String, dynamic>> {
  @override
  Map<String, dynamic> build() {
    loadProgress();
    return {
      'activeCourses': 0,
      'completed': 0,
      'total': 0,
      'pending': 0,
      'average': 0.0,
      'best': 0.0,
      'totalAttempts': 0,
      'passedAttempts': 0,
    };
  }

  String _getStudentId() {
    final user = ref.watch(authProvider);
    return user?.id ?? 'student_1';
  }

  Future<void> loadProgress({int? subjectId}) async {
    final studentId = _getStudentId();
    final summary = await DatabaseHelper().getStudentProgressSummary(studentId, subjectId: subjectId);
    if (!ref.mounted) return;
    state = summary;
  }
}

// --- Student Quiz Assignments (Active / Pending Quizzes) ---
final studentQuizAssignmentsProvider = NotifierProvider<StudentQuizAssignmentsNotifier, List<Map<String, dynamic>>>(() {
  return StudentQuizAssignmentsNotifier();
});

class StudentQuizAssignmentsNotifier extends Notifier<List<Map<String, dynamic>>> {
  int? _activeSubjectFilter;

  @override
  List<Map<String, dynamic>> build() {
    loadAssignedQuizzes();
    return [];
  }

  String _getStudentId() {
    final user = ref.watch(authProvider);
    return user?.id ?? 'student_1';
  }

  Future<void> loadAssignedQuizzes({int? subjectId}) async {
    _activeSubjectFilter = subjectId;
    final studentId = _getStudentId();
    final results = await DatabaseHelper().getAssignedQuizzesForStudent(studentId, subjectId: subjectId);
    if (!ref.mounted) return;
    state = results;
  }

  Future<void> reload() async => loadAssignedQuizzes(subjectId: _activeSubjectFilter);
}

// --- Student Quiz Attempts & History ---
final studentQuizAttemptsProvider = NotifierProvider<StudentQuizAttemptsNotifier, List<Map<String, dynamic>>>(() {
  return StudentQuizAttemptsNotifier();
});

class StudentQuizAttemptsNotifier extends Notifier<List<Map<String, dynamic>>> {
  int? _activeSubjectFilter;

  @override
  List<Map<String, dynamic>> build() {
    loadAttempts();
    return [];
  }

  String _getStudentId() {
    final user = ref.watch(authProvider);
    return user?.id ?? 'student_1';
  }

  Future<void> loadAttempts({int? subjectId}) async {
    _activeSubjectFilter = subjectId;
    final studentId = _getStudentId();
    final results = await DatabaseHelper().getStudentQuizAttempts(studentId, subjectId: subjectId);
    if (!ref.mounted) return;
    state = results;
  }

  Future<void> recordAttempt({
    required int loId,
    int? quizId,
    required int subjectId,
    required int score,
    required int totalQuestions,
    required double percentage,
    required bool isPassed,
    int durationSeconds = 0,
  }) async {
    final studentId = _getStudentId();
    await DatabaseHelper().recordQuizAttempt(
      studentId: studentId,
      loId: loId,
      quizId: quizId,
      subjectId: subjectId,
      score: score,
      totalQuestions: totalQuestions,
      percentage: percentage,
      isPassed: isPassed,
      durationSeconds: durationSeconds,
    );

    await loadAttempts(subjectId: _activeSubjectFilter);
    ref.invalidate(studentQuizAssignmentsProvider);
    ref.invalidate(studentCoursesProvider);
    ref.invalidate(studentProgressProvider);
    ref.invalidate(teacherScoresProvider);
    ref.invalidate(teacherDashboardProvider);
    ref.invalidate(adminAnalyticsProvider);
  }
}

// --- Teacher Scores Provider ---
final teacherScoresProvider = NotifierProvider<TeacherScoresNotifier, List<Map<String, dynamic>>>(() {
  return TeacherScoresNotifier();
});

class TeacherScoresNotifier extends Notifier<List<Map<String, dynamic>>> {
  String _selectedSection = 'All Sections';
  String _searchQuery = '';

  @override
  List<Map<String, dynamic>> build() {
    loadScores();
    return [];
  }

  Future<void> loadScores({String? section, String? query}) async {
    if (section != null) _selectedSection = section;
    if (query != null) _searchQuery = query;

    final results = await DatabaseHelper().getAllQuizScores(
      section: _selectedSection,
      query: _searchQuery,
    );
    if (!ref.mounted) return;
    state = results;
  }
}

// --- Specific LO Quiz Provider ---
final loQuizProvider = FutureProvider.family<Map<String, dynamic>?, int>((ref, loId) async {
  return await DatabaseHelper().getLoQuiz(loId);
});

