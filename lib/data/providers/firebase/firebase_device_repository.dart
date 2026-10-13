import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/backend/interfaces/device_repository.dart';

class FirebaseDeviceRepository implements DeviceRepository {
  FirebaseDeviceRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<void> upsertDevice(Map<String, dynamic> payload) async {
    final id = payload['id']?.toString().trim() ?? '';
    if (id.isEmpty) {
      throw StateError('Device payload requires an id.');
    }
    await _firestore.collection('devices').doc(id).set(payload, SetOptions(merge: true));
  }
}
