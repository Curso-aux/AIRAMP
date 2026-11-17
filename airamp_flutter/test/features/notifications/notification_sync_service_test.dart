import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:airamp_flutter/src/core/database/database_helper.dart';
import 'package:airamp_flutter/src/features/notifications/application/notification_sync_service.dart';
import 'package:airamp_flutter/src/features/notifications/domain/notification_filter_service.dart';
import 'package:airamp_flutter/src/features/notifications/domain/notification_model.dart';

void main() {
  late DatabaseHelper dbHelper;
  late NotificationFilterService filterService;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    DatabaseHelper.resetForTesting();
    NotificationSyncService.resetForTesting();
    dbHelper = DatabaseHelper();
    filterService = NotificationFilterService();
    filterService.reset();

    final db = await dbHelper.database;
    await db.delete('notifications');
  });

  tearDown(() {
    NotificationSyncService.resetForTesting();
  });

  group('NotificationSyncService Lifecycle & Event Delegation Tests', () {
    test('startSync sets activeUserId and initiates sync stream subscription', () async {
      final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
      addTearDown(controller.close);

      final syncService = NotificationSyncService(
        filterService: filterService,
        dbHelper: dbHelper,
        streamFactory: (uid) => controller.stream,
      );

      expect(syncService.isSyncing, isFalse);
      expect(syncService.activeUserId, isNull);

      syncService.startSync('student_sync_01');

      expect(syncService.isSyncing, isTrue);
      expect(syncService.activeUserId, 'student_sync_01');

      syncService.stopSync();
      expect(syncService.isSyncing, isFalse);
      expect(syncService.activeUserId, isNull);
    });

    test('listens to snapshot events and delegates to NotificationFilterService', () async {
      final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
      addTearDown(controller.close);

      final syncService = NotificationSyncService(
        filterService: filterService,
        dbHelper: dbHelper,
        streamFactory: (uid) => controller.stream,
      );

      final receivedStreamEvents = <List<AppNotification>>[];
      final sub = syncService.notificationStream.listen((events) {
        receivedStreamEvents.add(events);
      });
      addTearDown(sub.cancel);

      syncService.startSync('student_sync_01');

      final notifPayload = {
        'id': 'notif_sync_test_001',
        'user_id': 'student_sync_01',
        'type': 'new_assignment',
        'title': 'Operating Systems Assignment 2',
        'message': 'Kernel threads and memory mapping',
        'created_at': DateTime.now().toIso8601String(),
        'related_id': 'assign_os_02',
        'is_read': 0,
      };

      // Push incoming snapshot payload
      controller.add([notifPayload]);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // 1. Verify stream controller delivered notification
      expect(receivedStreamEvents.isNotEmpty, isTrue);
      expect(receivedStreamEvents.first.first.id, 'notif_sync_test_001');
      expect(receivedStreamEvents.first.first.title, 'Operating Systems Assignment 2');

      // 2. Verify persisted in SQLite
      final db = await dbHelper.database;
      final rows = await db.query(
        'notifications',
        where: 'id = ?',
        whereArgs: ['notif_sync_test_001'],
      );
      expect(rows.length, 1);
      expect(rows.first['title'], 'Operating Systems Assignment 2');
    });

    test('deduplicates identical repeat events received through snapshot stream', () async {
      final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
      addTearDown(controller.close);

      final syncService = NotificationSyncService(
        filterService: filterService,
        dbHelper: dbHelper,
        streamFactory: (uid) => controller.stream,
      );

      final receivedStreamEvents = <List<AppNotification>>[];
      final sub = syncService.notificationStream.listen((events) {
        receivedStreamEvents.add(events);
      });
      addTearDown(sub.cancel);

      syncService.startSync('student_sync_01');

      final now = DateTime.now().toIso8601String();
      final payload1 = {
        'id': 'notif_dedup_01',
        'user_id': 'student_sync_01',
        'type': 'quiz_assigned',
        'title': 'Calculus Quiz 3',
        'message': 'Derivatives and integrals',
        'created_at': now,
        'related_id': 'quiz_calc_03',
        'is_read': 0,
      };
      final payload2 = {
        'id': 'notif_dedup_02',
        'user_id': 'student_sync_01',
        'type': 'quiz_assigned',
        'title': 'Calculus Quiz 3',
        'message': 'Derivatives and integrals',
        'created_at': now,
        'related_id': 'quiz_calc_03',
        'is_read': 0,
      };

      // Emit first notification
      controller.add([payload1]);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(receivedStreamEvents.length, 1);

      // Emit duplicate notification with identical parameters
      controller.add([payload2]);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // FilterService should suppress duplicate -> stream events count remains 1
      expect(receivedStreamEvents.length, 1);

      final db = await dbHelper.database;
      final rows = await db.query(
        'notifications',
        where: 'title = ?',
        whereArgs: ['Calculus Quiz 3'],
      );
      expect(rows.length, 1);
    });

    test('processIncomingNotification suppresses stale notifications older than 24h from alerting', () async {
      final syncService = NotificationSyncService(
        filterService: filterService,
        dbHelper: dbHelper,
      );

      final staleNotification = AppNotification(
        id: 'notif_stale_01',
        userId: 'student_sync_01',
        type: 'announcement',
        title: 'Old Notice',
        message: 'This happened two days ago',
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(hours: 48)).toIso8601String(),
      );

      final eval = await syncService.processIncomingNotification(staleNotification, showBanner: false);

      // Stale notifications should still persist for audit history, but should NOT fire alerts
      expect(eval.isStale, isTrue);
      expect(eval.shouldAlert, isFalse);
      expect(eval.shouldPersist, isTrue);

      final db = await dbHelper.database;
      final rows = await db.query(
        'notifications',
        where: 'id = ?',
        whereArgs: ['notif_stale_01'],
      );
      expect(rows.length, 1);
    });
  });
}
