import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/organization.dart';
import '../theme/noti_theme.dart';

class OrganizationService {
  OrganizationService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance,
      _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('organizations');

  Stream<List<Organization>> watchOrganizations({
    bool includeDisabled = false,
  }) {
    return _collection.snapshots().map((snapshot) {
      final organizations = snapshot.docs
          .map(Organization.fromFirestore)
          .where((organization) => includeDisabled || organization.enabled)
          .toList();
      organizations.sort((a, b) => a.name.compareTo(b.name));
      return organizations.isEmpty ? [Organization.fallback] : organizations;
    });
  }

  Future<List<Organization>> getAvailableOrganizations() async {
    try {
      final snapshot = await _collection.get();
      final organizations = snapshot.docs
          .map(Organization.fromFirestore)
          .where((organization) => organization.enabled)
          .toList();
      organizations.sort((a, b) => a.name.compareTo(b.name));
      return organizations.isEmpty ? [Organization.fallback] : organizations;
    } catch (_) {
      return [Organization.fallback];
    }
  }

  Future<void> saveOrganization({
    required String id,
    required String name,
    required bool enabled,
    required DeviceNamingPolicy namingPolicy,
    required String namingPrompt,
    NotiThemePreset themePreset = NotiThemePreset.main,
    NotiAppearance appearance = NotiAppearance.light,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Sign in as an administrator first.');
    await _collection.doc(id).set({
      'id': id,
      'name': name.trim(),
      'enabled': enabled,
      'deviceNamingPolicy': namingPolicy.storageValue,
      'deviceNamingPrompt': namingPrompt.trim().isEmpty
          ? namingPolicy.prompt
          : namingPrompt.trim(),
      'themePreset': themePreset.storageValue,
      'appearanceMode': appearance.storageValue,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedByUid': uid,
    }, SetOptions(merge: true));
  }

  Future<void> ensureDefaultOrganization() => saveOrganization(
    id: Organization.defaultId,
    name: Organization.defaultName,
    enabled: true,
    namingPolicy: DeviceNamingPolicy.deviceName,
    namingPrompt: Organization.fallback.namingPrompt,
  );

  Future<void> deleteOrganization(String id) async {
    if (id == Organization.defaultId) {
      throw StateError('The default organization cannot be deleted.');
    }
    await _collection.doc(id).delete();
  }

  Future<String?> rotateOrganizationPin({
    required String organizationId,
    String? pin,
    String? adminEmail,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw StateError('Sign in as an administrator first.');
    }
    await user.getIdToken(true);
    final result = await _functions
        .httpsCallable('rotateOrganizationPin')
        .call<Map<String, dynamic>>({
          'organizationId': organizationId,
          if (pin != null && pin.trim().isNotEmpty) 'pin': pin.trim(),
          if (adminEmail != null && adminEmail.trim().isNotEmpty)
            'adminEmail': adminEmail.trim(),
        });
    final returnedPin = result.data['pin'] as String?;
    if (returnedPin != null && returnedPin.length != 6) {
      throw StateError('The organization PIN was invalid.');
    }
    return returnedPin;
  }

  Future<void> approveDevice(String deviceId) async {
    await _firestore.collection('devices').doc(deviceId).set({
      'joinStatus': 'approved',
      'approvedAt': FieldValue.serverTimestamp(),
      'approvedByUid': _auth.currentUser?.uid,
      'isDisabled': false,
    }, SetOptions(merge: true));
  }

  Future<void> updateDeviceProfile({
    required String deviceId,
    required String deviceType,
    required String displayName,
    String deviceNumber = '',
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw StateError('Sign in as an administrator first.');
    }
    final normalizedNumber = deviceNumber.trim();
    if (normalizedNumber.isEmpty) {
      throw StateError('Enter a tablet number.');
    }
    await _functions.httpsCallable('renameDevice').call({
      'deviceId': deviceId,
      'deviceType': deviceType,
      'displayName': 'Maranatha $normalizedNumber',
      'deviceNumber': normalizedNumber,
    });
  }
}
