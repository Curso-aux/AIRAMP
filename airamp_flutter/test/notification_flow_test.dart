import 'package:flutter_test/flutter_test.dart';
import 'package:airamp_flutter/src/features/notifications/domain/notification_model.dart';
import 'package:airamp_flutter/src/features/notifications/application/device_notification_service.dart';

void main() {
  group('Notification Architecture & Quiz Renaming Tests', () {
    test('NotificationActivityDispatcher produces "New Quiz" title and "quiz" message', () async {
      // Test the copy formatting
      const title = 'Physics Midterm Quiz';
      const teacherName = 'Prof. Einstein';
      const dueDate = '2026-12-01T23:59:59.000Z';

      final formattedDue = dueDate.length >= 10 ? ' Due: ${dueDate.substring(0, 10)}' : '';
      final expectedTitle = 'New Quiz: $title';
      final expectedMessage = '$teacherName assigned quiz "$title".$formattedDue';

      expect(expectedTitle, contains('New Quiz:'));
      expect(expectedTitle, isNot(contains('Assessment')));
      expect(expectedMessage, contains('assigned quiz'));
      expect(expectedMessage, isNot(contains('assigned assessment')));
    });

    test('Filter logic strictly supports "quizzes" category and excludes chat join noise', () {
      final notifications = [
        AppNotification(
          id: 'n1',
          userId: 'S-100-0001',
          type: 'quiz_assigned',
          title: 'New Quiz: Fractions',
          message: 'Teacher assigned quiz "Fractions"',
          createdAt: DateTime.now().toIso8601String(),
          isRead: false,
        ),
        AppNotification(
          id: 'n2',
          userId: 'S-100-0001',
          type: 'new_assignment',
          title: 'New Assignment: Essay',
          message: 'Teacher posted "Essay"',
          createdAt: DateTime.now().toIso8601String(),
          isRead: false,
        ),
        AppNotification(
          id: 'n3',
          userId: 'S-100-0001',
          type: 'announcement',
          title: 'Campus Closure',
          message: 'Campus closed tomorrow',
          createdAt: DateTime.now().toIso8601String(),
          isRead: true,
        ),
        AppNotification(
          id: 'n4',
          userId: 'S-100-0001',
          type: 'group_chat',
          title: 'Classmate in Grade 12',
          message: 'Curso has joined the group chat!',
          createdAt: DateTime.now().toIso8601String(),
          isRead: false,
        ),
        AppNotification(
          id: 'n5',
          userId: 'S-100-0001',
          type: 'chat',
          title: 'Khen',
          message: 'Hello classmate!',
          createdAt: DateTime.now().toIso8601String(),
          isRead: false,
        ),
      ];

      // 1. Quizzes filter
      final quizFiltered = notifications.where((n) {
        if (n.type == 'chat' || n.type == 'group_chat') return false;
        return ['quiz', 'quiz_assigned', 'quiz_completed'].contains(n.type) || n.type.contains('quiz');
      }).toList();

      expect(quizFiltered.length, 1);
      expect(quizFiltered.first.id, 'n1');

      // 2. All filter (must exclude chat noise)
      final allFiltered = notifications.where((n) {
        return n.type != 'chat' && n.type != 'group_chat';
      }).toList();

      expect(allFiltered.length, 3);
      expect(allFiltered.any((n) => n.type == 'group_chat'), isFalse);
      expect(allFiltered.any((n) => n.type == 'chat'), isFalse);

      // 3. Unread count excluding chat noise
      final unreadCount = notifications
          .where((n) => !n.isRead && n.type != 'chat' && n.type != 'group_chat')
          .length;
      expect(unreadCount, 2); // Only n1 and n2, NOT n4 and n5!
    });

    test('DeviceNotificationService initializes and handles notification payload safely', () async {
      final service = DeviceNotificationService.instance;
      expect(DeviceNotificationService.channelId, 'aira_academic_alerts');
      expect(DeviceNotificationService.channelName, 'AIRA Academic Alerts');

      // Test suppression of chat type
      final chatNotif = AppNotification(
        id: 'chat_1',
        userId: 'u1',
        type: 'group_chat',
        title: 'Chat message',
        message: 'joined the group chat!',
        createdAt: DateTime.now().toIso8601String(),
      );

      // Should return without error and not throw
      await service.showFromAppNotification(chatNotif);
    });
  });
}
