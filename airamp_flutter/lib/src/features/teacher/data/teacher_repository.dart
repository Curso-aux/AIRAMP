import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_helper.dart';
import '../../auth/application/auth_provider.dart';

// Teacher Dashboard Stats
final teacherDashboardProvider = NotifierProvider<TeacherDashboardNotifier, Map<String, dynamic>>(() {
  return TeacherDashboardNotifier();
});

class TeacherDashboardNotifier extends Notifier<Map<String, dynamic>> {
  @override
  Map<String, dynamic> build() {
    _load();
    return {};
  }

  String _getTeacherId() {
    final user = ref.watch(authProvider);
    return user?.id ?? 'teacher_1';
  }

  Future<void> _load() async {
    final teacherId = _getTeacherId();
    final stats = await DatabaseHelper().getTeacherDashboardStats(teacherId);
    if (!ref.mounted) return;
    state = stats;
  }

  Future<void> reload() async => _load();
}

// Teacher Students
final teacherStudentsProvider = NotifierProvider<TeacherStudentsNotifier, List<Map<String, dynamic>>>(() {
  return TeacherStudentsNotifier();
});

class TeacherStudentsNotifier extends Notifier<List<Map<String, dynamic>>> {
  @override
  List<Map<String, dynamic>> build() {
    _load();
    return [];
  }

  String _getTeacherId() {
    final user = ref.watch(authProvider);
    return user?.id ?? 'teacher_1';
  }

  Future<void> _load({String? section, String? query}) async {
    final teacherId = _getTeacherId();
    final results = await DatabaseHelper().getStudentsForTeacher(teacherId, section: section, query: query);
    if (!ref.mounted) return;
    state = results;
  }

  Future<void> reload({String? section, String? query}) async => _load(section: section, query: query);
}

// Teacher Subjects
final teacherSubjectsProvider = NotifierProvider<TeacherSubjectsNotifier, List<Map<String, dynamic>>>(() {
  return TeacherSubjectsNotifier();
});

class TeacherSubjectsNotifier extends Notifier<List<Map<String, dynamic>>> {
  @override
  List<Map<String, dynamic>> build() {
    _load();
    return [];
  }

  String _getTeacherId() {
    final user = ref.watch(authProvider);
    return user?.id ?? 'teacher_1';
  }

  Future<void> _load() async {
    final teacherId = _getTeacherId();
    final results = await DatabaseHelper().getSubjectsForTeacher(teacherId);
    if (!ref.mounted) return;
    state = results;
  }

  Future<void> reload() async => _load();
}

// Subject Quizzes Provider
final subjectQuizzesProvider = FutureProvider.family<List<Map<String, dynamic>>, int>((ref, subjectId) async {
  return await DatabaseHelper().getQuizzesForSubject(subjectId);
});

// Quiz Roster Provider
final quizRosterProvider = FutureProvider.family<List<Map<String, dynamic>>, int>((ref, quizId) async {
  return await DatabaseHelper().getQuizAssignmentRoster(quizId);
});
