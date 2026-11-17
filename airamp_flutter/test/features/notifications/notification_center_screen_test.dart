import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airamp_flutter/src/routing/app_router.dart';
import 'package:airamp_flutter/src/features/auth/application/auth_provider.dart';
import 'package:airamp_flutter/src/features/notifications/application/notification_provider.dart';
import 'package:airamp_flutter/src/features/notifications/domain/notification_model.dart';
import 'package:airamp_flutter/src/features/notifications/presentation/notification_center_screen.dart';

class FakeAuthNotifier extends AuthNotifier {
  final User? _user;
  FakeAuthNotifier(this._user);

  @override
  User? build() => _user;
}

class FakeNotificationsNotifier extends NotificationNotifier {
  static int _seq = 0;
  final List<AppNotification> initialItems;
  FakeNotificationsNotifier([this.initialItems = const []]);

  @override
  NotificationState build() {
    return NotificationState(
      notifications: initialItems,
      unreadCount: initialItems.where((n) => !n.isRead).length,
      isLoading: false,
    );
  }

  @override
  Future<void> loadNotifications() async {}

  @override
  Future<void> clearAll() async {
    state = const NotificationState(notifications: [], unreadCount: 0);
  }

  @override
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
    final notif = AppNotification(
      id: 'notif_fake_${_seq++}_${DateTime.now().microsecondsSinceEpoch}',
      userId: userId ?? 'test_widget_student',
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
    state = state.copyWith(
      notifications: [notif, ...state.notifications],
      unreadCount: state.unreadCount + 1,
    );
    return notif;
  }

  @override
  Future<void> markAsRead(String id) async {
    final updated = state.notifications.map((n) {
      if (n.id == id) return n.copyWith(isRead: true);
      return n;
    }).toList();
    state = state.copyWith(
      notifications: updated,
      unreadCount: updated.where((n) => !n.isRead).length,
    );
  }

  @override
  Future<void> markAllAsRead() async {
    final updated = state.notifications.map((n) => n.copyWith(isRead: true)).toList();
    state = state.copyWith(
      notifications: updated,
      unreadCount: 0,
    );
  }

  @override
  Future<void> deleteNotification(String id) async {
    final updated = state.notifications.where((n) => n.id != id).toList();
    state = state.copyWith(
      notifications: updated,
      unreadCount: updated.where((n) => !n.isRead).length,
    );
  }

  @override
  Future<int> deleteBatchNotifications(List<String> ids) async {
    final idSet = ids.toSet();
    final updated = state.notifications.where((n) => !idSet.contains(n.id)).toList();
    final count = state.notifications.length - updated.length;
    state = state.copyWith(
      notifications: updated,
      unreadCount: updated.where((n) => !n.isRead).length,
    );
    return count;
  }
}

void main() {
  final testUser = User(
    id: 'test_widget_student',
    email: 'student@test.com',
    role: 'student',
    fullName: 'Widget Test Student',
    username: 'widgetstudent',
    availableRoles: const ['student'],
  );

  Widget createNotificationScreen(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        navigatorKey: rootNavigatorKey,
        home: const NotificationCenterScreen(),
      ),
    );
  }

  group('NotificationCenterScreen Widget Tests', () {
    testWidgets('renders search bar, category chips, and notifications list', (tester) async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => FakeAuthNotifier(testUser)),
          notificationsProvider.overrideWith(() => FakeNotificationsNotifier()),
        ],
      );

      final notifier = container.read(notificationsProvider.notifier);
      await notifier.addNotification(
        userId: testUser.id,
        type: 'new_assignment',
        title: 'Mobile App Architecture Task',
        message: 'Implement Riverpod state management in module 4',
        showBanner: false,
      );
      await notifier.addNotification(
        userId: testUser.id,
        type: 'chat',
        title: 'Instructor Alex',
        message: 'Office hours moved to 4 PM today',
        showBanner: false,
      );

      await tester.pumpWidget(createNotificationScreen(container));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify AppBar
      expect(find.text('Notifications'), findsOneWidget);

      // Verify Search TextField
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search notifications...'), findsOneWidget);

      // Verify Category Chips
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Unread'), findsOneWidget);
      expect(find.text('Assignments'), findsOneWidget);
      expect(find.text('Chat'), findsOneWidget);

      // Verify rendered notification items
      expect(find.text('Mobile App Architecture Task'), findsOneWidget);
      expect(find.text('Instructor Alex'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });

    testWidgets('real-time search input filters notifications by keyword across title/message', (tester) async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => FakeAuthNotifier(testUser)),
          notificationsProvider.overrideWith(() => FakeNotificationsNotifier()),
        ],
      );

      final notifier = container.read(notificationsProvider.notifier);
      await notifier.addNotification(
        userId: testUser.id,
        type: 'new_assignment',
        title: 'Flutter UI Design',
        message: 'Build a notification center screen',
        showBanner: false,
      );
      await notifier.addNotification(
        userId: testUser.id,
        type: 'quiz',
        title: 'Database Systems Pop Quiz',
        message: 'SQL indexing and queries test',
        showBanner: false,
      );

      await tester.pumpWidget(createNotificationScreen(container));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Flutter UI Design'), findsOneWidget);
      expect(find.text('Database Systems Pop Quiz'), findsOneWidget);

      // Enter search query 'Database'
      await tester.enterText(find.byType(TextField), 'Database');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Only database pop quiz should remain visible
      expect(find.text('Database Systems Pop Quiz'), findsOneWidget);
      expect(find.text('Flutter UI Design'), findsNothing);

      // Clear search query
      final clearButton = find.byIcon(Icons.clear_rounded);
      expect(clearButton, findsOneWidget);
      await tester.tap(clearButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Both should be restored
      expect(find.text('Flutter UI Design'), findsOneWidget);
      expect(find.text('Database Systems Pop Quiz'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });

    testWidgets('multi-select mode allows selecting items and executing batch deletion', (tester) async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => FakeAuthNotifier(testUser)),
          notificationsProvider.overrideWith(() => FakeNotificationsNotifier()),
        ],
      );

      final notifier = container.read(notificationsProvider.notifier);
      await notifier.addNotification(
        userId: testUser.id,
        type: 'announcement',
        title: 'Campus Closure Notice',
        message: 'Weather disturbance alert',
        showBanner: false,
      );
      await notifier.addNotification(
        userId: testUser.id,
        type: 'chat',
        title: 'Team Member Bob',
        message: 'Ready for standup',
        showBanner: false,
      );

      await tester.pumpWidget(createNotificationScreen(container));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Campus Closure Notice'), findsOneWidget);
      expect(find.text('Team Member Bob'), findsOneWidget);

      // 1. Enter multi-selection mode
      final checklistIcon = find.byIcon(Icons.checklist_rounded);
      expect(checklistIcon, findsOneWidget);
      await tester.tap(checklistIcon);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify multi-select action bar
      expect(find.text('Select All'), findsOneWidget);
      expect(find.text('Delete Selected (0)'), findsOneWidget);
      expect(find.byType(Checkbox), findsNWidgets(2));

      // 2. Select the first notification (Campus Closure Notice)
      await tester.tap(find.text('Campus Closure Notice'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('1 Selected'), findsOneWidget);
      expect(find.text('Delete Selected (1)'), findsOneWidget);

      // 3. Tap 'Delete Selected (1)'
      await tester.tap(find.text('Delete Selected (1)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 4. Verify confirmation dialog appears
      expect(find.text('Delete 1 Notification?'), findsOneWidget);
      expect(find.text('Are you sure you want to permanently delete the selected notification?'), findsOneWidget);

      // 5. Confirm deletion by tapping 'Delete'
      final deleteConfirmButton = find.widgetWithText(ElevatedButton, 'Delete');
      expect(deleteConfirmButton, findsOneWidget);
      await tester.tap(deleteConfirmButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 6. Verify item was deleted and only 'Team Member Bob' remains
      expect(find.text('Campus Closure Notice'), findsNothing);
      expect(find.text('Team Member Bob'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });
  });
}
