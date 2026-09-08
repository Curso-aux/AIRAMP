import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/api/api_client.dart';

// --- Announcements ---
final announcementsProvider = NotifierProvider<AnnouncementsNotifier, List<Map<String, dynamic>>>(() {
  return AnnouncementsNotifier();
});

class AnnouncementsNotifier extends Notifier<List<Map<String, dynamic>>> {
  @override
  List<Map<String, dynamic>> build() {
    _loadAnnouncements();
    return [];
  }

  Future<void> _loadAnnouncements() async {
    final db = await DatabaseHelper().database;
    final List<Map<String, dynamic>> maps = await db.query('announcements', orderBy: 'id DESC');
    if (!ref.mounted) return;
    state = maps;
  }

  Future<void> addAnnouncement(Map<String, dynamic> announcement) async {
    final db = await DatabaseHelper().database;
    await db.insert('announcements', announcement);
    await _loadAnnouncements();
  }

  Future<void> updateAnnouncement(int id, Map<String, dynamic> announcement) async {
    final db = await DatabaseHelper().database;
    await db.update('announcements', announcement, where: 'id = ?', whereArgs: [id]);
    await _loadAnnouncements();
  }

  Future<void> deleteAnnouncement(int id) async {
    final db = await DatabaseHelper().database;
    await db.delete('announcements', where: 'id = ?', whereArgs: [id]);
    await _loadAnnouncements();
  }
}

// --- Subjects ---
final subjectsProvider = NotifierProvider<SubjectsNotifier, List<Map<String, dynamic>>>(() {
  return SubjectsNotifier();
});

class SubjectsNotifier extends Notifier<List<Map<String, dynamic>>> {
  final Dio? _dio;
  SubjectsNotifier({Dio? dio}) : _dio = dio ?? (ApiClient.isCloudAvailable ? ApiClient.instance : null);
  @override
  List<Map<String, dynamic>> build() {
    _loadSubjects();
    return [];
  }

  Future<void> _loadSubjects() async {
    final db = await DatabaseHelper().database;
    final List<Map<String, dynamic>> maps = await db.query('subjects', orderBy: 'id DESC');
    if (_dio != null && ApiClient.isCloudAvailable) {
      try {
        final resp = await _dio.get('/v1/api/subjects');
        final remote = resp.data;
        if (remote is Map && remote['subjects'] is List) {
          final remoteList = (remote['subjects'] as List).cast<Map<String, dynamic>>();
          for (final s in remoteList) {
            await db.insert('subjects', s, conflictAlgorithm: ConflictAlgorithm.replace);
          }
          if (!ref.mounted) return;
          state = await db.query('subjects', orderBy: 'id DESC');
          return;
        }
      } on DioException {
        // fall through to local data
      }
    }
    if (!ref.mounted) return;
    state = maps;
  }

  Future<int> addSubject(Map<String, dynamic> subject) async {
    final db = await DatabaseHelper().database;
    final id = await db.insert('subjects', subject);
    await _loadSubjects();
    return id;
  }

  Future<void> updateSubject(int id, Map<String, dynamic> data) async {
    final db = await DatabaseHelper().database;
    await db.update('subjects', data, where: 'id = ?', whereArgs: [id]);
    await _loadSubjects();
  }

  Future<void> deleteSubject(int id) async {
    final db = await DatabaseHelper().database;
    await db.delete('subjects', where: 'id = ?', whereArgs: [id]);
    await _loadSubjects();
  }

  Future<Map<String, dynamic>?> getSubjectById(int id) async {
    final db = await DatabaseHelper().database;
    final results = await db.query('subjects', where: 'id = ?', whereArgs: [id]);
    if (results.isNotEmpty) return results.first;
    return null;
  }
}

// --- Sections ---
final sectionsProvider = NotifierProvider<SectionsNotifier, List<Map<String, dynamic>>>(() {
  return SectionsNotifier();
});

class SectionsNotifier extends Notifier<List<Map<String, dynamic>>> {
  @override
  List<Map<String, dynamic>> build() {
    _loadSections();
    return [];
  }

  Future<void> _loadSections() async {
    final db = await DatabaseHelper().database;
    final List<Map<String, dynamic>> maps = await db.query('sections', orderBy: 'id DESC');
    if (!ref.mounted) return;
    state = maps;
  }

  Future<void> addSection(Map<String, dynamic> section) async {
    final db = await DatabaseHelper().database;
    await db.insert('sections', section);
    await _loadSections();
  }

  Future<void> updateSection(int id, Map<String, dynamic> section) async {
    final db = await DatabaseHelper().database;
    await db.update('sections', section, where: 'id = ?', whereArgs: [id]);
    await _loadSections();
  }
  
  Future<void> deleteSection(int id) async {
    final db = await DatabaseHelper().database;
    await db.delete('sections', where: 'id = ?', whereArgs: [id]);
    await _loadSections();
  }
}

// --- Teachers List (for subject assignment) ---
final teachersListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return await DatabaseHelper().getTeachersList();
});

// --- Count Providers (for dashboard stats) ---
final subjectsCountProvider = Provider<int>((ref) {
  final subjects = ref.watch(subjectsProvider);
  return subjects.length;
});

final sectionsCountProvider = Provider<int>((ref) {
  final sections = ref.watch(sectionsProvider);
  return sections.length;
});

// --- Registration Links ---
final regLinksProvider = NotifierProvider<RegLinksNotifier, List<Map<String, dynamic>>>(() {
  return RegLinksNotifier();
});

class RegLinksNotifier extends Notifier<List<Map<String, dynamic>>> {
  @override
  List<Map<String, dynamic>> build() {
    _loadLinks();
    return [];
  }

  Future<void> _loadLinks() async {
    final db = await DatabaseHelper().database;
    final List<Map<String, dynamic>> maps = await db.query('reg_links', orderBy: 'created_at DESC');
    if (!ref.mounted) return;
    state = maps;
  }

  Future<void> addLink(Map<String, dynamic> link) async {
    final db = await DatabaseHelper().database;
    await db.insert('reg_links', link);
    await _loadLinks();
  }
  
  Future<void> deleteLink(String code) async {
    final db = await DatabaseHelper().database;
    await db.delete('reg_links', where: 'code = ?', whereArgs: [code]);
    await _loadLinks();
  }
}

// --- Subject Detail Hierarchy ---
final subjectDetailProvider = NotifierProvider<SubjectDetailNotifier, List<Map<String, dynamic>>>(() {
  return SubjectDetailNotifier();
});

class SubjectDetailNotifier extends Notifier<List<Map<String, dynamic>>> {
  int? _subjectId;

  @override
  List<Map<String, dynamic>> build() {
    return [];
  }

  Future<void> loadHierarchy(int subjectId) async {
    _subjectId = subjectId;
    final db = await DatabaseHelper().database;
    
    final topics = await db.query('topics', where: 'subject_id = ?', whereArgs: [subjectId], orderBy: 'id ASC');
    
    List<Map<String, dynamic>> fullTopics = [];
    for (var topic in topics) {
      final topicId = topic['id'] as int;
      final los = await db.query('learning_outcomes', where: 'topic_id = ?', whereArgs: [topicId], orderBy: 'id ASC');
      
      List<Map<String, dynamic>> fullLos = [];
      for (var lo in los) {
        final loId = lo['id'] as int;
        final contents = await db.query('contents', where: 'lo_id = ?', whereArgs: [loId], orderBy: 'id ASC');
        final questions = await db.query('questions', where: 'lo_id = ?', whereArgs: [loId], orderBy: 'id ASC');
        fullLos.add({
          ...lo,
          'contents': contents,
          'questions': questions,
        });
      }
      
      fullTopics.add({
        ...topic,
        'learning_outcomes': fullLos,
      });
    }
    
    state = fullTopics;
  }

  // Topics
  Future<void> addTopic(Map<String, dynamic> topic) async {
    if (_subjectId == null) return;
    final db = await DatabaseHelper().database;
    topic['subject_id'] = _subjectId;
    topic['created_at'] = DateTime.now().toIso8601String();
    await db.insert('topics', topic);
    await loadHierarchy(_subjectId!);
  }

  Future<void> updateTopic(int topicId, Map<String, dynamic> data) async {
    if (_subjectId == null) return;
    final db = await DatabaseHelper().database;
    await db.update('topics', data, where: 'id = ?', whereArgs: [topicId]);
    await loadHierarchy(_subjectId!);
  }

  Future<void> deleteTopic(int topicId) async {
    if (_subjectId == null) return;
    final db = await DatabaseHelper().database;
    await db.delete('topics', where: 'id = ?', whereArgs: [topicId]);
    await loadHierarchy(_subjectId!);
  }

  // Learning Outcomes
  Future<void> addLearningOutcome(int topicId, Map<String, dynamic> lo) async {
    if (_subjectId == null) return;
    final db = await DatabaseHelper().database;
    lo['topic_id'] = topicId;
    lo['created_at'] = DateTime.now().toIso8601String();
    await db.insert('learning_outcomes', lo);
    await loadHierarchy(_subjectId!);
  }

  Future<void> updateLearningOutcome(int loId, Map<String, dynamic> data) async {
    if (_subjectId == null) return;
    final db = await DatabaseHelper().database;
    await db.update('learning_outcomes', data, where: 'id = ?', whereArgs: [loId]);
    await loadHierarchy(_subjectId!);
  }

  Future<void> deleteLearningOutcome(int loId) async {
    if (_subjectId == null) return;
    final db = await DatabaseHelper().database;
    await db.delete('learning_outcomes', where: 'id = ?', whereArgs: [loId]);
    await loadHierarchy(_subjectId!);
  }

  // Contents
  Future<void> addContent(int loId, Map<String, dynamic> content) async {
    if (_subjectId == null) return;
    final db = await DatabaseHelper().database;
    content['lo_id'] = loId;
    content['created_at'] = DateTime.now().toIso8601String();
    await db.insert('contents', content);
    await loadHierarchy(_subjectId!);
  }

  Future<void> updateContent(int contentId, Map<String, dynamic> data) async {
    if (_subjectId == null) return;
    final db = await DatabaseHelper().database;
    await db.update('contents', data, where: 'id = ?', whereArgs: [contentId]);
    await loadHierarchy(_subjectId!);
  }

  Future<void> deleteContent(int contentId) async {
    if (_subjectId == null) return;
    final db = await DatabaseHelper().database;
    await db.delete('contents', where: 'id = ?', whereArgs: [contentId]);
    await loadHierarchy(_subjectId!);
  }

  // Questions
  Future<void> addQuestion(int loId, Map<String, dynamic> question) async {
    if (_subjectId == null) return;
    final db = await DatabaseHelper().database;
    question['lo_id'] = loId;
    question['created_at'] = DateTime.now().toIso8601String();
    await db.insert('questions', question);
    await loadHierarchy(_subjectId!);
  }

  Future<void> updateQuestion(int questionId, Map<String, dynamic> question) async {
    if (_subjectId == null) return;
    final db = await DatabaseHelper().database;
    await db.update('questions', question, where: 'id = ?', whereArgs: [questionId]);
    await loadHierarchy(_subjectId!);
  }

  Future<void> deleteQuestion(int questionId) async {
    if (_subjectId == null) return;
    final db = await DatabaseHelper().database;
    await db.delete('questions', where: 'id = ?', whereArgs: [questionId]);
    await loadHierarchy(_subjectId!);
  }
}

// --- Admin Web Analytics Provider ---
final adminAnalyticsProvider = NotifierProvider<AdminAnalyticsNotifier, Map<String, dynamic>>(() {
  return AdminAnalyticsNotifier();
});

class AdminAnalyticsNotifier extends Notifier<Map<String, dynamic>> {
  @override
  Map<String, dynamic> build() {
    loadAnalytics();
    return {
      'totalUsers': 0,
      'totalStudents': 0,
      'totalTeachers': 0,
      'totalAdmins': 0,
      'totalEnrollments': 0,
      'totalSubjects': 0,
      'totalTopics': 0,
      'totalLos': 0,
      'totalAttempts': 0,
      'passedAttempts': 0,
      'passRate': 0,
      'avgScore': 0,
      'subjectEnrollments': <Map<String, dynamic>>[],
      'sectionDistribution': <Map<String, dynamic>>[],
      'recentAnnouncements': <Map<String, dynamic>>[],
      'recentAttempts': <Map<String, dynamic>>[],
    };
  }

  Future<void> loadAnalytics() async {
    final summary = await DatabaseHelper().getAdminAnalyticsSummary();
    if (!ref.mounted) return;
    state = summary;
  }
}

// --- Admin Students Provider ---
final adminStudentsProvider = NotifierProvider<AdminStudentsNotifier, List<Map<String, dynamic>>>(() {
  return AdminStudentsNotifier();
});

class AdminStudentsNotifier extends Notifier<List<Map<String, dynamic>>> {
  String _selectedSection = 'All';
  String _selectedGrade = 'All';
  String _searchQuery = '';

  @override
  List<Map<String, dynamic>> build() {
    loadStudents();
    return [];
  }

  Future<void> loadStudents({String? section, String? grade, String? query}) async {
    if (section != null) _selectedSection = section;
    if (grade != null) _selectedGrade = grade;
    if (query != null) _searchQuery = query;

    final results = await DatabaseHelper().getAdminStudentsList(
      section: _selectedSection,
      grade: _selectedGrade,
      query: _searchQuery,
    );
    if (!ref.mounted) return;
    state = results;
  }

  Future<void> reassignSection(String studentId, String newSection, {String? newGrade}) async {
    await DatabaseHelper().updateStudentSection(studentId, newSection, grade: newGrade);
    await loadStudents();
    ref.read(adminAnalyticsProvider.notifier).loadAnalytics();
  }
}

// --- Admin Enrollment Keys Provider ---
final adminKeysProvider = NotifierProvider<AdminKeysNotifier, List<Map<String, dynamic>>>(() {
  return AdminKeysNotifier();
});

class AdminKeysNotifier extends Notifier<List<Map<String, dynamic>>> {
  @override
  List<Map<String, dynamic>> build() {
    loadKeys();
    return [];
  }

  Future<void> loadKeys() async {
    final keys = await DatabaseHelper().getEnrollmentKeysList();
    if (!ref.mounted) return;
    state = keys;
  }

  Future<void> createKey({
    required String code,
    required String section,
    int maxUses = 50,
    String? expiration,
  }) async {
    await DatabaseHelper().generateEnrollmentKey(
      code: code,
      section: section,
      maxUses: maxUses,
      expiration: expiration,
    );
    await loadKeys();
  }

  Future<void> deleteKey(String code) async {
    await DatabaseHelper().deleteEnrollmentKey(code);
    await loadKeys();
  }
}

// --- Available Sections Provider ---
final availableSectionsProvider = FutureProvider<List<String>>((ref) async {
  return await DatabaseHelper().getAvailableSectionsList();
});

