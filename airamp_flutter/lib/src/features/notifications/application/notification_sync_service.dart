import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/database/supabase_service.dart';
import '../../../routing/app_router.dart';
import '../domain/notification_filter_service.dart';
import '../domain/notification_model.dart';
import '../presentation/components/in_app_notification_banner.dart';
import 'device_notification_service.dart';

abstract class INotificationSyncService {
  void startSync(String userId);
  void stopSync();
  Stream<List<AppNotification>> get notificationStream;
}

/// Production service providing real-time Cloud Firestore & Supabase snapshot synchronization
/// for incoming notifications, integrating deduplication, rate limiting, and stale
/// event suppression before persisting to SQLite and showing banners and OS device popups.
class NotificationSyncService implements INotificationSyncService {
  static final NotificationSyncService _instance = NotificationSyncService._internal();
  factory NotificationSyncService({
    NotificationFilterService? filterService,
    DatabaseHelper? dbHelper,
    Stream<List<Map<String, dynamic>>> Function(String userId)? streamFactory,
  }) {
    if (filterService != null) _instance._filterService = filterService;
    if (dbHelper != null) _instance._db = dbHelper;
    if (streamFactory != null) _instance._streamFactory = streamFactory;
    return _instance;
  }
  NotificationSyncService._internal();

  NotificationFilterService _filterService = NotificationFilterService();
  DatabaseHelper _db = DatabaseHelper();
  Stream<List<Map<String, dynamic>>> Function(String userId)? _streamFactory;

  StreamSubscription? _subscription;
  StreamSubscription? _supabaseQuizSub;
  StreamSubscription? _supabaseAssignmentSub;
  StreamSubscription? _supabaseNotifSub;
  Timer? _pollTimer;
  String? _activeUserId;
  final StreamController<List<AppNotification>> _streamController =
      StreamController<List<AppNotification>>.broadcast();

  @override
  Stream<List<AppNotification>> get notificationStream => _streamController.stream;

  String? get activeUserId => _activeUserId;
  bool get isSyncing => _subscription != null || _supabaseQuizSub != null || _pollTimer != null;

  @visibleForTesting
  static void resetForTesting() {
    _instance.stopSync();
    _instance._streamFactory = null;
    _instance._filterService = NotificationFilterService();
    _instance._db = DatabaseHelper();
  }

  @override
  void startSync(String userId) {
    final cleanUid = userId.trim();
    if (cleanUid.isEmpty) return;
    if (_activeUserId == cleanUid && isSyncing) return;

    stopSync();
    _activeUserId = cleanUid;

    if (_streamFactory != null) {
      _subscription = _streamFactory!(cleanUid).listen(
        (items) async {
          for (final data in items) {
            final notif = AppNotification.fromMap(data);
            await processIncomingNotification(notif, showBanner: true);
          }
        },
        onError: (e) {
          debugPrint('[NotificationSyncService] Test stream error: $e');
        },
      );
      return;
    }

    // 1. Listen to Cloud Firestore notifications (if configured)
    try {
      final query = FirebaseFirestore.instance
          .collection('notifications')
          .where('user_id', isEqualTo: cleanUid);

      _subscription = query.snapshots().listen(
        (snapshot) async {
          await _handleSnapshot(snapshot);
        },
        onError: (e) {
          debugPrint('[NotificationSyncService] Firestore stream error: $e');
        },
      );
    } catch (e) {
      debugPrint('[NotificationSyncService] Firestore not initialized or unavailable: $e');
    }

    // 2. Listen to Supabase Realtime for Quizzes & Assignments
    try {
      if (SupabaseService.instance.isInitialized) {
        _supabaseQuizSub = SupabaseService.instance.streamQuizzes().listen(
          (quizList) async {
            if (quizList.isNotEmpty && _activeUserId != null) {
              await _processSupabaseQuizzesForStudent(_activeUserId!, quizList);
            }
          },
          onError: (e) {
            debugPrint('[NotificationSyncService] Supabase quiz stream notice: $e');
          },
        );

        _supabaseAssignmentSub = SupabaseService.instance.streamAssignments().listen(
          (assignmentList) async {
            if (assignmentList.isNotEmpty && _activeUserId != null) {
              await _processSupabaseAssignmentsForStudent(_activeUserId!, assignmentList);
            }
          },
          onError: (e) {
            debugPrint('[NotificationSyncService] Supabase assignment stream notice: $e');
          },
        );

        _supabaseNotifSub = SupabaseService.instance.streamNotifications(cleanUid).listen(
          (notifList) async {
            for (final item in notifList) {
              final notif = AppNotification.fromMap(item);
              await processIncomingNotification(notif, showBanner: true);
            }
          },
          onError: (e) {
            debugPrint('[NotificationSyncService] Supabase notification stream notice: $e');
          },
        );
      }
    } catch (e) {
      debugPrint('[NotificationSyncService] Supabase real-time setup notice: $e');
    }

    // 3. Perform immediate Supabase delta sync & schedule recurring check (every 15s)
    unawaited(syncFromSupabaseNow(userId: cleanUid));
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_activeUserId != null) {
        unawaited(syncFromSupabaseNow(userId: _activeUserId!));
      }
    });
  }

  /// Syncs newly published quizzes and assignments from Supabase for [userId]
  Future<void> syncFromSupabaseNow({String? userId}) async {
    final uid = userId ?? _activeUserId;
    if (uid == null || uid.isEmpty) return;
    if (!SupabaseService.instance.isInitialized) return;

    try {
      final quizzes = await SupabaseService.instance.fetchAllQuizzes();
      if (quizzes.isNotEmpty) {
        await _processSupabaseQuizzesForStudent(uid, quizzes);
      }
    } catch (e) {
      debugPrint('[NotificationSyncService] syncFromSupabaseNow quizzes notice: $e');
    }

    try {
      final assignments = await SupabaseService.instance.fetchAllAssignments();
      if (assignments.isNotEmpty) {
        await _processSupabaseAssignmentsForStudent(uid, assignments);
      }
    } catch (e) {
      debugPrint('[NotificationSyncService] syncFromSupabaseNow assignments notice: $e');
    }

    try {
      final supaNotifs = await SupabaseService.instance.fetchNotifications(uid);
      if (supaNotifs.isNotEmpty) {
        for (final item in supaNotifs) {
          final notif = AppNotification.fromMap(item);
          await processIncomingNotification(notif, showBanner: false);
        }
      }
    } catch (_) {}
  }

  Future<void> _processSupabaseQuizzesForStudent(
    String studentId,
    List<Map<String, dynamic>> quizzes,
  ) async {
    try {
      final db = await _db.database;
      for (final q in quizzes) {
        final qIdStr = q['id']?.toString() ?? '';
        final title = (q['title']?.toString() ?? '').trim();
        if (qIdStr.isEmpty || title.isEmpty || title == '1') continue;
        final status = q['status']?.toString() ?? 'published';
        if (status == 'draft') continue;

        final subMap = q['subjects'] is Map ? Map<String, dynamic>.from(q['subjects']) : null;
        final subName = subMap?['name']?.toString() ?? 'Course';
        final rawSubId = int.tryParse(q['subject_id']?.toString() ?? '') ?? 0;

        // Ensure quiz exists in local SQLite
        int localQuizId = 0;
        final existingQuiz = await db.query(
          'quizzes',
          where: 'cloud_id = ? OR (LOWER(title) = ? AND subject_id = ?)',
          whereArgs: [qIdStr, title.toLowerCase(), rawSubId],
        );
        if (existingQuiz.isNotEmpty) {
          localQuizId = (existingQuiz.first['id'] as num).toInt();
        } else {
          localQuizId = await db.insert('quizzes', {
            'cloud_id': qIdStr,
            'title': title,
            'description': q['description']?.toString() ?? '',
            'subject_id': rawSubId,
            'teacher_id': q['teacher_id']?.toString() ?? 'teacher_1',
            'teacher_name': q['teacher_name']?.toString() ?? 'Teacher',
            'time_limit_minutes': q['time_limit_minutes'] ?? 0,
            'passing_score': q['passing_score'] ?? 70,
            'status': 'published',
            'created_at': q['created_at']?.toString() ?? DateTime.now().toIso8601String(),
          });
          final qList = q['questions_json'] is List ? q['questions_json'] as List : [];
          for (final quest in qList) {
            if (quest is Map) {
              await db.insert('questions', {
                'quiz_id': localQuizId,
                'question_text': quest['question_text'] ?? '',
                'option_a': quest['option_a'] ?? '',
                'option_b': quest['option_b'] ?? '',
                'option_c': quest['option_c'] ?? '',
                'option_d': quest['option_d'] ?? '',
                'correct_option': quest['correct_option'] ?? 'A',
                'created_at': q['created_at']?.toString() ?? DateTime.now().toIso8601String(),
              });
            }
          }
        }

        // Check if student already completed this quiz
        final attempts = await db.query(
          'quiz_attempts',
          where: 'student_id = ? AND (quiz_id = ? OR quiz_id = ?)',
          whereArgs: [studentId, localQuizId, int.tryParse(qIdStr) ?? -1],
        );
        if (attempts.isNotEmpty) continue;

        // Check if notification already delivered
        final existingNotif = await db.query(
          'notifications',
          where: 'user_id = ? AND (related_id = ? OR related_id = ? OR (title = ? AND type = ?))',
          whereArgs: [studentId, qIdStr, localQuizId.toString(), 'New Quiz: $title', 'quiz_assigned'],
        );
        if (existingNotif.isNotEmpty) continue;

        // Generate and dispatch notification
        final notifId = 'notif_quiz_${localQuizId}_${DateTime.now().millisecondsSinceEpoch}';
        final notif = AppNotification(
          id: notifId,
          userId: studentId,
          type: 'quiz_assigned',
          title: 'New Quiz: $title',
          message: 'A new quiz "$title" has been assigned in $subName.',
          isRead: false,
          createdAt: q['created_at']?.toString() ?? DateTime.now().toIso8601String(),
          relatedId: localQuizId.toString(),
          targetRoute: '/student/courses',
          subjectId: rawSubId,
          actorName: q['teacher_name']?.toString() ?? 'Faculty',
        );

        await db.insert('notifications', notif.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

        final context = rootNavigatorKey.currentContext;
        if (context != null && context.mounted) {
          InAppNotificationBanner.show(context, notif);
        }
        DeviceNotificationService.instance.showFromAppNotification(notif);

        if (!_streamController.isClosed) {
          _streamController.add([notif]);
        }
      }
    } catch (e) {
      debugPrint('[NotificationSyncService] _processSupabaseQuizzesForStudent error: $e');
    }
  }

  Future<void> _processSupabaseAssignmentsForStudent(
    String studentId,
    List<Map<String, dynamic>> assignments,
  ) async {
    try {
      final db = await _db.database;
      for (final a in assignments) {
        final aIdStr = a['id']?.toString() ?? '';
        final title = (a['title']?.toString() ?? '').trim();
        if (aIdStr.isEmpty || title.isEmpty) continue;

        final subMap = a['subjects'] is Map ? Map<String, dynamic>.from(a['subjects']) : null;
        final subName = subMap?['name']?.toString() ?? 'Course';
        final rawSubId = int.tryParse(a['subject_id']?.toString() ?? '') ?? 0;

        // Ensure assignment exists in local SQLite
        int localAssignmentId = 0;
        final existingA = await db.query(
          'assignments',
          where: 'cloud_id = ? OR (LOWER(title) = ? AND subject_id = ?)',
          whereArgs: [aIdStr, title.toLowerCase(), rawSubId],
        );
        if (existingA.isNotEmpty) {
          localAssignmentId = (existingA.first['id'] as num).toInt();
        } else {
          localAssignmentId = await db.insert('assignments', {
            'cloud_id': aIdStr,
            'title': title,
            'description': a['description']?.toString() ?? '',
            'subject_id': rawSubId,
            'teacher_id': a['teacher_id']?.toString() ?? 'teacher_1',
            'teacher_name': a['teacher_name']?.toString() ?? 'Teacher',
            'due_date': a['due_date']?.toString(),
            'created_at': a['created_at']?.toString() ?? DateTime.now().toIso8601String(),
          });
        }

        // Check if student already submitted this assignment
        final submissions = await db.query(
          'submissions',
          where: 'student_id = ? AND (assignment_id = ? OR assignment_id = ?)',
          whereArgs: [studentId, localAssignmentId.toString(), aIdStr],
        );
        if (submissions.isNotEmpty) continue;

        // Check if notification already delivered
        final existingNotif = await db.query(
          'notifications',
          where: 'user_id = ? AND (related_id = ? OR related_id = ? OR (title = ? AND type = ?))',
          whereArgs: [studentId, aIdStr, localAssignmentId.toString(), 'New Assignment: $title', 'new_assignment'],
        );
        if (existingNotif.isNotEmpty) continue;

        final notifId = 'notif_assign_${localAssignmentId}_${DateTime.now().millisecondsSinceEpoch}';
        final notif = AppNotification(
          id: notifId,
          userId: studentId,
          type: 'new_assignment',
          title: 'New Assignment: $title',
          message: 'A new assignment "$title" was posted in $subName.',
          isRead: false,
          createdAt: a['created_at']?.toString() ?? DateTime.now().toIso8601String(),
          relatedId: localAssignmentId.toString(),
          targetRoute: '/student/courses',
          subjectId: rawSubId,
          actorName: a['teacher_name']?.toString() ?? 'Faculty',
        );

        await db.insert('notifications', notif.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

        final context = rootNavigatorKey.currentContext;
        if (context != null && context.mounted) {
          InAppNotificationBanner.show(context, notif);
        }
        DeviceNotificationService.instance.showFromAppNotification(notif);

        if (!_streamController.isClosed) {
          _streamController.add([notif]);
        }
      }
    } catch (e) {
      debugPrint('[NotificationSyncService] _processSupabaseAssignmentsForStudent error: $e');
    }
  }

  Future<List<AppNotification>> _handleSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) async {
    final newNotifications = <AppNotification>[];

    for (final change in snapshot.docChanges) {
      if (change.type == DocumentChangeType.added || change.type == DocumentChangeType.modified) {
        final doc = change.doc;
        final data = Map<String, dynamic>.from(doc.data() ?? {});
        data.putIfAbsent('id', () => doc.id);

        final notif = AppNotification.fromMap(data);
        final eval = await processIncomingNotification(
          notif,
          showBanner: change.type == DocumentChangeType.added,
        );

        if (eval.shouldPersist) {
          newNotifications.add(notif);
        }
      }
    }

    return newNotifications;
  }

  /// Processes an incoming notification through the filtering engine,
  /// saves to SQLite if evaluated as shouldPersist, and triggers in-app banner alert if shouldAlert.
  Future<NotificationEvaluation> processIncomingNotification(
    AppNotification notif, {
    bool showBanner = true,
  }) async {
    final eventTime = DateTime.tryParse(notif.createdAt) ?? DateTime.now();
    final eval = _filterService.evaluate(
      userId: notif.userId,
      type: notif.type,
      title: notif.title,
      eventTime: eventTime,
      relatedId: notif.relatedId,
      actorId: notif.actorId,
    );

    if (eval.shouldPersist) {
      final db = await _db.database;
      final existing = await db.query(
        'notifications',
        where: 'id = ?',
        whereArgs: [notif.id],
      );

      if (existing.isEmpty) {
        await db.insert('notifications', notif.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }

      if (eval.shouldAlert && showBanner) {
        final context = rootNavigatorKey.currentContext;
        if (context != null && context.mounted) {
          InAppNotificationBanner.show(context, notif);
        }
        // Trigger OS-level system notification popup outside the app
        DeviceNotificationService.instance.showFromAppNotification(notif);
      }

      if (!_streamController.isClosed) {
        _streamController.add([notif]);
      }
    }

    return eval;
  }

  @override
  void stopSync() {
    _subscription?.cancel();
    _subscription = null;
    _supabaseQuizSub?.cancel();
    _supabaseQuizSub = null;
    _supabaseAssignmentSub?.cancel();
    _supabaseAssignmentSub = null;
    _supabaseNotifSub?.cancel();
    _supabaseNotifSub = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    _activeUserId = null;
  }

  void dispose() {
    stopSync();
    _streamController.close();
  }
}
