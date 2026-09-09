import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_helper.dart';
import '../../admin/data/admin_repository.dart';
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

  String? _getTeacherId() {
    final user = ref.watch(authProvider);
    return user?.id;
  }

  Future<void> _load() async {
    final teacherId = _getTeacherId();
    if (teacherId == null) {
      if (ref.mounted) state = {};
      return;
    }
    final stats = await DatabaseHelper().getTeacherDashboardStats(teacherId);
    if (!ref.mounted) return;
    state = stats;
  }

  Future<void> reload() async {
    ref.invalidate(teacherHandledSectionsProvider);
    ref.invalidate(teacherHandledSectionsDetailsProvider);
    await _load();
  }
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

  String? _getTeacherId() {
    final user = ref.watch(authProvider);
    return user?.id;
  }

  Future<void> _load({String? section, String? query}) async {
    final teacherId = _getTeacherId();
    if (teacherId == null) {
      if (ref.mounted) state = [];
      return;
    }
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

  String? _getTeacherId() {
    final user = ref.watch(authProvider);
    return user?.id;
  }

  Future<void> _load() async {
    final teacherId = _getTeacherId();
    if (teacherId == null) {
      if (ref.mounted) state = [];
      return;
    }
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

// Teacher Handled Sections Provider
final teacherHandledSectionsProvider = FutureProvider<List<String>>((ref) async {
  final user = ref.watch(authProvider);
  final teacherId = user?.id;
  if (teacherId == null) return [];
  return await DatabaseHelper().getSectionsForTeacher(teacherId);
});

// Teacher Handled Sections Details Provider (counts, subjects, rooms)
final teacherHandledSectionsDetailsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(authProvider);
  final teacherId = user?.id;
  if (teacherId == null) return [];
  return await DatabaseHelper().getHandledSectionsWithDetails(teacherId);
});

// Teacher Announcements Provider
final teacherAnnouncementsProvider = NotifierProvider<TeacherAnnouncementsNotifier, List<Map<String, dynamic>>>(() {
  return TeacherAnnouncementsNotifier();
});

class TeacherAnnouncementsNotifier extends Notifier<List<Map<String, dynamic>>> {
  String _selectedSection = 'All Handled Sections';
  String get selectedSection => _selectedSection;

  @override
  List<Map<String, dynamic>> build() {
    _load();
    return [];
  }

  String? _getTeacherId() {
    final user = ref.watch(authProvider);
    return user?.id;
  }

  Future<void> _load({String? sectionFilter}) async {
    if (sectionFilter != null) {
      _selectedSection = sectionFilter;
    }
    final teacherId = _getTeacherId();
    if (teacherId == null) {
      if (ref.mounted) state = [];
      return;
    }
    final results = await DatabaseHelper().getAnnouncementsForTeacher(
      teacherId,
      section: _selectedSection,
    );
    if (!ref.mounted) return;
    state = results;
  }

  Future<void> reload({String? sectionFilter}) async => _load(sectionFilter: sectionFilter);

  Future<int> createAnnouncement({
    required String title,
    required String message,
    required String priority,
    required String targetSection,
    String targetAudience = 'students',
  }) async {
    final user = ref.read(authProvider);
    if (user == null || user.id.isEmpty) {
      throw StateError('You must be logged in as a teacher to post announcements.');
    }
    final teacherId = user.id;
    final teacherName = user.fullName;

    final db = await DatabaseHelper().database;
    final id = await db.insert('announcements', {
      'title': title.trim(),
      'message': message.trim(),
      'priority': priority.toLowerCase(),
      'target_audience': targetAudience.toLowerCase(),
      'section': targetSection,
      'author_id': teacherId,
      'author_name': teacherName,
      'author_role': 'teacher',
      'created_at': DateTime.now().toIso8601String(),
    });

    ref.invalidate(announcementsProvider);
    await _load();
    return id;
  }

  Future<void> updateAnnouncement(int id, Map<String, dynamic> data) async {
    final db = await DatabaseHelper().database;
    await db.update('announcements', data, where: 'id = ?', whereArgs: [id]);
    ref.invalidate(announcementsProvider);
    await _load();
  }

  Future<void> deleteAnnouncement(int id) async {
    final db = await DatabaseHelper().database;
    await db.delete('announcements', where: 'id = ?', whereArgs: [id]);
    ref.invalidate(announcementsProvider);
    await _load();
  }
}

