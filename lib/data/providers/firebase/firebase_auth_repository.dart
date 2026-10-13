import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/backend/interfaces/auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  Future<String?> currentIdToken({bool forceRefresh = false}) {
    return _auth.currentUser?.getIdToken(forceRefresh);
  }

  @override
  Future<String?> currentUserId() async => _auth.currentUser?.uid;

  @override
  Future<bool> isSignedIn() async => _auth.currentUser != null;
}
