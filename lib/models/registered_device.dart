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
    required this.organizationId,
    required this.organizationName,
    required this.joinStatus,
    required this.deviceType,
    required this.displayName,
    required this.firstName,
    required this.lastName,
    required this.deviceNumber,
    required this.staffAccessRequested,
    required this.notificationPermissionStatus,
    required this.songDeliveryListenerActive,
    required this.songDeliveryListenerStatus,
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
  final String organizationId;
  final String organizationName;
  final String joinStatus;
  final String deviceType;
  final String displayName;
  final String firstName;
  final String lastName;
  final String deviceNumber;
  final bool staffAccessRequested;
  final String notificationPermissionStatus;
  final bool songDeliveryListenerActive;
  final String songDeliveryListenerStatus;

  bool get isApproved => joinStatus == 'approved';

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
      organizationId: data['organizationId'] ?? '',
      organizationName: data['organizationName'] ?? '',
      joinStatus: data['joinStatus'] ?? 'approved',
      deviceType: data['deviceType'] ?? 'unknown',
      displayName:
          data['displayName'] ?? data['deviceName'] ?? 'Unknown device',
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      deviceNumber: data['deviceNumber'] ?? '',
      staffAccessRequested: data['staffAccessRequested'] as bool? ?? false,
      notificationPermissionStatus:
          data['notificationPermissionStatus'] as String? ?? 'unknown',
      songDeliveryListenerActive:
          data['songDeliveryListenerActive'] as bool? ?? false,
      songDeliveryListenerStatus:
          data['songDeliveryListenerStatus'] as String? ?? '',
    );
  }

  factory RegisteredDevice.fromMap(Map<String, dynamic> data) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
      }
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    return RegisteredDevice(
      id: data['id'] as String? ?? '',
      deviceName: data['deviceName'] as String? ?? 'Unknown device',
      manufacturer: data['manufacturer'] as String? ?? '',
      model: data['model'] as String? ?? '',
      platformVersion: data['platformVersion'] as String? ?? '',
      appVersion: data['appVersion'] as String? ?? '',
      fcmToken: data['fcmToken'] as String? ?? '',
      firstSeenAt: parseDate(data['firstSeenAt']),
      lastSeenAt: parseDate(data['lastSeenAt']),
      notificationsEnabled: data['notificationsEnabled'] as bool? ?? false,
      isDisabled: data['isDisabled'] as bool? ?? false,
      minimumSupportedVersion: data['minimumSupportedVersion'] as String? ?? '',
      isOutdated: data['isOutdated'] as bool? ?? false,
      organizationId: data['organizationId'] as String? ?? '',
      organizationName: data['organizationName'] as String? ?? '',
      joinStatus: data['joinStatus'] as String? ?? 'approved',
      deviceType: data['deviceType'] as String? ?? 'unknown',
      displayName:
          data['displayName'] as String? ??
          data['deviceName'] as String? ??
          'Unknown device',
      firstName: data['firstName'] as String? ?? '',
      lastName: data['lastName'] as String? ?? '',
      deviceNumber: data['deviceNumber'] as String? ?? '',
      staffAccessRequested: data['staffAccessRequested'] as bool? ?? false,
      notificationPermissionStatus:
          data['notificationPermissionStatus'] as String? ?? 'unknown',
      songDeliveryListenerActive:
          data['songDeliveryListenerActive'] as bool? ?? false,
      songDeliveryListenerStatus:
          data['songDeliveryListenerStatus'] as String? ?? '',
    );
  }
}
