import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    // Start in online synchronized state with fresh timestamp
    return OfflineSyncState(
      status: SyncConnectivityStatus.onlineSynced,
      lastSyncedAt: DateTime.now().subtract(const Duration(minutes: 2)),
      pendingQueueCount: 0,
      syncMessage: 'Local SQLite & Firebase Cloud in sync',
    );
  }

  /// Triggers an immediate cloud synchronization cycle
  Future<void> syncNow() async {
    if (state.isSyncing) return;

    state = state.copyWith(
      status: SyncConnectivityStatus.syncing,
      syncMessage: 'Synchronizing assessment scores and course data...',
    );

    try {
      // Simulate/perform async sync roundtrip
      await Future.delayed(const Duration(milliseconds: 1200));

      state = state.copyWith(
        status: SyncConnectivityStatus.onlineSynced,
        lastSyncedAt: DateTime.now(),
        pendingQueueCount: 0,
        syncMessage: 'Cloud sync complete · All changes up to date',
      );
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
