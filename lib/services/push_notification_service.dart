import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

class PushNotificationService {
  PushNotificationService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  Future<String> sendTestBroadcast({
    required String title,
    required String message,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      throw StateError(
        'Sign in with an administrator account before sending a notification.',
      );
    }

    // Ensure the callable request carries a current Firebase Auth token.
    await user.getIdToken(true);

    final result = await _functions
        .httpsCallable('sendTestPush')
        .call<Map<String, dynamic>>({'title': title, 'message': message});
    return result.data['messageId'] as String? ?? '';
  }
}
