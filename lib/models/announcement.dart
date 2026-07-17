import 'package:cloud_firestore/cloud_firestore.dart';

class Announcement {
  final String id;
  final String organizationId;
  final String title;
  final String message;
  final String author;
  final String authorPhotoUrl;
  final DateTime createdAt;
  final bool pinned;
  final DateTime? correctionWindowEndsAt;

  Announcement({
    required this.id,
    this.organizationId = '',
    required this.title,
    required this.message,
    required this.author,
    this.authorPhotoUrl = '',
    required this.createdAt,
    required this.pinned,
    this.correctionWindowEndsAt,
  });

  bool get canCorrect =>
      correctionWindowEndsAt != null &&
      DateTime.now().isBefore(correctionWindowEndsAt!);

  factory Announcement.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    final rawCreatedAt = data['createdAt'];
    final createdAt = rawCreatedAt is Timestamp
        ? rawCreatedAt.toDate()
        : DateTime.fromMillisecondsSinceEpoch(0);

    return Announcement(
      id: doc.id,
      organizationId: data['organizationId'] as String? ?? '',
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      author: data['author'] ?? '',
      authorPhotoUrl: data['authorPhotoUrl'] as String? ?? '',
      createdAt: createdAt,
      pinned: data['pinned'] ?? false,
      correctionWindowEndsAt: (data['correctionWindowEndsAt'] as Timestamp?)
          ?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'organizationId': organizationId,
      'title': title,
      'message': message,
      'author': author,
      'authorPhotoUrl': authorPhotoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'pinned': pinned,
    };
  }
}
