import '../../../models/announcement.dart';

abstract class NotificationRepository {
  Stream<List<Announcement>> watchAnnouncements({String? organizationId});

  Future<void> createAnnouncement({
    required String title,
    required String message,
    required String author,
    required bool pinned,
    String? organizationId,
  });

  Future<void> updateAnnouncement({
    required String id,
    required String title,
    required String message,
    required String author,
    required bool pinned,
    String? organizationId,
  });

  Future<void> deleteAnnouncement(String id, {String? organizationId});
}
