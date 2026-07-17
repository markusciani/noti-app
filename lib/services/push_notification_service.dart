import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/custom_notification_delivery.dart';
import 'auth_service.dart';

class PushNotificationService {
  PushNotificationService({
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
  }) : _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'us-central1'),
       _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;

  Future<String> sendTestBroadcast({
    required String title,
    required String message,
    String? organizationId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('A device identity is required before sending a notification.');
    }
    if (user.isAnonymous) {
      final role = await AuthService().currentStaffRole();
      if (role != StaffRole.director) {
        throw StateError('Open director access before sending a notification.');
      }
    }

    // Ensure the callable request carries a current Firebase Auth token.
    await user.getIdToken(true);

    final result = await _functions
        .httpsCallable('sendTestPush')
        .call<Map<String, dynamic>>({
          'title': title,
          'message': message,
          if (organizationId != null && organizationId.isNotEmpty)
            'organizationId': organizationId,
        });
    return result.data['messageId'] as String? ?? '';
  }

  Future<void> createBroadcast({
    required String title,
    required String message,
    String? organizationId,
  }) => _call('createCustomBroadcast', {
    'title': title,
    'message': message,
    if (organizationId != null && organizationId.isNotEmpty)
      'organizationId': organizationId,
  });

  Future<void> updateBroadcast({
    required String notificationId,
    required String title,
    required String message,
    String? organizationId,
  }) => _call('updateCustomBroadcast', {
    'notificationId': notificationId,
    'title': title,
    'message': message,
    if (organizationId != null && organizationId.isNotEmpty)
      'organizationId': organizationId,
  });

  Future<void> withdrawBroadcast(
    String notificationId, {
    String? organizationId,
  }) => _call('withdrawCustomBroadcast', {
    'notificationId': notificationId,
    if (organizationId != null && organizationId.isNotEmpty)
      'organizationId': organizationId,
  });

  Stream<List<CustomNotificationDelivery>> watchMyBroadcasts() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _firestore
        .collection('custom_notifications')
        .where('requestedByUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(12)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(CustomNotificationDelivery.fromFirestore)
              .toList(growable: false),
        );
  }

  Future<void> _call(String function, Map<String, dynamic> data) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('A device identity is required before sending a notification.');
    }
    if (user.isAnonymous) {
      final role = await AuthService().currentStaffRole();
      if (role != StaffRole.director) {
        throw StateError('Open director access before sending a notification.');
      }
    }
    await user.getIdToken(true);
    await _functions.httpsCallable(function).call<Map<String, dynamic>>(data);
  }
}
