import 'package:cloud_firestore/cloud_firestore.dart';

class AppSettingsService {
  AppSettingsService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _firestore.collection('settings').doc('app');

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchSettings() {
    return _doc.snapshots();
  }

  Future<void> saveSettings({
    required String minimumSupportedVersion,
    required bool deviceRegistrationEnabled,
    String? themePreset,
    String? appearanceMode,
  }) {
    final data = <String, dynamic>{
      'minimumSupportedVersion': minimumSupportedVersion,
      'deviceRegistrationEnabled': deviceRegistrationEnabled,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (themePreset != null) data['themePreset'] = themePreset;
    if (appearanceMode != null) data['appearanceMode'] = appearanceMode;

    return _doc.set(data, SetOptions(merge: true));
  }
}
