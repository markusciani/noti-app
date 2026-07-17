import 'package:cloud_firestore/cloud_firestore.dart';

import 'song_file.dart';

class SongDelivery {
  const SongDelivery({
    required this.id,
    required this.title,
    required this.senderName,
    required this.primarySong,
    required this.secondarySong,
    required this.status,
    required this.createdAt,
    required this.correctionWindowEndsAt,
  });

  final String id;
  final String title;
  final String senderName;
  final SongFile primarySong;
  final SongFile? secondarySong;
  final String status;
  final DateTime? createdAt;
  final DateTime? correctionWindowEndsAt;

  bool get isActive => status == 'active';

  bool get canCorrect =>
      isActive &&
      correctionWindowEndsAt != null &&
      DateTime.now().isBefore(correctionWindowEndsAt!);

  factory SongDelivery.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    final secondary = data['secondarySong'];
    return SongDelivery(
      id: snapshot.id,
      title: data['title'] as String? ?? 'Songs are ready',
      senderName: data['senderName'] as String? ?? 'Your Director',
      primarySong: SongFile.fromMap(
        Map<String, dynamic>.from(data['primarySong'] as Map? ?? const {}),
      ),
      secondarySong: secondary is Map
          ? SongFile.fromMap(Map<String, dynamic>.from(secondary))
          : null,
      status: data['status'] as String? ?? 'active',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      correctionWindowEndsAt: (data['correctionWindowEndsAt'] as Timestamp?)
          ?.toDate(),
    );
  }
}
