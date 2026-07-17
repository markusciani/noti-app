import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/announcement.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'us-central1',
  );

  Stream<List<Announcement>> getAnnouncements({String? organizationId}) {
    return _firestore
        .collection('announcements')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          final announcements = snapshot.docs
              .map((doc) => Announcement.fromFirestore(doc))
              .where(
                (announcement) =>
                    organizationId == null ||
                    organizationId.isEmpty ||
                    announcement.organizationId == organizationId ||
                    (organizationId == 'maranatha-romanian-church' &&
                        announcement.organizationId.isEmpty),
              )
              .toList();
          announcements.sort((a, b) {
            if (a.pinned != b.pinned) {
              return a.pinned ? -1 : 1;
            }
            return b.createdAt.compareTo(a.createdAt);
          });
          return announcements;
        });
  }

  Future<void> addAnnouncement({
    required String title,
    required String message,
    required String author,
    bool pinned = false,
    String? organizationId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('A device identity is required.');
    }

    await FirebaseAuth.instance.currentUser!.getIdToken(true);
    await _functions.httpsCallable('createAnnouncement').call({
      'title': title,
      'message': message,
      'author': author,
      'pinned': pinned,
      if (organizationId != null && organizationId.isNotEmpty)
        'organizationId': organizationId,
    });
  }

  Future<void> updateAnnouncement({
    required String id,
    required String title,
    required String message,
    required String author,
    required bool pinned,
    String? organizationId,
  }) async {
    await FirebaseAuth.instance.currentUser!.getIdToken(true);
    await _functions.httpsCallable('updateAnnouncement').call({
      'announcementId': id,
      'title': title,
      'message': message,
      'author': author,
      'pinned': pinned,
      if (organizationId != null && organizationId.isNotEmpty)
        'organizationId': organizationId,
    });
  }

  Future<void> deleteAnnouncement(String id, {String? organizationId}) async {
    await FirebaseAuth.instance.currentUser!.getIdToken(true);
    await _functions.httpsCallable('deleteAnnouncement').call({
      'announcementId': id,
      if (organizationId != null && organizationId.isNotEmpty)
        'organizationId': organizationId,
    });
  }
}
