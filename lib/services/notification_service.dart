import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/song_file.dart';
import 'music_directory_service.dart';

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
    'noti_silent',
    'Noti Announcements',
    description: 'Alerts for church announcements and music from Noti.',
    // Android channel sound/importance cannot be changed after installation.
    // Keep this on a dedicated silent channel so upgrades do not inherit the
    // old noisy channel settings.
    importance: Importance.low,
    playSound: false,
    enableVibration: false,
  );

  Future<void> initialize() async {
    await _initializeLocalNotifications();
    await _messaging.requestPermission(alert: true, badge: true, sound: false);

    FirebaseMessaging.onMessage.listen(_showMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpen);
    await _messaging.getInitialMessage().then((message) {
      if (message != null) _handleMessageOpen(message);
    });
  }

  /// Called from the top-level FCM background handler after Firebase is ready.
  Future<void> showBackgroundMessage(RemoteMessage message) async {
    await _initializeLocalNotifications();
    await _showMessage(message);
  }

  Future<void> _initializeLocalNotifications() async {
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
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      final data = Map<String, dynamic>.from(jsonDecode(payload) as Map);
      if (data['type'] != 'song_delivery') return;
      final openSecondSong = response.actionId == 'open_second_song';
      final song = _songFromData(data, secondSong: openSecondSong);
      if (song == null) return;
      unawaited(MusicDirectoryService().openSong(song));
    } catch (_) {
      // A malformed payload should never interrupt the home feed.
    }
  }

  void _handleMessageOpen(RemoteMessage message) {
    // The member app intentionally remains on the announcements feed when a
    // standard FCM notification is tapped. Song delivery actions use the
    // local notification buttons above to launch the selected file instead.
  }

  Future<void> _showMessage(RemoteMessage message) async {
    final data = message.data;
    if (data['type'] == 'song_delivery_withdrawn') {
      final deliveryId = data['deliveryId'];
      if (deliveryId != null && deliveryId.isNotEmpty) {
        await _localNotifications.cancel(_notificationId(deliveryId));
      }
      return;
    }

    if (data['type'] == 'custom_notification_withdrawn') {
      final notificationId = data['notificationId'];
      if (notificationId != null && notificationId.isNotEmpty) {
        await _localNotifications.cancel(_notificationId(notificationId));
      }
      return;
    }

    if (data['type'] == 'announcement_withdrawn') {
      final announcementId = data['announcementId'];
      if (announcementId != null && announcementId.isNotEmpty) {
        await _localNotifications.cancel(_notificationId(announcementId));
      }
      return;
    }

    if (data['type'] == 'song_delivery') {
      await _showSongDelivery(data);
      return;
    }

    if (data['type'] == 'custom_notification') {
      await _showCustomNotification(data);
      return;
    }

    if (data['type'] == 'announcement') {
      await _showAnnouncement(data);
      return;
    }

    final notification = message.notification;
    if (notification == null) return;
    await _localNotifications.show(
      notification.hashCode,
      notification.title ?? 'Noti',
      notification.body ?? '',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'noti_silent',
          'Noti Announcements',
          channelDescription:
              'Alerts for church announcements and music from Noti.',
          importance: Importance.low,
          priority: Priority.low,
          playSound: false,
          enableVibration: false,
        ),
      ),
    );
  }

  Future<void> _showSongDelivery(Map<String, dynamic> data) async {
    final deliveryId = data['deliveryId'];
    final primarySong = _songFromData(data);
    if (deliveryId == null || deliveryId.isEmpty || primarySong == null) return;
    final secondarySong = _songFromData(data, secondSong: true);
    final body = secondarySong == null
        ? '${data['title']?.toString().trim() ?? 'Songs are ready'}\n${primarySong.fileName}'
        : '${data['title']?.toString().trim() ?? 'Songs are ready'}\n${primarySong.fileName}\nThen: ${secondarySong.fileName}';
    final largeIcon = await _notificationIcon(
      data['senderPhotoUrl'],
      deliveryId,
    );
    await _localNotifications.show(
      _notificationId(deliveryId),
      data['senderName']?.toString().trim().isNotEmpty == true
          ? data['senderName']!.toString().trim()
          : 'Your Director',
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'noti_silent',
          'Noti Announcements',
          channelDescription:
              'Alerts for church announcements and music from Noti.',
          importance: Importance.low,
          priority: Priority.low,
          playSound: false,
          enableVibration: false,
          largeIcon: largeIcon,
          actions: [
            const AndroidNotificationAction(
              'open_primary_song',
              'Open song',
              showsUserInterface: true,
            ),
            if (secondarySong != null)
              const AndroidNotificationAction(
                'open_second_song',
                'Open second song',
                showsUserInterface: true,
              ),
          ],
        ),
      ),
      payload: jsonEncode(data),
    );
  }

  Future<void> _showCustomNotification(Map<String, dynamic> data) async {
    final notificationId = data['notificationId'];
    final title = data['title']?.trim() ?? '';
    final message = data['message']?.trim() ?? '';
    if (notificationId == null ||
        notificationId.isEmpty ||
        title.isEmpty ||
        message.isEmpty) {
      return;
    }
    final largeIcon = await _notificationIcon(
      data['senderPhotoUrl'],
      notificationId,
    );
    await _localNotifications.show(
      _notificationId(notificationId),
      title,
      message,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'noti_silent',
          'Noti Announcements',
          channelDescription:
              'Alerts for church announcements and music from Noti.',
          importance: Importance.low,
          priority: Priority.low,
          playSound: false,
          enableVibration: false,
          largeIcon: largeIcon,
        ),
      ),
    );
  }

  Future<void> _showAnnouncement(Map<String, dynamic> data) async {
    final announcementId = data['announcementId'];
    final title = data['title']?.toString().trim() ?? '';
    final message = data['message']?.toString().trim() ?? '';
    if (announcementId == null ||
        announcementId.isEmpty ||
        title.isEmpty ||
        message.isEmpty) {
      return;
    }
    final largeIcon = await _notificationIcon(
      data['authorPhotoUrl'],
      announcementId,
    );
    await _localNotifications.show(
      _notificationId(announcementId),
      title,
      message,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'noti_silent',
          'Noti Announcements',
          channelDescription:
              'Alerts for church announcements and music from Noti.',
          importance: Importance.low,
          priority: Priority.low,
          playSound: false,
          enableVibration: false,
          largeIcon: largeIcon,
        ),
      ),
    );
  }

  Future<FilePathAndroidBitmap?> _notificationIcon(
    dynamic rawUrl,
    dynamic rawId,
  ) async {
    final url = rawUrl?.toString().trim() ?? '';
    final id = rawId?.toString().trim() ?? '';
    if (url.isEmpty || id.isEmpty) return null;
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/noti_notification_$id.jpg');
      await file.writeAsBytes(response.bodyBytes, flush: true);
      return FilePathAndroidBitmap(file.path);
    } on Object catch (_) {
      return null;
    }
  }

  SongFile? _songFromData(
    Map<String, dynamic> data, {
    bool secondSong = false,
  }) {
    final prefix = secondSong ? 'secondary' : 'primary';
    final path = data['${prefix}Path']?.toString().trim() ?? '';
    final fileName = data['${prefix}Name']?.toString().trim() ?? '';
    if (path.isEmpty || fileName.isEmpty) return null;
    return SongFile(
      relativePath: path,
      fileName: fileName,
      mimeType:
          data['${prefix}Mime']?.toString().trim() ??
          'application/octet-stream',
    );
  }

  int _notificationId(String deliveryId) {
    final hex = sha256
        .convert(utf8.encode(deliveryId))
        .toString()
        .substring(0, 8);
    return int.parse(hex, radix: 16) & 0x7fffffff;
  }

  Future<String?> getToken() => _messaging.getToken();

  static String topicForOrganization(String organizationId) {
    final normalized = organizationId.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9_.~-]+'),
      '_',
    );
    return 'org_${normalized.isEmpty ? 'unassigned' : normalized}';
  }

  Future<void> syncOrganizationTopic(String? organizationId) async {
    // Remove the legacy broadcast topic so a device cannot receive another
    // organization's messages after it changes or leaves an organization.
    await _messaging.unsubscribeFromTopic('announcements');
    if (organizationId == null || organizationId.trim().isEmpty) return;
    await _messaging.subscribeToTopic(topicForOrganization(organizationId));
  }

  Future<void> unsubscribeFromOrganizationTopic(String? organizationId) async {
    await _messaging.unsubscribeFromTopic('announcements');
    if (organizationId == null || organizationId.trim().isEmpty) return;
    await _messaging.unsubscribeFromTopic(topicForOrganization(organizationId));
  }
}
