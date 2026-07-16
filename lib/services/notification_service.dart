import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _localNotifications =
           localNotifications ?? FlutterLocalNotificationsPlugin();

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'noti_announcements',
    'Noti Announcements',
    description: 'Alerts for church announcements from Noti.',
    importance: Importance.high,
  );

  Future<void> initialize() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(_channel);

    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    await _messaging.subscribeToTopic('announcements');

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpen);
    await _messaging.getInitialMessage().then((message) {
      if (message != null) _handleMessageOpen(message);
    });
  }

  void _handleNotificationResponse(NotificationResponse response) {
    // Noti has one member-facing screen. A local notification tap should resume
    // that screen rather than create a detail route or a second navigation stack.
  }

  void _handleMessageOpen(RemoteMessage message) {
    // The app always starts on the announcements feed. Keep push notification
    // taps there until announcement deep links are intentionally introduced.
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      notification.hashCode,
      notification.title ?? 'Noti',
      notification.body ?? '',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'noti_announcements',
          'Noti Announcements',
          channelDescription: 'Alerts for church announcements from Noti.',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  Future<String?> getToken() => _messaging.getToken();
}
