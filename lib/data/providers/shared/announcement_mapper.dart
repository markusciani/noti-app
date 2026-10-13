import '../../../models/announcement.dart';

Announcement announcementFromMap(
  String id,
  Map<String, dynamic> data,
) {
  DateTime parseTimestamp(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value)?.toUtc() ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  final createdAt = parseTimestamp(data['createdAt']);
  final correctionWindowEndsAtRaw = data['correctionWindowEndsAt'];

  return Announcement(
    id: id,
    organizationId: data['organizationId'] as String? ?? '',
    title: data['title'] as String? ?? '',
    message: data['message'] as String? ?? '',
    author: data['author'] as String? ?? '',
    authorPhotoUrl: data['authorPhotoUrl'] as String? ?? '',
    createdAt: createdAt,
    pinned: data['pinned'] as bool? ?? false,
    correctionWindowEndsAt: correctionWindowEndsAtRaw == null
        ? null
        : parseTimestamp(correctionWindowEndsAtRaw),
  );
}
