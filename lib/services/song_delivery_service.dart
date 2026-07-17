import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/song_delivery.dart';
import '../models/song_file.dart';

class SongDeliveryService {
  SongDeliveryService({
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'us-central1'),
       _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<void> createDelivery({
    required String title,
    required SongFile primarySong,
    SongFile? secondarySong,
    String? organizationId,
  }) async {
    await _call('createSongDelivery', {
      'title': title,
      'primarySong': primarySong.toMap(),
      if (secondarySong != null) 'secondarySong': secondarySong.toMap(),
      if (organizationId != null && organizationId.isNotEmpty)
        'organizationId': organizationId,
    });
  }

  Future<void> updateDelivery({
    required String deliveryId,
    required String title,
    required SongFile primarySong,
    SongFile? secondarySong,
    String? organizationId,
  }) async {
    await _call('updateSongDelivery', {
      'deliveryId': deliveryId,
      'title': title,
      'primarySong': primarySong.toMap(),
      'secondarySong': secondarySong?.toMap(),
      if (organizationId != null && organizationId.isNotEmpty)
        'organizationId': organizationId,
    });
  }

  Future<void> withdrawDelivery(String deliveryId, {String? organizationId}) {
    return _call('withdrawSongDelivery', {
      'deliveryId': deliveryId,
      if (organizationId != null && organizationId.isNotEmpty)
        'organizationId': organizationId,
    });
  }

  Stream<List<SongDelivery>> watchMyDeliveries() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _firestore
        .collection('song_deliveries')
        .where('requestedByUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(12)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(SongDelivery.fromFirestore)
              .toList(growable: false),
        );
  }

  Future<void> _call(String name, Map<String, dynamic> data) async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw StateError(
        'Sign in as a director or founder before sending songs.',
      );
    }
    await user.getIdToken(true);
    await _functions.httpsCallable(name).call<Map<String, dynamic>>(data);
  }
}
