import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_helper.dart';
import '../../../routing/app_router.dart';
import '../../auth/application/auth_provider.dart';
import '../domain/notification_model.dart';
import '../presentation/components/in_app_notification_banner.dart';

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

  @override
  NotificationState build() {
    final currentUser = ref.watch(authProvider);
    if (currentUser != null) {
      Future.microtask(() => loadNotifications());
      return const NotificationState(isLoading: true);
    }
    return const NotificationState();
  }

  Future<void> loadNotifications() async {
    final user = ref.read(authProvider);
    if (user == null) {
      state = const NotificationState();
      return;
    }

    try {
      final rawList = await _db.getNotificationsForUser(user.id);
      final list = rawList.map((m) => AppNotification.fromMap(m)).toList();
      final unread = list.where((n) => !n.isRead).length;

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
        state = state.copyWith(
          notifications: [notif, ...state.notifications],
          unreadCount: state.unreadCount + 1,
        );

        if (showBanner) {
          final context = rootNavigatorKey.currentContext;
          if (context != null && context.mounted) {
            InAppNotificationBanner.show(context, notif);
          }
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

      final unread = updated.where((n) => !n.isRead).length;
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
      final unread = updated.where((n) => !n.isRead).length;
      state = state.copyWith(
        notifications: updated,
        unreadCount: unread,
      );
    } catch (_) {}
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
