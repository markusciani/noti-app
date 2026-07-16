import 'package:cloud_firestore/cloud_firestore.dart';

class RegisteredDevice {
  RegisteredDevice({
    required this.id,
    required this.deviceName,
    required this.manufacturer,
    required this.model,
    required this.platformVersion,
    required this.appVersion,
    required this.fcmToken,
    required this.firstSeenAt,
    required this.lastSeenAt,
    required this.notificationsEnabled,
    required this.isDisabled,
    required this.minimumSupportedVersion,
    required this.isOutdated,
  });

  final String id;
  final String deviceName;
  final String manufacturer;
  final String model;
  final String platformVersion;
  final String appVersion;
  final String fcmToken;
  final DateTime firstSeenAt;
  final DateTime lastSeenAt;
  final bool notificationsEnabled;
  final bool isDisabled;
  final String minimumSupportedVersion;
  final bool isOutdated;

  factory RegisteredDevice.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    final firstSeen = data['firstSeenAt'];
    final lastSeen = data['lastSeenAt'];

    return RegisteredDevice(
      id: doc.id,
      deviceName: data['deviceName'] ?? 'Unknown device',
      manufacturer: data['manufacturer'] ?? '',
      model: data['model'] ?? '',
      platformVersion: data['platformVersion'] ?? '',
      appVersion: data['appVersion'] ?? '',
      fcmToken: data['fcmToken'] ?? '',
      firstSeenAt: firstSeen is Timestamp
          ? firstSeen.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
      lastSeenAt: lastSeen is Timestamp
          ? lastSeen.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
      notificationsEnabled: data['notificationsEnabled'] ?? false,
      isDisabled: data['isDisabled'] ?? false,
      minimumSupportedVersion: data['minimumSupportedVersion'] ?? '',
      isOutdated: data['isOutdated'] ?? false,
    );
  }
}
