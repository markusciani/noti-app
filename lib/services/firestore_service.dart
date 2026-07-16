import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/announcement.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Announcement>> getAnnouncements() {
    return _firestore
        .collection('announcements')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => Announcement.fromFirestore(doc))
                  .toList()
                ..sort((a, b) {
                  if (a.pinned != b.pinned) {
                    return a.pinned ? -1 : 1;
                  }
                  return b.createdAt.compareTo(a.createdAt);
                }),
        );
  }

  Future<void> addAnnouncement({
    required String title,
    required String message,
    required String author,
    bool pinned = false,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      throw StateError('An authorized admin account is required.');
    }

    await _firestore.collection('announcements').add({
      'title': title,
      'message': message,
      'author': author,
      'createdAt': FieldValue.serverTimestamp(),
      'pinned': pinned,
      'createdByUid': user.uid,
    });
  }

  Future<void> updateAnnouncement({
    required String id,
    required String title,
    required String message,
    required String author,
    required bool pinned,
  }) async {
    await _firestore.collection('announcements').doc(id).update({
      'title': title,
      'message': message,
      'author': author,
      'pinned': pinned,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteAnnouncement(String id) async {
    await _firestore.collection('announcements').doc(id).delete();
  }
}
