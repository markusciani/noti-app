import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/backend/backend_config.dart';
import '../../../core/backend/interfaces/notification_repository.dart';
import '../../../models/announcement.dart';
import '../shared/http_notification_repository.dart';

class SupabaseNotificationRepository implements NotificationRepository {
  SupabaseNotificationRepository({FirebaseAuth? auth})
    : _delegate = HttpNotificationRepository(
        baseUrl: _resolveBaseUrl(),
        tokenProvider: () => (auth ?? FirebaseAuth.instance).currentUser
            ?.getIdToken(),
        staticHeaders: {
          if (BackendConfig.supabaseAnonKey.trim().isNotEmpty)
            'apikey': BackendConfig.supabaseAnonKey.trim(),
        },
        mode: HttpNotificationMode.supabaseEdge,
      );

  final HttpNotificationRepository _delegate;

  static String _resolveBaseUrl() {
    final explicit = BackendConfig.apiBaseUrl.trim();
    if (explicit.isNotEmpty) return explicit;
    final supabaseUrl = BackendConfig.supabaseUrl.trim();
    if (supabaseUrl.isEmpty) return '';
    return '$supabaseUrl/functions/v1/noti';
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
