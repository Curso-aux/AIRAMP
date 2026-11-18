import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_helper.dart';
import '../../../routing/app_router.dart';
import '../../auth/application/auth_provider.dart';
import '../domain/notification_model.dart';
import '../presentation/components/in_app_notification_banner.dart';
import 'device_notification_service.dart';
import 'notification_sync_service.dart';

class NotificationState {
  final List<AppNotification> notifications;
  final int unreadCount;
  final bool isLoading;

  const NotificationState({
    this.notifications = const [],
    this.unreadCount = 0,
    this.isLoading = false,
  });

  NotificationState copyWith({
    List<AppNotification>? notifications,
    int? unreadCount,
    bool? isLoading,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class NotificationNotifier extends Notifier<NotificationState> {
  final DatabaseHelper _db = DatabaseHelper();
  StreamSubscription? _syncSub;

  @override
  NotificationState build() {
    final currentUser = ref.watch(authProvider);
    if (currentUser != null) {
      Future.microtask(() => loadNotifications());
      _listenToSync();
      return const NotificationState(isLoading: true);
    }
    _syncSub?.cancel();
    _syncSub = null;
    return const NotificationState();
  }

  void _listenToSync() {
    _syncSub?.cancel();
    _syncSub = NotificationSyncService().notificationStream.listen((incoming) {
      if (incoming.isEmpty) return;
      final existingIds = state.notifications.map((n) => n.id).toSet();
      final newItems = incoming.where((n) => !existingIds.contains(n.id)).toList();
      if (newItems.isNotEmpty) {
        final unreadCountDelta = newItems
            .where((n) => !n.isRead && n.type != 'chat' && n.type != 'group_chat')
            .length;
        state = state.copyWith(
          notifications: [...newItems, ...state.notifications],
          unreadCount: state.unreadCount + unreadCountDelta,
        );
      }
    });
  }

  Future<void> loadNotifications() async {
    final user = ref.read(authProvider);
    if (user == null) {
      state = const NotificationState();
      return;
    }

    try {
      // Sync latest cloud events from Supabase first
      await NotificationSyncService().syncFromSupabaseNow(userId: user.id);
      final rawList = await _db.getNotificationsForUser(user.id);
      final list = rawList.map((m) => AppNotification.fromMap(m)).toList();
      final unread = list.where((n) => !n.isRead && n.type != 'chat' && n.type != 'group_chat').length;

      state = NotificationState(
        notifications: list,
        unreadCount: unread,
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Adds a notification for the specified user (or current user if userId not provided).
  /// Automatically saves to SQLite DB and displays in-app banner alert if [showBanner] is true.
  Future<AppNotification?> addNotification({
    String? userId,
    required String type,
    required String title,
    required String message,
    String? relatedId,
    String? targetRoute,
    int? subjectId,
    String? actorId,
    String? actorName,
    bool showBanner = true,
  }) async {
    final targetUserId = userId ?? ref.read(authProvider)?.id;
    if (targetUserId == null) return null;

    try {
      final id = await _db.createNotification(
        userId: targetUserId,
        type: type,
        title: title,
        message: message,
        relatedId: relatedId,
        targetRoute: targetRoute,
        subjectId: subjectId,
        actorId: actorId,
        actorName: actorName,
      );

      final notif = AppNotification(
        id: id,
        userId: targetUserId,
        type: type,
        title: title,
        message: message,
        isRead: false,
        createdAt: DateTime.now().toIso8601String(),
        relatedId: relatedId,
        targetRoute: targetRoute,
        subjectId: subjectId,
        actorId: actorId,
        actorName: actorName,
      );

      // Only add to in-memory state if this notification belongs to currently logged-in user
      final currentUser = ref.read(authProvider);
      if (currentUser != null && currentUser.id == targetUserId) {
        final isChatNoise = notif.type == 'chat' || notif.type == 'group_chat';
        state = state.copyWith(
          notifications: [notif, ...state.notifications],
          unreadCount: isChatNoise ? state.unreadCount : state.unreadCount + 1,
        );

        if (showBanner) {
          final context = rootNavigatorKey.currentContext;
          if (context != null && context.mounted) {
            InAppNotificationBanner.show(context, notif);
          }
          // Trigger system-level device notification popup outside the app
          DeviceNotificationService.instance.showFromAppNotification(notif);
        }
      }

      return notif;
    } catch (_) {
      return null;
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      await _db.markNotificationRead(id);
      final updated = state.notifications.map((n) {
        if (n.id == id) {
          return n.copyWith(isRead: true);
        }
        return n;
      }).toList();

      final unread = updated.where((n) => !n.isRead && n.type != 'chat' && n.type != 'group_chat').length;
      state = state.copyWith(
        notifications: updated,
        unreadCount: unread,
      );
    } catch (_) {}
  }

  Future<void> markAllAsRead() async {
    final user = ref.read(authProvider);
    if (user == null) return;

    try {
      await _db.markAllNotificationsRead(user.id);
      final updated = state.notifications.map((n) => n.copyWith(isRead: true)).toList();
      state = state.copyWith(
        notifications: updated,
        unreadCount: 0,
      );
    } catch (_) {}
  }

  Future<void> deleteNotification(String id) async {
    try {
      await _db.deleteNotification(id);
      final updated = state.notifications.where((n) => n.id != id).toList();
      final unread = updated.where((n) => !n.isRead && n.type != 'chat' && n.type != 'group_chat').length;
      state = state.copyWith(
        notifications: updated,
        unreadCount: unread,
      );
    } catch (_) {}
  }

  /// Batch deletes multiple notifications by their IDs and updates state atomically.
  Future<int> deleteBatchNotifications(List<String> ids) async {
    if (ids.isEmpty) return 0;
    try {
      final count = await _db.batchDeleteNotifications(ids);
      final idSet = ids.toSet();
      final updated = state.notifications.where((n) => !idSet.contains(n.id)).toList();
      final unread = updated.where((n) => !n.isRead && n.type != 'chat' && n.type != 'group_chat').length;

      state = state.copyWith(
        notifications: updated,
        unreadCount: unread,
      );
      return count;
    } catch (_) {
      return 0;
    }
  }

  /// Filters current in-memory notifications by search [query] and [category].
  List<AppNotification> filterByQuery(String query, {String category = 'all'}) {
    final q = query.trim().toLowerCase();
    return state.notifications.where((n) {
      // Exclude chat join/message noise from the academic Notification Center
      if (n.type == 'chat' || n.type == 'group_chat') return false;

      if (category == 'unread' && n.isRead) return false;
      if (category == 'assignments' &&
          !['new_assignment', 'activity_submission', 'grade_released', 'resubmission_allowed'].contains(n.type)) {
        return false;
      }
      if ((category == 'quizzes' || category == 'assessments') &&
          !['quiz', 'quiz_assigned', 'quiz_completed'].contains(n.type) &&
          !n.type.contains('quiz')) {
        return false;
      }
      if (category == 'announcements' && n.type != 'announcement') return false;

      if (q.isEmpty) return true;
      final titleMatch = n.title.toLowerCase().contains(q);
      final msgMatch = n.message.toLowerCase().contains(q);
      final typeMatch = n.type.toLowerCase().contains(q);
      final actorMatch = (n.actorName ?? '').toLowerCase().contains(q);
      return titleMatch || msgMatch || typeMatch || actorMatch;
    }).toList();
  }

  Future<void> clearAll() async {
    final user = ref.read(authProvider);
    if (user == null) return;

    try {
      await _db.clearNotificationsForUser(user.id);
      state = state.copyWith(
        notifications: const [],
        unreadCount: 0,
      );
    } catch (_) {}
  }
}

final notificationsProvider = NotifierProvider<NotificationNotifier, NotificationState>(() {
  return NotificationNotifier();
});

final unreadNotificationCountProvider = Provider<int>((ref) {
  return ref.watch(notificationsProvider).unreadCount;
});

class NotificationSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
  void clear() => state = '';
}

final notificationSearchQueryProvider =
    NotifierProvider<NotificationSearchQueryNotifier, String>(() {
  return NotificationSearchQueryNotifier();
});

class NotificationCategoryFilterNotifier extends Notifier<String> {
  @override
  String build() => 'all';

  void setCategory(String category) => state = category;
}

final notificationCategoryFilterProvider =
    NotifierProvider<NotificationCategoryFilterNotifier, String>(() {
  return NotificationCategoryFilterNotifier();
});

/// Reactive provider delivering filtered notifications based on real-time search query and category filter.
final filteredNotificationsProvider = Provider<List<AppNotification>>((ref) {
  final notifState = ref.watch(notificationsProvider);
  final query = ref.watch(notificationSearchQueryProvider).trim().toLowerCase();
  final category = ref.watch(notificationCategoryFilterProvider);

  return notifState.notifications.where((n) {
    // Exclude chat join/message noise from the academic Notification Center
    if (n.type == 'chat' || n.type == 'group_chat') return false;

    if (category == 'unread' && n.isRead) return false;
    if (category == 'assignments' &&
        !['new_assignment', 'activity_submission', 'grade_released', 'resubmission_allowed'].contains(n.type)) {
      return false;
    }
    if ((category == 'quizzes' || category == 'assessments') &&
        !['quiz', 'quiz_assigned', 'quiz_completed'].contains(n.type) &&
        !n.type.contains('quiz')) {
      return false;
    }
    if (category == 'announcements' && n.type != 'announcement') return false;

    if (query.isEmpty) return true;
    final titleMatch = n.title.toLowerCase().contains(query);
    final msgMatch = n.message.toLowerCase().contains(query);
    final typeMatch = n.type.toLowerCase().contains(query);
    final actorMatch = (n.actorName ?? '').toLowerCase().contains(query);
    return titleMatch || msgMatch || typeMatch || actorMatch;
  }).toList();
});
