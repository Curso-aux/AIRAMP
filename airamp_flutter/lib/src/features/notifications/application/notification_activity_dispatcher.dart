import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/database/database_helper.dart';
import '../domain/notification_filter_service.dart';

/// Standardized, role-aware routing dispatcher for system activities
/// across students and teachers with deduplication and spam protection.
class NotificationActivityDispatcher {
  final DatabaseHelper _db;
  final NotificationFilterService _filterService;

  NotificationActivityDispatcher({
    DatabaseHelper? db,
    NotificationFilterService? filterService,
  })  : _db = db ?? DatabaseHelper(),
        _filterService = filterService ?? NotificationFilterService();

  /// Alerts all enrolled students of a subject when a teacher posts a new assignment.
  Future<List<String>> notifyNewAssignment({
    required String assignmentId,
    required int subjectId,
    required String title,
    required String teacherId,
    required String teacherName,
    String? dueDate,
  }) async {
    final createdIds = <String>[];
    try {
      final db = await _db.database;
      final enrollments = await db.query(
        'enrollments',
        columns: ['student_id'],
        where: 'subject_id = ?',
        whereArgs: [subjectId],
      );

      final sub = await db.query(
        'subjects',
        columns: ['name'],
        where: 'id = ?',
        whereArgs: [subjectId],
      );
      final subName = sub.isNotEmpty ? (sub.first['name'] as String? ?? 'Subject') : 'Subject';
      final formattedDue = dueDate != null && dueDate.length >= 10 ? ' Due: ${dueDate.substring(0, 10)}' : '';

      for (final row in enrollments) {
        final sId = row['student_id'] as String?;
        if (sId == null || sId.isEmpty) continue;

        final eval = _filterService.evaluate(
          userId: sId,
          type: 'new_assignment',
          title: 'New Assignment: $title',
          eventTime: DateTime.now(),
          relatedId: assignmentId,
          actorId: teacherId,
        );

        if (eval.shouldPersist) {
          final id = await _db.createNotification(
            userId: sId,
            type: 'new_assignment',
            title: 'New Assignment: $title',
            message: '$teacherName posted "$title" in $subName.$formattedDue',
            relatedId: assignmentId,
            targetRoute: '/student/home',
            subjectId: subjectId,
            actorId: teacherId,
            actorName: teacherName,
          );
          createdIds.add(id);
        }
      }
    } catch (e) {
      debugPrint('[NotificationActivityDispatcher] notifyNewAssignment error: $e');
    }
    return createdIds;
  }

  /// Alerts the subject teacher when a student submits an assignment activity.
  Future<String?> notifyActivitySubmitted({
    required String assignmentId,
    required int? subjectId,
    required String title,
    required String studentId,
    required String studentName,
    required String teacherId,
    bool isLate = false,
  }) async {
    try {
      final eval = _filterService.evaluate(
        userId: teacherId,
        type: 'activity_submission',
        title: 'Activity Submitted: $title',
        eventTime: DateTime.now(),
        relatedId: assignmentId,
        actorId: studentId,
      );

      if (!eval.shouldPersist) return null;

      final lateTag = isLate ? ' (Late)' : '';
      return await _db.createNotification(
        userId: teacherId,
        type: 'activity_submission',
        title: 'Activity Submitted: $title',
        message: '$studentName submitted "$title"$lateTag.',
        relatedId: assignmentId,
        targetRoute: '/teacher/dashboard',
        subjectId: subjectId,
        actorId: studentId,
        actorName: studentName,
      );
    } catch (e) {
      debugPrint('[NotificationActivityDispatcher] notifyActivitySubmitted error: $e');
      return null;
    }
  }

  /// Alerts a student when a teacher grades their assignment submission.
  Future<String?> notifyGradeReleased({
    required String assignmentId,
    required int? subjectId,
    required String title,
    required String studentId,
    required num grade,
    required num totalPoints,
    String? feedback,
    required String teacherId,
    String? teacherName,
  }) async {
    try {
      final eval = _filterService.evaluate(
        userId: studentId,
        type: 'grade_released',
        title: 'Activity Graded: $title',
        eventTime: DateTime.now(),
        relatedId: assignmentId,
        actorId: teacherId,
      );

      if (!eval.shouldPersist) return null;

      final feedbackText = feedback != null && feedback.trim().isNotEmpty ? ' Feedback: $feedback' : '';
      return await _db.createNotification(
        userId: studentId,
        type: 'grade_released',
        title: 'Activity Graded: $title',
        message: 'Your submission for "$title" was graded: $grade/$totalPoints.$feedbackText',
        relatedId: assignmentId,
        targetRoute: '/student/history',
        subjectId: subjectId,
        actorId: teacherId,
        actorName: teacherName ?? 'Teacher',
      );
    } catch (e) {
      debugPrint('[NotificationActivityDispatcher] notifyGradeReleased error: $e');
      return null;
    }
  }

  /// Alerts a student when a teacher unlocks resubmission for an assignment.
  Future<String?> notifyResubmissionUnlocked({
    required String assignmentId,
    required int? subjectId,
    required String title,
    required String studentId,
    required String teacherId,
    String? teacherName,
  }) async {
    try {
      final eval = _filterService.evaluate(
        userId: studentId,
        type: 'resubmission_allowed',
        title: 'Resubmission Allowed: $title',
        eventTime: DateTime.now(),
        relatedId: assignmentId,
        actorId: teacherId,
      );

      if (!eval.shouldPersist) return null;

      return await _db.createNotification(
        userId: studentId,
        type: 'resubmission_allowed',
        title: 'Resubmission Allowed: $title',
        message: '${teacherName ?? "Your teacher"} reopened resubmissions for "$title".',
        relatedId: assignmentId,
        targetRoute: '/student/history',
        subjectId: subjectId,
        actorId: teacherId,
        actorName: teacherName ?? 'Teacher',
      );
    } catch (e) {
      debugPrint('[NotificationActivityDispatcher] notifyResubmissionUnlocked error: $e');
      return null;
    }
  }

  /// Alerts assigned students when a teacher publishes a quiz.
  Future<List<String>> notifyQuizAssigned({
    required String quizId,
    required int? subjectId,
    required String title,
    required String teacherId,
    String? teacherName,
    required List<String> studentIds,
    String? dueDate,
  }) async {
    final createdIds = <String>[];
    try {
      final formattedDue = dueDate != null && dueDate.length >= 10 ? ' Due: ${dueDate.substring(0, 10)}' : '';

      for (final sId in studentIds) {
        if (sId.trim().isEmpty) continue;

        final eval = _filterService.evaluate(
          userId: sId,
          type: 'quiz_assigned',
          title: 'New Quiz: $title',
          eventTime: DateTime.now(),
          relatedId: quizId,
          actorId: teacherId,
        );

        if (eval.shouldPersist) {
          final id = await _db.createNotification(
            userId: sId,
            type: 'quiz_assigned',
            title: 'New Quiz: $title',
            message: '${teacherName ?? "Teacher"} assigned quiz "$title".$formattedDue',
            relatedId: quizId,
            targetRoute: '/student/courses',
            subjectId: subjectId,
            actorId: teacherId,
            actorName: teacherName ?? 'Teacher',
          );
          createdIds.add(id);
        }
      }
    } catch (e) {
      debugPrint('[NotificationActivityDispatcher] notifyQuizAssigned error: $e');
    }
    return createdIds;
  }

  /// Alerts student and teacher upon completion of a quiz.
  Future<void> notifyQuizAttemptCompleted({
    required String quizId,
    required int? subjectId,
    required String title,
    required String studentId,
    required String studentName,
    required num score,
    required num totalQuestions,
    String? teacherId,
  }) async {
    try {
      // 1. Notify Student
      final studentEval = _filterService.evaluate(
        userId: studentId,
        type: 'quiz',
        title: 'Quiz Completed: $title',
        eventTime: DateTime.now(),
        relatedId: quizId,
      );

      if (studentEval.shouldPersist) {
        final pct = totalQuestions > 0 ? ((score / totalQuestions) * 100).round() : 0;
        final passEmoji = pct >= 75 ? ' 🎉' : '';
        await _db.createNotification(
          userId: studentId,
          type: 'quiz',
          title: 'Quiz Submitted$passEmoji',
          message: 'You scored $score/$totalQuestions ($pct%) on "$title".',
          relatedId: quizId,
          targetRoute: '/student/history',
          subjectId: subjectId,
        );
      }

      // 2. Notify Teacher (if teacherId provided)
      if (teacherId != null && teacherId.isNotEmpty) {
        final teacherEval = _filterService.evaluate(
          userId: teacherId,
          type: 'quiz_completed',
          title: 'Quiz Completed: $studentName',
          eventTime: DateTime.now(),
          relatedId: quizId,
          actorId: studentId,
        );

        if (teacherEval.shouldPersist) {
          await _db.createNotification(
            userId: teacherId,
            type: 'quiz_completed',
            title: 'Quiz Completed: $studentName',
            message: '$studentName completed "$title" with score $score/$totalQuestions.',
            relatedId: quizId,
            targetRoute: '/teacher/dashboard',
            subjectId: subjectId,
            actorId: studentId,
            actorName: studentName,
          );
        }
      }
    } catch (e) {
      debugPrint('[NotificationActivityDispatcher] notifyQuizAttemptCompleted error: $e');
    }
  }

  /// Alerts users when an announcement is published.
  Future<List<String>> notifyAnnouncementPublished({
    required String announcementId,
    required String title,
    required String message,
    String? section,
    required String authorId,
    required String authorName,
    List<String>? targetUserIds,
  }) async {
    final createdIds = <String>[];
    try {
      var recipientIds = targetUserIds ?? <String>[];

      // If no explicit target IDs but section specified, find students in section
      if (recipientIds.isEmpty && section != null && section.isNotEmpty) {
        final db = await _db.database;
        final students = await db.query(
          'users',
          columns: ['id'],
          where: 'section = ? AND role = ?',
          whereArgs: [section, 'student'],
        );
        recipientIds = students.map((r) => r['id'] as String).toList();
      }

      for (final uid in recipientIds) {
        if (uid == authorId) continue; // Don't notify the author

        final eval = _filterService.evaluate(
          userId: uid,
          type: 'announcement',
          title: 'Announcement: $title',
          eventTime: DateTime.now(),
          relatedId: announcementId,
          actorId: authorId,
        );

        if (eval.shouldPersist) {
          final id = await _db.createNotification(
            userId: uid,
            type: 'announcement',
            title: 'Announcement: $title',
            message: message,
            relatedId: announcementId,
            targetRoute: '/student/home',
            actorId: authorId,
            actorName: authorName,
          );
          createdIds.add(id);
        }
      }
    } catch (e) {
      debugPrint('[NotificationActivityDispatcher] notifyAnnouncementPublished error: $e');
    }
    return createdIds;
  }
}
