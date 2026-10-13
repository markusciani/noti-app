import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:noti/core/backend/interfaces/notification_repository.dart';
import 'package:noti/models/announcement.dart';
import 'package:noti/services/firestore_service.dart';

class FakeNotificationRepository implements NotificationRepository {
  final announcementsController = StreamController<List<Announcement>>.broadcast();

  Map<String, dynamic>? lastCreate;
  Map<String, dynamic>? lastUpdate;
  Map<String, dynamic>? lastDelete;

  @override
  Future<void> createAnnouncement({
    required String title,
    required String message,
    required String author,
    required bool pinned,
    String? organizationId,
  }) async {
    lastCreate = {
      'title': title,
      'message': message,
      'author': author,
      'pinned': pinned,
      'organizationId': organizationId,
    };
  }

  @override
  Future<void> deleteAnnouncement(String id, {String? organizationId}) async {
    lastDelete = {'id': id, 'organizationId': organizationId};
  }

  @override
  Future<void> updateAnnouncement({
    required String id,
    required String title,
    required String message,
    required String author,
    required bool pinned,
    String? organizationId,
  }) async {
    lastUpdate = {
      'id': id,
      'title': title,
      'message': message,
      'author': author,
      'pinned': pinned,
      'organizationId': organizationId,
    };
  }

  @override
  Stream<List<Announcement>> watchAnnouncements({String? organizationId}) {
    return announcementsController.stream;
  }
}

void main() {
  test('FirestoreService delegates write methods to configured repository', () async {
    final fake = FakeNotificationRepository();
    final service = FirestoreService(repository: fake);

    await service.addAnnouncement(
      title: 'T',
      message: 'M',
      author: 'A',
      pinned: true,
      organizationId: 'org-1',
    );
    await service.updateAnnouncement(
      id: 'id-1',
      title: 'T2',
      message: 'M2',
      author: 'A2',
      pinned: false,
      organizationId: 'org-2',
    );
    await service.deleteAnnouncement('id-3', organizationId: 'org-3');

    expect(fake.lastCreate?['title'], 'T');
    expect(fake.lastCreate?['pinned'], true);
    expect(fake.lastUpdate?['id'], 'id-1');
    expect(fake.lastDelete?['organizationId'], 'org-3');
  });

  test('FirestoreService exposes repository announcement stream', () async {
    final fake = FakeNotificationRepository();
    final service = FirestoreService(repository: fake);

    final expected = [
      Announcement(
        id: 'a1',
        title: 'title',
        message: 'message',
        author: 'author',
        createdAt: DateTime.utc(2026, 1, 1),
        pinned: false,
      ),
    ];

    final future = expectLater(service.getAnnouncements(), emits(expected));
    fake.announcementsController.add(expected);
    await future;
  });
}
