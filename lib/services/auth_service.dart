import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

import '../models/organization.dart';

enum StaffRole {
  founder,
  admin,
  director,
  none;

  bool get canManageChurch => this != none;
  bool get canSendSongs => this == director;
  bool get isFounder => this == founder;
}

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  static const _usersCollection = 'users';
  static const _deviceAuthChannel = MethodChannel(
    'org.ciani01.noti/device_auth',
  );
  static const directorFallbackCode = '9089';

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
    final role = await currentStaffRole();
    return role == StaffRole.director;
  }

  Future<StaffRole> currentStaffRole() async {
    final user = _auth.currentUser;
    if (user == null) return StaffRole.none;

    final snapshot = await _firestore
        .collection(_usersCollection)
        .doc(user.uid)
        .get();
    final data = snapshot.data();
    if (!snapshot.exists || data?['enabled'] == false) {
      return StaffRole.none;
    }

    return switch (data?['role']) {
      // Migrate old staff profiles to the single director role.
      'admin' || 'founder' || 'director' => StaffRole.director,
      _ => StaffRole.none,
    };
  }

  Future<String> currentOrganizationId() async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) return Organization.defaultId;
    final snapshot = await _firestore
        .collection(_usersCollection)
        .doc(user.uid)
        .get();
    final organizationId = snapshot.data()?['organizationId'] as String?;
    return organizationId == null || organizationId.isEmpty
        ? Organization.defaultId
        : organizationId;
  }

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<bool> authenticateDeviceCredential() async {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      try {
        return await LocalAuthentication().authenticate(
          localizedReason: 'Verify your identity to open Noti Director tools.',
          options: const AuthenticationOptions(
            biometricOnly: false,
            stickyAuth: true,
            useErrorDialogs: true,
          ),
        );
      } catch (_) {
        return false;
      }
    }

    try {
      return await _deviceAuthChannel.invokeMethod<bool>(
            'authenticateDevice',
          ) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> claimDirectorAccess({required String fallbackCode}) async {
    final user = _auth.currentUser ?? (await _auth.signInAnonymously()).user;
    if (user == null) {
      throw StateError('Noti could not create this device identity.');
    }
    await FirebaseFunctions.instance.httpsCallable('claimDirectorAccess').call({
      'fallbackCode': fallbackCode,
    });
  }

  Future<void> updateDirectorProfile({
    required String firstName,
    String? photoUrl,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Sign in as a director first.');
    }
    await user.getIdToken(true);
    await FirebaseFunctions.instance
        .httpsCallable('updateDirectorProfile')
        .call({
          'firstName': firstName.trim(),
          if (photoUrl != null && photoUrl.trim().isNotEmpty)
            'photoUrl': photoUrl.trim(),
        });
    // Keep the current device session responsive. Firebase-backed profile
    // data remains authoritative for Cloud Functions and notifications.
    try {
      await user.updateDisplayName(firstName.trim());
      if (photoUrl != null && photoUrl.trim().isNotEmpty) {
        await user.updatePhotoURL(photoUrl.trim());
      }
    } catch (_) {
      // Some anonymous/provider sessions do not allow local profile updates.
    }
    await user.reload();
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
