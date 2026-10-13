import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/backend/backend_config.dart';
import '../../../core/backend/interfaces/notification_repository.dart';
import '../../../models/announcement.dart';
import '../shared/http_notification_repository.dart';

class ConvexNotificationRepository implements NotificationRepository {
  ConvexNotificationRepository({FirebaseAuth? auth})
    : _delegate = HttpNotificationRepository(
        baseUrl: _resolveBaseUrl(),
        tokenProvider: () => (auth ?? FirebaseAuth.instance).currentUser
            ?.getIdToken(),
        staticHeaders: const {},
        mode: HttpNotificationMode.convexHttp,
      );

  final HttpNotificationRepository _delegate;

  static String _resolveBaseUrl() {
    final explicit = BackendConfig.apiBaseUrl.trim();
    if (explicit.isNotEmpty) return explicit;
    final convex = BackendConfig.convexUrl.trim();
    if (convex.isEmpty) return '';
    return '$convex/noti';
  }

  @override
  Future<void> createAnnouncement({
    required String title,
    required String message,
    required String author,
    required bool pinned,
    String? organizationId,
  }) {
    return _delegate.createAnnouncement(
      title: title,
      message: message,
      author: author,
      pinned: pinned,
      organizationId: organizationId,
    );
  }

  @override
  Future<void> deleteAnnouncement(String id, {String? organizationId}) {
    return _delegate.deleteAnnouncement(id, organizationId: organizationId);
  }

  @override
  Future<void> updateAnnouncement({
    required String id,
    required String title,
    required String message,
    required String author,
    required bool pinned,
    String? organizationId,
  }) {
    return _delegate.updateAnnouncement(
      id: id,
      title: title,
      message: message,
      author: author,
      pinned: pinned,
      organizationId: organizationId,
    );
  }

  @override
  Stream<List<Announcement>> watchAnnouncements({String? organizationId}) =>
      _delegate.watchAnnouncements(organizationId: organizationId);
}
