import 'package:cloud_firestore/cloud_firestore.dart';

class CustomNotificationDelivery {
  const CustomNotificationDelivery({
    required this.id,
    required this.title,
    required this.message,
    required this.status,
    required this.correctionWindowEndsAt,
  });

  final String id;
  final String title;
  final String message;
  final String status;
  final DateTime? correctionWindowEndsAt;

  bool get isActive => status == 'active';

  bool get canCorrect =>
      isActive &&
      correctionWindowEndsAt != null &&
      DateTime.now().isBefore(correctionWindowEndsAt!);

  factory CustomNotificationDelivery.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return CustomNotificationDelivery(
      id: snapshot.id,
      title: data['title'] as String? ?? 'Noti',
      message: data['message'] as String? ?? '',
      status: data['status'] as String? ?? 'active',
      correctionWindowEndsAt: (data['correctionWindowEndsAt'] as Timestamp?)
          ?.toDate(),
    );
  }
}
