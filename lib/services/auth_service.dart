import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:local_auth/local_auth.dart';

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final LocalAuthentication _localAuth = LocalAuthentication();

  static const _pinCollection = 'admin_pins';
  static const _usersCollection = 'users';

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<User> ensureAnonymousUser() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) return currentUser;

    final credential = await _auth.signInAnonymously();
    final user = credential.user;
    if (user == null) {
      throw StateError('Could not create a secure device identity.');
    }
    return user;
  }

  Future<bool> isCurrentUserAdmin() async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) return false;

    final snapshot = await _firestore
        .collection(_usersCollection)
        .doc(user.uid)
        .get();
    final data = snapshot.data();
    return data?['role'] == 'admin' && data?['enabled'] != false;
  }

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> reauthenticateWithPassword(String password) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw StateError('No signed-in admin user.');
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);
  }

  Future<bool> canCheckBiometrics() async {
    return _localAuth.canCheckBiometrics;
  }

  Future<bool> authenticateWithBiometrics({
    String reason = 'Confirm your identity to continue.',
  }) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> setPin(String pin) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in admin user.');
    }

    await _firestore.collection(_pinCollection).doc(user.uid).set({
      'pinHash': _hashPin(pin),
      'updatedAt': FieldValue.serverTimestamp(),
      'email': user.email,
    }, SetOptions(merge: true));
  }

  Future<bool> hasPin() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final snapshot = await _firestore
        .collection(_pinCollection)
        .doc(user.uid)
        .get();
    return snapshot.exists &&
        (snapshot.data()?['pinHash'] as String? ?? '').isNotEmpty;
  }

  Future<bool> verifyPin(String pin) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final snapshot = await _firestore
        .collection(_pinCollection)
        .doc(user.uid)
        .get();
    final stored = snapshot.data()?['pinHash'] as String?;
    if (stored == null || stored.isEmpty) return false;
    return stored == _hashPin(pin);
  }

  Future<void> clearPin() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in admin user.');
    }

    await _firestore.collection(_pinCollection).doc(user.uid).delete();
  }

  String _hashPin(String pin) {
    return sha256.convert(utf8.encode(pin)).toString();
  }
}
