import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
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

/// Production service providing real-time Cloud Firestore snapshot synchronization
/// for incoming notifications, integrating deduplication, rate limiting, and stale
/// event suppression before persisting to SQLite and showing banners.
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
  String? _activeUserId;
  final StreamController<List<AppNotification>> _streamController =
      StreamController<List<AppNotification>>.broadcast();

  @override
  Stream<List<AppNotification>> get notificationStream => _streamController.stream;

  String? get activeUserId => _activeUserId;
  bool get isSyncing => _subscription != null;

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
    if (_activeUserId == cleanUid && _subscription != null) return;

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
    _activeUserId = null;
  }

  void dispose() {
    stopSync();
    _streamController.close();
  }
}
