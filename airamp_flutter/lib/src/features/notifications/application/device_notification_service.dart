import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../domain/notification_model.dart';

/// Service providing OS-level system notifications (heads-up popups on top of the device)
/// across Android, iOS, and Web for critical academic events like new assignments and quizzes.
class DeviceNotificationService {
  static final DeviceNotificationService _instance = DeviceNotificationService._internal();
  factory DeviceNotificationService() => _instance;
  static DeviceNotificationService get instance => _instance;
  DeviceNotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  static const String channelId = 'aira_academic_alerts';
  static const String channelName = 'AIRA Academic Alerts';
  static const String channelDescription =
      'High-priority notifications for new quizzes, assignments, and grades.';

  /// Initializes local notifications plugin, sets up heads-up channels, and requests permissions.
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinInit = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(
        android: androidInit,
        iOS: darwinInit,
        macOS: darwinInit,
      );

      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('[DeviceNotificationService] Notification tapped: ${response.payload}');
        },
      );

      // Create high-importance Android Notification Channel for Heads-up popups
      if (!kIsWeb) {
        final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        if (androidPlugin != null) {
          const channel = AndroidNotificationChannel(
            channelId,
            channelName,
            description: channelDescription,
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            showBadge: true,
          );
          await androidPlugin.createNotificationChannel(channel);
          await androidPlugin.requestNotificationsPermission();
        }
      }

      _isInitialized = true;
      debugPrint('[DeviceNotificationService] Initialized successfully');
    } catch (e) {
      debugPrint('[DeviceNotificationService] Init error: $e');
    }
  }

  /// Triggers a system-level notification popup outside the app.
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
    String? type,
  }) async {
    try {
      if (!_isInitialized) {
        await init();
      }

      final notifId = Random().nextInt(1000000);
      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'AIRA Academic Alert',
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
        playSound: true,
        styleInformation: BigTextStyleInformation(body),
      );
      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      final details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      await _localNotifications.show(
        id: notifId,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('[DeviceNotificationService] showNotification error: $e');
    }
  }

  /// Displays an OS-level notification for an [AppNotification], suppressing chat join spam.
  Future<void> showFromAppNotification(AppNotification notif) async {
    // Suppress chat join logs or group chat membership spam from OS banners
    if (notif.type == 'chat' || notif.type == 'group_chat') {
      return;
    }
    await showNotification(
      title: notif.title,
      body: notif.message,
      payload: notif.targetRoute ?? notif.relatedId,
      type: notif.type,
    );
  }
}
