import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/database/firestore_service.dart';
import '../domain/semester_archive_models.dart';

abstract class ISemesterSelectivePurgeService {
  Future<PurgeSummary> executeSelectivePurge({
    required String adminId,
    required String schoolId,
    String? previousSemester,
    String? newSemester,
  });
}

/// Helper queue to batch Firestore operations (set, update, delete)
/// capping at 400 operations per batch to safely remain below Firestore's 500-write limit.
class ChunkedBatchQueue {
  final FirebaseFirestore? firestore;
  final int maxOpsPerBatch;
  final WriteBatch Function()? _batchFactory;
  WriteBatch _currentBatch;
  int _pendingOps = 0;
  int _totalCommitted = 0;

  ChunkedBatchQueue(
    FirebaseFirestore this.firestore, {
    this.maxOpsPerBatch = 400,
  }) : _batchFactory = null,
       _currentBatch = firestore.batch();

  ChunkedBatchQueue.custom(
    WriteBatch Function() batchFactory, {
    this.maxOpsPerBatch = 400,
  }) : firestore = null,
       _batchFactory = batchFactory,
       _currentBatch = batchFactory();

  int get pendingOps => _pendingOps;
  int get totalCommitted => _totalCommitted;

  Future<void> delete(DocumentReference docRef) async {
    _currentBatch.delete(docRef);
    _pendingOps++;
    if (_pendingOps >= maxOpsPerBatch) {
      await commit();
    }
  }

  Future<void> update(
    DocumentReference docRef,
    Map<String, dynamic> data,
  ) async {
    _currentBatch.update(docRef, data);
    _pendingOps++;
    if (_pendingOps >= maxOpsPerBatch) {
      await commit();
    }
  }

  Future<void> set(
    DocumentReference docRef,
    Map<String, dynamic> data, [
    SetOptions? options,
  ]) async {
    _currentBatch.set(docRef, data, options);
    _pendingOps++;
    if (_pendingOps >= maxOpsPerBatch) {
      await commit();
    }
  }

  Future<void> commit() async {
    if (_pendingOps > 0) {
      await _currentBatch.commit();
      _totalCommitted += _pendingOps;
      _pendingOps = 0;
      if (_batchFactory != null) {
        _currentBatch = _batchFactory();
      } else if (firestore != null) {
        _currentBatch = firestore!.batch();
      }
    }
  }
}

class SemesterSelectivePurgeService implements ISemesterSelectivePurgeService {
  final FirebaseFirestore? _firestoreInstance;
  final DatabaseHelper? dbHelper;
  final Database? database;

  SemesterSelectivePurgeService({
    FirebaseFirestore? firestore,
    this.dbHelper,
    this.database,
  }) : _firestoreInstance = firestore;

  FirebaseFirestore? get _firestore {
    if (_firestoreInstance != null) return _firestoreInstance;
    try {
      if (FirestoreService().isAvailable) {
        return FirestoreService().firestore;
      }
    } catch (_) {}
    return null;
  }

  Future<Database> _getDatabase() async {
    final db = database;
    if (db != null) return db;
    final helper = dbHelper;
    if (helper != null) return await helper.database;
    return await DatabaseHelper().database;
  }

  @override
  Future<PurgeSummary> executeSelectivePurge({
    required String adminId,
    required String schoolId,
    String? previousSemester,
    String? newSemester,
  }) async {
    final executedAt = DateTime.now();
    final prevSem = (previousSemester?.trim().isNotEmpty == true)
        ? previousSemester!.trim()
        : '1st Semester AY 2025-2026';
    final nextSem = (newSemester?.trim().isNotEmpty == true)
        ? newSemester!.trim()
        : '2nd Semester AY 2025-2026';

    int deletedSubjectsCount = 0;
    int deletedModulesCount = 0;
    int deletedQuizzesCount = 0;
    int deletedAttemptsCount = 0;
    int deletedAssignmentsCount = 0;
    int deletedSubmissionsCount = 0;
    int deletedFlashcardsCount = 0;
    int deletedSchedulesCount = 0;
    int deletedEnrollmentKeysCount = 0;
    int resetStudentEnrollmentsCount = 0;
    int preservedUsersCount = 0;

    final fs = _firestore;

    if (fs != null) {
      final queue = ChunkedBatchQueue(fs, maxOpsPerBatch: 400);

      // 1. Recursive Subcollection Deletion: /subjects/{subjectId}/modules/{moduleId}
      final subjectsSnap = await fs.collection('subjects').get();
      deletedSubjectsCount = subjectsSnap.docs.length;
      for (final subjectDoc in subjectsSnap.docs) {
        final modulesSnap = await subjectDoc.reference
            .collection('modules')
            .get();
        deletedModulesCount += modulesSnap.docs.length;
        for (final moduleDoc in modulesSnap.docs) {
          await queue.delete(moduleDoc.reference);
        }
        await queue.delete(subjectDoc.reference);
      }

      // 2. Flat Transient Collections Deletion
      Future<int> purgeCollection(String collectionName) async {
        final snap = await fs.collection(collectionName).get();
        for (final doc in snap.docs) {
          await queue.delete(doc.reference);
        }
        return snap.docs.length;
      }

      deletedAssignmentsCount = await purgeCollection('assignments');
      deletedQuizzesCount = await purgeCollection('quizzes');
      await purgeCollection('quiz_assignments');
      deletedAttemptsCount = await purgeCollection('quiz_attempts');
      deletedSubmissionsCount = await purgeCollection('submissions');
      deletedFlashcardsCount = await purgeCollection('module_flashcards');
      deletedSchedulesCount = await purgeCollection('class_schedules');
      deletedEnrollmentKeysCount = await purgeCollection('enrollment_keys');
      await purgeCollection('reg_links');
      await purgeCollection('student_progress');

      // 3. Strict User Preservation & Student Enrollment Reset
      final usersSnap = await fs.collection('users').get();
      preservedUsersCount = usersSnap.docs.length;

      for (final userDoc in usersSnap.docs) {
        final data = userDoc.data();
        final role = data['role']?.toString().toLowerCase();
        if (role == 'student') {
          await queue.update(userDoc.reference, {
            'enrolled_courses': 0,
            'enrolled_subjects': <String>[],
            'updated_at': executedAt.toIso8601String(),
          });
          resetStudentEnrollmentsCount++;
        }
        // Admin and teacher documents are preserved unmodified
      }

      // 4. Commit all pending Firestore operations
      await queue.commit();
    }

    // 5. Purge Local SQLite Academic Data in leaf-first order
    try {
      final db = await _getDatabase();
      await db.transaction((txn) async {
        final tables = [
          'submissions',
          'quiz_attempts',
          'quiz_assignments',
          'assignments',
          'quizzes',
          'questions',
          'contents',
          'learning_outcomes',
          'topics',
          'module_flashcards',
          'class_schedules',
          'student_progress',
          'enrollments',
          'reg_links',
          'subjects',
        ];
        for (final table in tables) {
          try {
            await txn.delete(table);
          } catch (e) {
            debugPrint(
              '[SemesterSelectivePurge] Note deleting table $table: $e',
            );
          }
        }
      });
    } catch (e) {
      debugPrint('[SemesterSelectivePurge] SQLite transaction note: $e');
    }

    // Fallback: If running without Firestore, count preserved users from SQLite
    if (preservedUsersCount == 0) {
      try {
        final db = await _getDatabase();
        final usersList = await db.query('users');
        preservedUsersCount = usersList.length;
      } catch (_) {}
    }

    // 6. Clean SharedPreferences tombstones for subjects
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('permanently_deleted_subjects');
    } catch (_) {}

    // 7. Summary Creation
    final summary = PurgeSummary(
      deletedSubjectsCount: deletedSubjectsCount,
      deletedModulesCount: deletedModulesCount,
      deletedQuizzesCount: deletedQuizzesCount,
      deletedAttemptsCount: deletedAttemptsCount,
      deletedAssignmentsCount: deletedAssignmentsCount,
      deletedSubmissionsCount: deletedSubmissionsCount,
      preservedUsersCount: preservedUsersCount,
      executedAt: executedAt,
      deletedFlashcardsCount: deletedFlashcardsCount,
      deletedSchedulesCount: deletedSchedulesCount,
      deletedEnrollmentKeysCount: deletedEnrollmentKeysCount,
      resetStudentEnrollmentsCount: resetStudentEnrollmentsCount,
    );

    // 8. Update School Academic Term to New Semester
    try {
      final helper = dbHelper ?? DatabaseHelper();
      String ay = 'AY 2025-2026';
      String sem = nextSem;
      if (nextSem.contains('AY')) {
        final parts = nextSem.split('AY');
        sem = parts[0].trim();
        ay = 'AY ${parts[1].trim()}';
      }
      await helper.updateSchoolAcademicTerm(
        schoolId: schoolId,
        academicYear: ay,
        currentSemester: sem,
        recordResetTimestamp: true,
      );
    } catch (e) {
      debugPrint('[SemesterSelectivePurge] School term update note: $e');
    }

    // 8. Dual Audit Logging with Semester Rollover Metadata
    if (fs != null) {
      try {
        final auditDocId = 'audit_purge_${executedAt.millisecondsSinceEpoch}';
        await fs.collection('system_audit_logs').doc(auditDocId).set({
          'id': auditDocId,
          'action': 'SEMESTER_ROLLOVER',
          'previous_semester': prevSem,
          'new_semester': nextSem,
          'timestamp': executedAt.toUtc().toIso8601String(),
          'admin_id': adminId,
          'actor_id': adminId,
          'school_id': schoolId,
          'created_at': executedAt.toIso8601String(),
          'details':
              'Academic semester reset executed ($prevSem -> $nextSem). Preserved $preservedUsersCount users.',
          'summary': summary.toMap(),
        });
      } catch (e) {
        debugPrint('[SemesterSelectivePurgeService] Cloud audit log note: $e');
      }
    }

    try {
      final db = database;
      if (db != null) {
        final auditDocId = 'audit_purge_${executedAt.millisecondsSinceEpoch}';
        await db.insert('system_audit_logs', {
          'id': auditDocId,
          'action': 'SEMESTER_SELECTIVE_PURGE',
          'actor_id': adminId,
          'actor_name': 'Campus Admin',
          'school_id': schoolId,
          'created_at': executedAt.toIso8601String(),
          'details':
              'Semester academic data purged ($prevSem -> $nextSem). Preserved $preservedUsersCount user accounts. Deleted $deletedSubjectsCount subjects, $deletedQuizzesCount quizzes, $deletedAssignmentsCount assignments, $deletedSubmissionsCount submissions.',
        });
        await db.insert('system_audit_logs', {
          'id': '${auditDocId}_rollover',
          'action': 'SEMESTER_ROLLOVER',
          'actor_id': adminId,
          'actor_name': 'Campus Admin',
          'school_id': schoolId,
          'created_at': executedAt.toIso8601String(),
          'details':
              'Semester rollover recorded ($prevSem -> $nextSem). Preserved $preservedUsersCount user accounts.',
        });
      } else {
        final helper = dbHelper ?? DatabaseHelper();
        await helper.logAuditEvent(
          action: 'SEMESTER_SELECTIVE_PURGE',
          details:
              'Semester academic data purged ($prevSem -> $nextSem). Preserved $preservedUsersCount user accounts. Deleted $deletedSubjectsCount subjects, $deletedQuizzesCount quizzes, $deletedAssignmentsCount assignments, $deletedSubmissionsCount submissions.',
          actorId: adminId,
          schoolId: schoolId,
        );
        await helper.logAuditEvent(
          action: 'SEMESTER_ROLLOVER',
          details:
              'Semester rollover recorded ($prevSem -> $nextSem). Preserved $preservedUsersCount user accounts.',
          actorId: adminId,
          schoolId: schoolId,
        );
      }
    } catch (e) {
      debugPrint('[SemesterSelectivePurgeService] Local audit log note: $e');
    }

    return summary;
  }
}
