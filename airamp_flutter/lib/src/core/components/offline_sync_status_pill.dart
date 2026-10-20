import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/offline_sync_provider.dart';
import '../theme/app_theme.dart';

class OfflineSyncStatusPill extends ConsumerStatefulWidget {
  final bool compact;

  const OfflineSyncStatusPill({
    super.key,
    this.compact = false,
  });

  @override
  ConsumerState<OfflineSyncStatusPill> createState() => _OfflineSyncStatusPillState();
}

class _OfflineSyncStatusPillState extends ConsumerState<OfflineSyncStatusPill>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  String _formatLastSynced(DateTime dt) {
    final now = DateTime.now();
    final difference = now.difference(dt);

    if (difference.inSeconds < 45) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
  }

  void _triggerManualSync() async {
    final syncNotifier = ref.read(offlineSyncProvider.notifier);
    _rotationController.repeat();
    await syncNotifier.syncNow();
    if (mounted) {
      _rotationController.stop();
      _rotationController.reset();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.cloud_done_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              const Text('AIRAMP database synced successfully with cloud storage!'),
            ],
          ),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showSyncDetailsDialog(BuildContext context, OfflineSyncState syncState, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (syncState.isOnline ? AppTheme.primary : AppTheme.warning)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                syncState.isOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                color: syncState.isOnline ? AppTheme.primary : AppTheme.warning,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Database Synchronization',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppTheme.darkText : AppTheme.lightText,
                    ),
                  ),
                  Text(
                    'Offline SQLite & Cloud Status',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurfaceLight : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Connection Status',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: syncState.isOnline ? AppTheme.primary : AppTheme.warning,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            syncState.isOnline ? 'Online (Synced)' : 'Offline Mode',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: syncState.isOnline ? AppTheme.primary : AppTheme.warning,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Last Cloud Sync',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                        ),
                      ),
                      Text(
                        _formatLastSynced(syncState.lastSyncedAt),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppTheme.darkText : AppTheme.lightText,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Pending Queued Items',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: (syncState.pendingQueueCount > 0 ? AppTheme.warning : AppTheme.primary)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${syncState.pendingQueueCount} items',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: syncState.pendingQueueCount > 0 ? AppTheme.warning : AppTheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'AIRAMP caches curriculum, topics, and quiz questions in local SQLite. Assessment answers and enrollments auto-sync whenever internet is active.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(offlineSyncProvider.notifier).setConnectivity(isOnline: !syncState.isOnline);
              Navigator.pop(ctx);
            },
            child: Text(
              syncState.isOnline ? 'Simulate Offline' : 'Set Online',
              style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _triggerManualSync();
            },
            icon: const Icon(Icons.sync_rounded, size: 16),
            label: const Text('Sync Now'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(offlineSyncProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isSyncing = syncState.isSyncing;
    final isOnline = syncState.isOnline;
    final lastSyncedStr = _formatLastSynced(syncState.lastSyncedAt);

    final statusColor = isSyncing
        ? const Color(0xFF0284C7) // Sky blue during sync
        : isOnline
            ? AppTheme.primary // Emerald
            : const Color(0xFFD97706); // Amber / orange

    final statusLabel = isSyncing
        ? 'Syncing...'
        : isOnline
            ? 'Cloud Synced'
            : syncState.pendingQueueCount > 0
                ? 'Offline • Queued (${syncState.pendingQueueCount})'
                : 'Offline Mode';

    final tooltipMessage = 'Database Status: ${isOnline ? 'Online (SQLite & Cloud Connected)' : 'Offline (Local Storage Active)'}\n'
        'Last Synced: $lastSyncedStr\n'
        'Pending Changes: ${syncState.pendingQueueCount}\n'
        'Click to view details or sync database';

    if (widget.compact) {
      return Tooltip(
        message: tooltipMessage,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _showSyncDetailsDialog(context, syncState, isDark),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSyncing)
                  RotationTransition(
                    turns: _rotationController,
                    child: Icon(Icons.sync_rounded, size: 13, color: statusColor),
                  )
                else
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: statusColor,
                    ),
                  ),
                const SizedBox(width: 6),
                Text(
                  isSyncing
                      ? 'Syncing'
                      : isOnline
                          ? 'Synced'
                          : 'Offline',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.darkText : AppTheme.lightText,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Tooltip(
      message: tooltipMessage,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 4, 6, 4),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.02),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status Dot or Rotating Sync Icon
            if (isSyncing)
              RotationTransition(
                turns: _rotationController,
                child: Icon(Icons.sync_rounded, size: 14, color: statusColor),
              )
            else
              InkWell(
                onTap: () => _showSyncDetailsDialog(context, syncState, isDark),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: statusColor,
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 8),

            // Status Text & Last Synced Timestamp
            InkWell(
              onTap: () => _showSyncDetailsDialog(context, syncState, isDark),
              borderRadius: BorderRadius.circular(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppTheme.darkText : AppTheme.lightText,
                    ),
                  ),
                  Text(
                    'Synced $lastSyncedStr',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w400,
                      color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Manual "Sync Now" Button
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: isSyncing ? null : _triggerManualSync,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurfaceLight : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.sync_rounded,
                        size: 12,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Sync Now',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppTheme.darkText : AppTheme.lightText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
