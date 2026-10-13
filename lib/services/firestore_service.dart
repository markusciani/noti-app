import '../core/backend/backend_factory.dart';
import '../core/backend/interfaces/notification_repository.dart';
import '../models/announcement.dart';

class FirestoreService {
  FirestoreService({NotificationRepository? repository})
    : _repository = repository ?? BackendFactory.create().notificationRepository;

  final NotificationRepository _repository;

  Stream<List<Announcement>> getAnnouncements({String? organizationId}) {
    return _repository.watchAnnouncements(organizationId: organizationId);
  }

  Future<void> addAnnouncement({
    required String title,
    required String message,
    required String author,
    bool pinned = false,
    String? organizationId,
  }) {
    return _repository.createAnnouncement(
      title: title,
      message: message,
      author: author,
      pinned: pinned,
      organizationId: organizationId,
    );
  }

  Future<void> updateAnnouncement({
    required String id,
    required String title,
    required String message,
    required String author,
    required bool pinned,
    String? organizationId,
  }) {
    return _repository.updateAnnouncement(
      id: id,
      title: title,
      message: message,
      author: author,
      pinned: pinned,
      organizationId: organizationId,
    );
  }

  Future<void> deleteAnnouncement(String id, {String? organizationId}) {
    return _repository.deleteAnnouncement(id, organizationId: organizationId);
  }
}
