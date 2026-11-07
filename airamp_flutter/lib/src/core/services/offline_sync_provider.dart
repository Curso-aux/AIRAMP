import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_helper.dart';
import '../database/firestore_service.dart';
import '../../features/admin/data/admin_repository.dart';
import '../../features/super_admin/data/super_admin_repository.dart';

enum SyncConnectivityStatus {
  onlineSynced,
  offlineQueued,
  syncing,
}

class OfflineSyncState {
  final SyncConnectivityStatus status;
  final DateTime lastSyncedAt;
  final int pendingQueueCount;
  final String syncMessage;

  const OfflineSyncState({
    required this.status,
    required this.lastSyncedAt,
    required this.pendingQueueCount,
    this.syncMessage = 'All database records synchronized',
  });

  bool get isOnline => status == SyncConnectivityStatus.onlineSynced || status == SyncConnectivityStatus.syncing;
  bool get isSyncing => status == SyncConnectivityStatus.syncing;
  bool get isOffline => status == SyncConnectivityStatus.offlineQueued;

  OfflineSyncState copyWith({
    SyncConnectivityStatus? status,
    DateTime? lastSyncedAt,
    int? pendingQueueCount,
    String? syncMessage,
  }) {
    return OfflineSyncState(
      status: status ?? this.status,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      pendingQueueCount: pendingQueueCount ?? this.pendingQueueCount,
      syncMessage: syncMessage ?? this.syncMessage,
    );
  }
}

class OfflineSyncNotifier extends Notifier<OfflineSyncState> {
  Timer? _periodicSyncTimer;

  @override
  OfflineSyncState build() {
    ref.onDispose(() {
      _periodicSyncTimer?.cancel();
    });

    // Wire up real-time user sync callback to immediately notify Riverpod UI
    void handleSync() {
      try {
        ref.read(schoolAdminsProvider.notifier).loadAdmins();
        ref.read(archivedSchoolAdminsProvider.notifier).loadArchivedAdmins();
        ref.read(adminTeachersProvider.notifier).loadTeachers();
        ref.read(adminArchivedTeachersProvider.notifier).loadArchivedTeachers();
        ref.read(adminStudentsProvider.notifier).loadStudents();
        ref.read(adminArchivedStudentsProvider.notifier).loadArchived();
        ref.read(schoolsListProvider.notifier).loadSchools();
        ref.invalidate(superAdminStatsProvider);
      } catch (_) {}
    }

    FirestoreService.addSyncListener(handleSync);
    ref.onDispose(() {
      FirestoreService.removeSyncListener(handleSync);
    });

    // Activate Firestore real-time live listener
    FirestoreService().startRealtimeUserSync();

    // On native mobile/desktop (!kIsWeb), periodic sync checks connectivity for queued offline actions.
    // Throttled to 15 minutes to preserve battery and remain well within Firebase free tier quotas.
    if (!kIsWeb) {
      _periodicSyncTimer = Timer.periodic(const Duration(minutes: 15), (_) {
        syncNow();
      });
      // Proactively perform initial sync in background on mobile
      Future.microtask(() => syncNow());
    }

    return OfflineSyncState(
      status: SyncConnectivityStatus.onlineSynced,
      lastSyncedAt: DateTime.now().subtract(const Duration(minutes: 2)),
      pendingQueueCount: 0,
      syncMessage: 'Local SQLite & Firebase Cloud in sync',
    );
  }

  /// Triggers a cloud synchronization cycle. Pass [force] = true on manual button clicks.
  Future<void> syncNow({bool force = false}) async {
    if (state.isSyncing) return;

    if (force) {
      FirestoreService().invalidateUsersSyncCache();
    }

    state = state.copyWith(
      status: SyncConnectivityStatus.syncing,
      syncMessage: 'Synchronizing assessment scores and course data...',
    );

    try {
      // Perform bidirectional Cloud Firestore to local SQLite sync roundtrip
      await DatabaseHelper().syncAllCloudData(force: force);

      state = state.copyWith(
        status: SyncConnectivityStatus.onlineSynced,
        lastSyncedAt: DateTime.now(),
        pendingQueueCount: 0,
        syncMessage: 'Cloud sync complete · All changes up to date',
      );

      // Trigger UI reload of all directories immediately
      try {
        FirestoreService.onUserSynced?.call();
      } catch (_) {}
    } catch (e) {
      debugPrint('[OfflineSync] Sync failed: $e');
      state = state.copyWith(
        status: SyncConnectivityStatus.offlineQueued,
        pendingQueueCount: state.pendingQueueCount + 1,
        syncMessage: 'Sync failed: Changes queued locally for retry',
      );
    }
  }

  /// Toggle connectivity simulation (useful for testing or manual offline switch)
  void setConnectivity({required bool isOnline}) {
    if (isOnline) {
      state = state.copyWith(
        status: SyncConnectivityStatus.onlineSynced,
        syncMessage: 'Connected to AIRAMP Cloud server',
      );
    } else {
      state = state.copyWith(
        status: SyncConnectivityStatus.offlineQueued,
        pendingQueueCount: state.pendingQueueCount > 0 ? state.pendingQueueCount : 3,
        syncMessage: 'Offline Mode: Assessments stored locally in SQLite',
      );
    }
  }

  /// Queue a local mutation when offline
  void incrementPendingQueue([int count = 1]) {
    state = state.copyWith(
      pendingQueueCount: state.pendingQueueCount + count,
      status: SyncConnectivityStatus.offlineQueued,
      syncMessage: '${state.pendingQueueCount + count} assessments queued for cloud sync',
    );
  }
}

final offlineSyncProvider = NotifierProvider<OfflineSyncNotifier, OfflineSyncState>(() {
  return OfflineSyncNotifier();
});
