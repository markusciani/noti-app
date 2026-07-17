import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/device_registration.dart';
import '../models/organization.dart';

class DeviceService {
  DeviceService({
    FirebaseFirestore? firestore,
    FirebaseMessaging? messaging,
    FirebaseAuth? auth,
    DeviceInfoPlugin? deviceInfo,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _messaging = messaging ?? FirebaseMessaging.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _deviceInfo = deviceInfo ?? DeviceInfoPlugin();

  final FirebaseFirestore _firestore;
  final FirebaseMessaging _messaging;
  final FirebaseAuth _auth;
  final DeviceInfoPlugin _deviceInfo;

  static const _deviceIdKey = 'noti_device_id';
  static const _staffAccessKey = 'noti_staff_access';
  static const _collection = 'devices';

  Future<String> _ensureDeviceOwner() async {
    var user = _auth.currentUser;
    user ??= (await _auth.signInAnonymously()).user;
    if (user == null) {
      throw StateError('Could not create a secure device identity.');
    }
    return user.uid;
  }

  Future<String> _getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final id = const Uuid().v4();
    await prefs.setString(_deviceIdKey, id);
    return id;
  }

  Future<String?> currentDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_deviceIdKey);
  }

  Future<bool> staffAccessEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_staffAccessKey)) {
      return prefs.getBool(_staffAccessKey) ?? false;
    }
    final deviceId = prefs.getString(_deviceIdKey);
    if (deviceId != null && deviceId.isNotEmpty) {
      final snapshot = await _firestore
          .collection(_collection)
          .doc(deviceId)
          .get();
      if (snapshot.data()?['staffAccessRequested'] == true) return true;
    }
    return false;
  }

  Future<void> enableStaffAccess() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_staffAccessKey, true);

    final deviceId = prefs.getString(_deviceIdKey);
    if (deviceId == null || deviceId.isEmpty) return;

    try {
      await _firestore.collection(_collection).doc(deviceId).set({
        'staffAccessRequested': true,
        'deviceType': 'director_tablet',
        'organizationId': Organization.defaultId,
        'organizationName': Organization.defaultName,
      }, SetOptions(merge: true));
    } catch (_) {
      // The local device credential still controls the local director entry.
    }
  }

  Future<void> disableStaffAccess() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_staffAccessKey, false);

    final deviceId = prefs.getString(_deviceIdKey);
    if (deviceId == null || deviceId.isEmpty) return;

    try {
      await _firestore.collection(_collection).doc(deviceId).set({
        'staffAccessRequested': false,
      }, SetOptions(merge: true));
    } catch (_) {
      // Local access is authoritative for this device. A stale or deleted
      // Firestore record must not prevent the director tools from hiding.
    }
  }

  Future<bool> needsOnboarding() async {
    final deviceId = await currentDeviceId();
    if (deviceId == null || deviceId.isEmpty) return true;

    final snapshot = await _firestore
        .collection(_collection)
        .doc(deviceId)
        .get();
    if (!snapshot.exists) return true;
    final data = snapshot.data() ?? const <String, dynamic>{};
    final organizationId = data['organizationId'] as String? ?? '';
    return organizationId.isEmpty;
  }

  Future<String?> approvedOrganizationId() async {
    final prefs = await SharedPreferences.getInstance();
    final localStaffAccess = prefs.getBool(_staffAccessKey) ?? false;
    final deviceId = await currentDeviceId();
    if (deviceId == null || deviceId.isEmpty) {
      return localStaffAccess ? Organization.defaultId : null;
    }
    final snapshot = await _firestore
        .collection(_collection)
        .doc(deviceId)
        .get();
    final data = snapshot.data();
    if (!snapshot.exists) {
      return localStaffAccess ? Organization.defaultId : null;
    }
    if (data?['isDisabled'] == true) return null;
    final organizationId = data?['organizationId'] as String?;
    return organizationId == null || organizationId.isEmpty
        ? Organization.defaultId
        : organizationId;
  }

  Future<Map<String, dynamic>> _collectPlatformData() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final permissionStatus = await _messaging.getNotificationSettings();
    final messagingEnabled =
        permissionStatus.authorizationStatus ==
            AuthorizationStatus.authorized ||
        permissionStatus.authorizationStatus == AuthorizationStatus.provisional;
    final token = await _messaging.getToken() ?? '';
    final minimumSupportedVersion = await _fetchMinimumSupportedVersion();

    if (kIsWeb) {
      return {
        'deviceName': 'Web',
        'manufacturer': 'Web',
        'model': 'Web',
        'platformVersion': 'Web',
        'appVersion': packageInfo.version,
        'buildNumber': packageInfo.buildNumber,
        'fcmToken': token,
        'notificationsEnabled': messagingEnabled,
        'minimumSupportedVersion': minimumSupportedVersion,
        'isOutdated': _isVersionOutdated(
          packageInfo.version,
          minimumSupportedVersion,
        ),
      };
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final androidInfo = await _deviceInfo.androidInfo;
        return {
          'deviceName': androidInfo.model,
          'manufacturer': androidInfo.manufacturer,
          'model': androidInfo.model,
          'platformVersion': androidInfo.version.release,
          'appVersion': packageInfo.version,
          'buildNumber': packageInfo.buildNumber,
          'fcmToken': token,
          'notificationsEnabled': messagingEnabled,
          'minimumSupportedVersion': minimumSupportedVersion,
          'isOutdated': _isVersionOutdated(
            packageInfo.version,
            minimumSupportedVersion,
          ),
        };
      case TargetPlatform.iOS:
        final iosInfo = await _deviceInfo.iosInfo;
        return {
          'deviceName': iosInfo.name,
          'manufacturer': 'Apple',
          'model': iosInfo.utsname.machine,
          'platformVersion': iosInfo.systemVersion,
          'appVersion': packageInfo.version,
          'buildNumber': packageInfo.buildNumber,
          'fcmToken': token,
          'notificationsEnabled': messagingEnabled,
          'minimumSupportedVersion': minimumSupportedVersion,
          'isOutdated': _isVersionOutdated(
            packageInfo.version,
            minimumSupportedVersion,
          ),
        };
      case TargetPlatform.macOS:
        final macInfo = await _deviceInfo.macOsInfo;
        return {
          'deviceName': macInfo.computerName,
          'manufacturer': 'Apple',
          'model': macInfo.model,
          'platformVersion': macInfo.osRelease,
          'appVersion': packageInfo.version,
          'buildNumber': packageInfo.buildNumber,
          'fcmToken': token,
          'notificationsEnabled': messagingEnabled,
          'minimumSupportedVersion': minimumSupportedVersion,
          'isOutdated': _isVersionOutdated(
            packageInfo.version,
            minimumSupportedVersion,
          ),
        };
      case TargetPlatform.linux:
      case TargetPlatform.windows:
      case TargetPlatform.fuchsia:
        return {
          'deviceName': defaultTargetPlatform.name,
          'manufacturer': defaultTargetPlatform.name,
          'model': defaultTargetPlatform.name,
          'platformVersion': defaultTargetPlatform.name,
          'appVersion': packageInfo.version,
          'buildNumber': packageInfo.buildNumber,
          'fcmToken': token,
          'notificationsEnabled': messagingEnabled,
          'minimumSupportedVersion': minimumSupportedVersion,
          'isOutdated': _isVersionOutdated(
            packageInfo.version,
            minimumSupportedVersion,
          ),
        };
    }
  }

  Future<String> _fetchMinimumSupportedVersion() async {
    try {
      final snapshot = await _firestore.collection('settings').doc('app').get();
      final data = snapshot.data();
      return data?['minimumSupportedVersion'] as String? ?? '';
    } catch (_) {
      return '';
    }
  }

  bool _isVersionOutdated(String currentVersion, String minimumVersion) {
    if (minimumVersion.isEmpty) return false;

    List<int> parse(String version) =>
        version.split('.').map((part) => int.tryParse(part) ?? 0).toList();

    final current = parse(currentVersion);
    final minimum = parse(minimumVersion);
    final maxLength = current.length > minimum.length
        ? current.length
        : minimum.length;

    for (var i = 0; i < maxLength; i++) {
      final currentPart = i < current.length ? current[i] : 0;
      final minimumPart = i < minimum.length ? minimum[i] : 0;
      if (currentPart != minimumPart) {
        return currentPart < minimumPart;
      }
    }

    return false;
  }

  Future<void> registerDevice({
    required DeviceRegistration registration,
  }) async {
    final settings = await _firestore.collection('settings').doc('app').get();
    final settingsData = settings.data() ?? {};
    final registrationEnabled =
        settingsData['deviceRegistrationEnabled'] as bool? ?? true;
    if (!registrationEnabled) {
      return;
    }

    final deviceId = await _getOrCreateDeviceId();
    final ownerUid = await _ensureDeviceOwner();
    final prefs = await SharedPreferences.getInstance();
    final staffAccessRequested = registration.deviceType == 'director_tablet';
    await prefs.setBool(_staffAccessKey, staffAccessRequested);
    final platformData = await _collectPlatformData();
    final owner = _auth.currentUser;
    final deviceNumber = '';
    final displayName = registration.displayName.trim();
    if (owner != null &&
        displayName.isNotEmpty &&
        owner.displayName != displayName) {
      await owner.updateDisplayName(displayName);
    }

    final ref = _firestore.collection(_collection).doc(deviceId);
    final existing = await ref.get();
    final existingData = existing.data() ?? const <String, dynamic>{};
    await ref.set({
      ...platformData,
      'id': deviceId,
      'ownerUid': ownerUid,
      'firstSeenAt':
          existingData['firstSeenAt'] ?? FieldValue.serverTimestamp(),
      'lastSeenAt': FieldValue.serverTimestamp(),
      'isDisabled': false,
      'organizationId': registration.organizationId,
      'organizationName': registration.organizationName,
      'joinStatus': 'approved',
      'deviceType': registration.deviceType,
      'displayName': displayName,
      'deviceName': displayName,
      'firstName': '',
      'lastName': '',
      'deviceNumber': deviceNumber,
      'staffAccessRequested': staffAccessRequested,
    }, SetOptions(merge: true));
  }

  Future<void> updatePresence() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString(_deviceIdKey);
    if (deviceId == null || deviceId.isEmpty) {
      return;
    }

    final platformData = await _collectPlatformData();
    await _ensureDeviceOwner();
    final ref = _firestore.collection(_collection).doc(deviceId);
    final existing = await ref.get();
    final existingData = existing.data() ?? const <String, dynamic>{};
    final deviceNumber = (existingData['deviceNumber'] as String? ?? '').trim();
    await ref.set({
      ...platformData,
      'id': deviceId,
      'lastSeenAt': FieldValue.serverTimestamp(),
      if (deviceNumber.isNotEmpty) 'displayName': 'Maranatha $deviceNumber',
      'joinStatus': 'approved',
    }, SetOptions(merge: true));
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchCurrentDevice() async* {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString(_deviceIdKey);
    if (deviceId == null || deviceId.isEmpty) {
      return;
    }

    yield* _firestore.collection(_collection).doc(deviceId).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchDevices() {
    return _firestore
        .collection(_collection)
        .orderBy('lastSeenAt', descending: true)
        .snapshots();
  }

  Future<void> deleteDevice(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }

  Future<void> setDeviceDisabled(String id, bool disabled) async {
    await _firestore.collection(_collection).doc(id).set({
      'isDisabled': disabled,
    }, SetOptions(merge: true));
  }
}
