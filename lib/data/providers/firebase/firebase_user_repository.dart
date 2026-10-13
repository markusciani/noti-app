import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/backend/interfaces/user_repository.dart';

class FirebaseUserRepository implements UserRepository {
  FirebaseUserRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  @override
  Future<Map<String, dynamic>?> currentUserProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final snapshot = await _firestore.collection('users').doc(uid).get();
    return snapshot.data();
  }
}
