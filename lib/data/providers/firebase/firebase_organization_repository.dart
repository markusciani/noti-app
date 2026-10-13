import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/backend/interfaces/organization_repository.dart';

class FirebaseOrganizationRepository implements OrganizationRepository {
  FirebaseOrganizationRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<List<Map<String, dynamic>>> listOrganizations() async {
    final snapshot = await _firestore.collection('organizations').get();
    return snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList(growable: false);
  }
}
