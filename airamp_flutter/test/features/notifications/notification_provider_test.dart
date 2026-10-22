import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airamp_flutter/src/features/notifications/application/notification_provider.dart';
import 'package:airamp_flutter/src/features/auth/application/auth_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FakeAuthNotifier extends AuthNotifier {
  final User? _user;
  FakeAuthNotifier(this._user);

  @override
  User? build() => _user;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('NotificationNotifier adds, tracks unread, and marks as read', () async {
    final testUser = User(
      id: 'test_student_01',
      email: 'student@example.com',
      role: 'student',
      fullName: 'Test Student',
      username: 'teststudent',
      availableRoles: const ['student'],
    );

    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(() => FakeAuthNotifier(testUser)),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(notificationsProvider.notifier);
    await notifier.loadNotifications();

    // Clear any previous test data
    await notifier.clearAll();
    expect(container.read(notificationsProvider).notifications.length, 0);
    expect(container.read(unreadNotificationCountProvider), 0);

    // 1. Add direct message notification
    final dmNotif = await notifier.addNotification(
      userId: 'test_student_01',
      type: 'chat',
      title: 'Teacher Maria',
      message: 'Please review Unit 2 before tomorrow.',
      targetRoute: '/chat/dm_teacher_student',
      showBanner: false,
    );
    expect(dmNotif, isNotNull);
    expect(container.read(unreadNotificationCountProvider), 1);

    // 2. Add group chat notification
    final gcNotif = await notifier.addNotification(
      userId: 'test_student_01',
      type: 'group_chat',
      title: 'John in BSIT 3-A',
      message: 'Meeting at 3 PM today in Lab 1.',
      targetRoute: '/chat/gc_bsit3a',
      showBanner: false,
    );
    expect(gcNotif, isNotNull);
    expect(container.read(unreadNotificationCountProvider), 2);

    // 3. Add quiz action notification
    final quizNotif = await notifier.addNotification(
      userId: 'test_student_01',
      type: 'quiz',
      title: 'Assessment Passed! 🎉',
      message: 'You scored 9/10 (90%) on Flutter Fundamentals.',
      targetRoute: '/student/history',
      showBanner: false,
    );
    expect(quizNotif, isNotNull);
    expect(container.read(unreadNotificationCountProvider), 3);

    // 4. Mark one as read
    await notifier.markAsRead(dmNotif!.id);
    expect(container.read(unreadNotificationCountProvider), 2);

    // 5. Mark all as read
    await notifier.markAllAsRead();
    expect(container.read(unreadNotificationCountProvider), 0);
    expect(container.read(notificationsProvider).notifications.length, 3);

    // 6. Delete notification
    await notifier.deleteNotification(quizNotif!.id);
    expect(container.read(notificationsProvider).notifications.length, 2);

    // 7. Clear all
    await notifier.clearAll();
    expect(container.read(notificationsProvider).notifications.length, 0);
  });
}
