import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FounderAuthUser {
  const FounderAuthUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.organizationId,
    required this.enabled,
    required this.disabled,
    required this.emailVerified,
  });

  final String uid;
  final String email;
  final String displayName;
  final String role;
  final String organizationId;
  final bool enabled;
  final bool disabled;
  final bool emailVerified;

  bool get isFounder => email.trim().toLowerCase() == 'markus@ciani01.org';

  factory FounderAuthUser.fromMap(Map<String, dynamic> data) {
    return FounderAuthUser(
      uid: data['uid'] as String? ?? '',
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      role: data['role'] as String? ?? '',
      organizationId: data['organizationId'] as String? ?? '',
      enabled: data['enabled'] as bool? ?? true,
      disabled: data['disabled'] as bool? ?? false,
      emailVerified: data['emailVerified'] as bool? ?? false,
    );
  }
}

class FounderService {
  FounderService({FirebaseFunctions? functions, FirebaseAuth? auth})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'us-central1'),
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  Future<List<FounderAuthUser>> listAuthUsers() async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw StateError('Sign in as the founder first.');
    }
    await user.getIdToken(true);
    final result = await _functions
        .httpsCallable('listAuthUsers')
        .call<Map<String, dynamic>>();
    final rawUsers = result.data['users'] as List<dynamic>? ?? const [];
    return rawUsers
        .map(
          (item) =>
              FounderAuthUser.fromMap(Map<String, dynamic>.from(item as Map)),
        )
        .toList(growable: false);
  }

  Future<void> setStaffProfile({
    required String uid,
    required String role,
    required String organizationId,
    required bool enabled,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw StateError('Sign in as the founder first.');
    }
    await user.getIdToken(true);
    await _functions.httpsCallable('setStaffProfile').call({
      'uid': uid,
      'role': role,
      'organizationId': organizationId,
      'enabled': enabled,
    });
  }
}
