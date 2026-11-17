import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:airamp_flutter/src/core/database/database_helper.dart';
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
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    DatabaseHelper.resetForTesting();
    final db = await DatabaseHelper().database;
    await db.delete('notifications');
  });

  final testUser = User(
    id: 'test_student_01',
    email: 'student@example.com',
    role: 'student',
    fullName: 'Test Student',
    username: 'teststudent',
    availableRoles: const ['student'],
  );

  test('NotificationNotifier adds, tracks unread, and marks as read', () async {
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

  test('NotificationNotifier batch deletes multiple notifications atomically', () async {
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(() => FakeAuthNotifier(testUser)),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(notificationsProvider.notifier);
    await notifier.clearAll();

    // Insert 4 test notifications
    final n1 = await notifier.addNotification(
      userId: 'test_student_01',
      type: 'new_assignment',
      title: 'Assignment 1',
      message: 'Complete Lab Exercise 1',
      showBanner: false,
    );
    final n2 = await notifier.addNotification(
      userId: 'test_student_01',
      type: 'new_assignment',
      title: 'Assignment 2',
      message: 'Complete Lab Exercise 2',
      showBanner: false,
    );
    final n3 = await notifier.addNotification(
      userId: 'test_student_01',
      type: 'announcement',
      title: 'School Notice',
      message: 'Midterm schedule posted',
      showBanner: false,
    );
    final n4 = await notifier.addNotification(
      userId: 'test_student_01',
      type: 'chat',
      title: 'Professor Garcia',
      message: 'Good progress!',
      showBanner: false,
    );

    expect(container.read(notificationsProvider).notifications.length, 4);
    expect(container.read(unreadNotificationCountProvider), 4);

    // Batch delete n1 and n3
    final deletedCount = await notifier.deleteBatchNotifications([n1!.id, n3!.id]);
    expect(deletedCount, 2);

    final remaining = container.read(notificationsProvider).notifications;
    expect(remaining.length, 2);
    expect(remaining.any((n) => n.id == n1.id), isFalse);
    expect(remaining.any((n) => n.id == n3.id), isFalse);
    expect(remaining.any((n) => n.id == n2!.id), isTrue);
    expect(remaining.any((n) => n.id == n4!.id), isTrue);
    expect(container.read(unreadNotificationCountProvider), 2);

    // Reload from database to verify persistence of batch deletion
    await notifier.loadNotifications();
    expect(container.read(notificationsProvider).notifications.length, 2);

    // Clean up
    await notifier.clearAll();
  });

  test('Search and category filtering filters notifications correctly', () async {
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(() => FakeAuthNotifier(testUser)),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(notificationsProvider.notifier);
    await notifier.loadNotifications();
    await notifier.clearAll();

    await notifier.addNotification(
      userId: 'test_student_01',
      type: 'new_assignment',
      title: 'Discrete Mathematics Homework',
      message: 'Solve set theory problems in chapter 3',
      actorName: 'Dr. Euler',
      showBanner: false,
    );
    await notifier.addNotification(
      userId: 'test_student_01',
      type: 'quiz',
      title: 'Calculus Pop Quiz',
      message: 'Integration rules assessment',
      actorName: 'Prof. Newton',
      showBanner: false,
    );
    await notifier.addNotification(
      userId: 'test_student_01',
      type: 'chat',
      title: 'Study Group BSIT',
      message: 'Who has the lecture notes?',
      actorName: 'Alice',
      showBanner: false,
    );

    // 1. Filter by keyword in title
    final mathResults = notifier.filterByQuery('Mathematics');
    expect(mathResults.length, 1);
    expect(mathResults.first.title, contains('Discrete Mathematics'));

    // 2. Filter by keyword in message
    final noteResults = notifier.filterByQuery('lecture notes');
    expect(noteResults.length, 1);
    expect(noteResults.first.type, 'chat');

    // 3. Filter by keyword in actor name
    final newtonResults = notifier.filterByQuery('Newton');
    expect(newtonResults.length, 1);
    expect(newtonResults.first.title, contains('Calculus'));

    // 4. Filter by category
    final assignmentCategory = notifier.filterByQuery('', category: 'assignments');
    expect(assignmentCategory.length, 1);
    expect(assignmentCategory.first.type, 'new_assignment');

    final chatCategory = notifier.filterByQuery('', category: 'chat');
    expect(chatCategory.length, 1);
    expect(chatCategory.first.type, 'chat');

    // 5. Test reactive filteredNotificationsProvider
    container.read(notificationSearchQueryProvider.notifier).setQuery('Calculus');
    expect(container.read(filteredNotificationsProvider).length, 1);
    expect(container.read(filteredNotificationsProvider).first.title, contains('Calculus'));

    container.read(notificationSearchQueryProvider.notifier).clear();
    expect(container.read(filteredNotificationsProvider).length, 3);

    container.read(notificationCategoryFilterProvider.notifier).setCategory('chat');
    expect(container.read(filteredNotificationsProvider).length, 1);
    expect(container.read(filteredNotificationsProvider).first.type, 'chat');

    // Clean up
    await notifier.clearAll();
  });
}
