import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_helper.dart';

// --- Student Enrollment / Courses ---
final studentCoursesProvider = NotifierProvider<StudentCoursesNotifier, List<Map<String, dynamic>>>(() {
  return StudentCoursesNotifier();
});

class StudentCoursesNotifier extends Notifier<List<Map<String, dynamic>>> {
  @override
  List<Map<String, dynamic>> build() {
    _loadCourses();
    return [];
  }

  Future<void> _loadCourses() async {
    final db = await DatabaseHelper().database;
    final results = await db.rawQuery('SELECT s.*, t.name as topic_name FROM subjects s JOIN sections sec ON sec.subject_id = s.id');
    state = results;
  }
}

// --- Student Progress ---
final studentProgressProvider = NotifierProvider<StudentProgressNotifier, Map<String, dynamic>>(() {
  return StudentProgressNotifier();
});

class StudentProgressNotifier extends Notifier<Map<String, dynamic>> {
  @override
  Map<String, dynamic> build() {
    return {'completed': 0, 'total': 0, 'average': 0.0};
  }

  Future<void> loadProgress() async {
    final db = await DatabaseHelper().database;
    final completed = (await db.rawQuery('SELECT COUNT(*) as c FROM learning_outcomes'))[0]['c'] ?? 0;
    state = {'completed': completed, 'total': 120, 'average': 75.0};
  }
}
