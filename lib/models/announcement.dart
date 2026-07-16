import 'package:cloud_firestore/cloud_firestore.dart';

class Announcement {
  final String id;
  final String title;
  final String message;
  final String author;
  final DateTime createdAt;
  final bool pinned;

  Announcement({
    required this.id,
    required this.title,
    required this.message,
    required this.author,
    required this.createdAt,
    required this.pinned,
  });

  factory Announcement.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    final rawCreatedAt = data['createdAt'];
    final createdAt = rawCreatedAt is Timestamp
        ? rawCreatedAt.toDate()
        : DateTime.fromMillisecondsSinceEpoch(0);

    return Announcement(
      id: doc.id,
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      author: data['author'] ?? '',
      createdAt: createdAt,
      pinned: data['pinned'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'message': message,
      'author': author,
      'createdAt': Timestamp.fromDate(createdAt),
      'pinned': pinned,
    };
  }
}
