import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/utils/cache_manager.dart';
import '../../admin/data/admin_repository.dart';
import '../../auth/application/auth_provider.dart';

// Teacher Dashboard Stats
final teacherDashboardProvider = NotifierProvider<TeacherDashboardNotifier, Map<String, dynamic>>(() {
  return TeacherDashboardNotifier();
});

class TeacherDashboardNotifier extends Notifier<Map<String, dynamic>> {
  String? _section;
  String? _studentId;

  String? get currentSection => _section;
  String? get currentStudentId => _studentId;

  @override
  Map<String, dynamic> build() {
    _load();
    return {};
  }

  String? _getTeacherId() {
    final user = ref.watch(authProvider);
    return user?.id;
  }

  Future<void> _load({String? section, String? studentId, bool forceRefresh = false}) async {
    if (section != null) _section = section;
    if (studentId != null) _studentId = studentId;

    final teacherId = _getTeacherId();
    if (teacherId == null) {
      if (ref.mounted) state = {};
      return;
    }

    final sFilter = (_section == null ||
            _section == 'All' ||
            _section == 'All Handled Sections' ||
            _section == 'All Sections')
        ? null
        : _section;
    final stFilter = (_studentId == null ||
            _studentId == 'All' ||
            _studentId == 'All Students')
        ? null
        : _studentId;

    final cacheKey = 'teacher_dashboard_${teacherId}_${sFilter ?? "all"}_${stFilter ?? "all"}';
    final stats = await AppCacheManager.instance.getOrFetch(
      cacheKey,
      () => DatabaseHelper().getTeacherDashboardStats(
        teacherId,
        section: sFilter,
        studentId: stFilter,
      ),
      ttl: const Duration(minutes: 2),
      forceRefresh: forceRefresh,
    );
    if (!ref.mounted) return;
    state = stats;
  }

  Future<void> reload({String? section, String? studentId, bool resetFilters = false}) async {
    if (resetFilters) {
      _section = null;
      _studentId = null;
    }
    AppCacheManager.instance.invalidatePrefix('teacher_dashboard_');
    ref.invalidate(teacherHandledSectionsProvider);
    ref.invalidate(teacherHandledSectionsDetailsProvider);
    await _load(section: section, studentId: studentId, forceRefresh: true);
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

  Future<void> _load({String? section, String? query, bool forceRefresh = false}) async {
    final teacherId = _getTeacherId();
    if (teacherId == null) {
      if (ref.mounted) state = [];
      return;
    }
    final cacheKey = 'teacher_students_${teacherId}_${section ?? "all"}_${query ?? ""}';
    final results = await AppCacheManager.instance.getOrFetch(
      cacheKey,
      () => DatabaseHelper().getStudentsForTeacher(teacherId, section: section, query: query),
      ttl: const Duration(minutes: 2),
      forceRefresh: forceRefresh,
    );
    if (!ref.mounted) return;
    state = results;
  }

  Future<void> reload({String? section, String? query}) async {
    AppCacheManager.instance.invalidatePrefix('teacher_students_');
    await _load(section: section, query: query, forceRefresh: true);
  }
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

  Future<Map<String, dynamic>?> getSubjectById(int id) async {
    final teacherId = _getTeacherId();
    if (teacherId == null) return null;
    final db = await DatabaseHelper().database;
    final results = await db
        .query('subjects', where: 'id = ? AND teacher_id = ?', whereArgs: [id, teacherId]);
    if (results.isNotEmpty) return results.first;
    return null;
  }
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

