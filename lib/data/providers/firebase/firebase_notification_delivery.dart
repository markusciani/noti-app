import '../../../core/backend/interfaces/notification_delivery.dart';
import '../../../services/notification_service.dart';

class FirebaseCloudMessagingDelivery implements NotificationDelivery {
  FirebaseCloudMessagingDelivery({NotificationService? service})
    : _service = service ?? NotificationService();

  final NotificationService _service;

  @override
  String get transport => 'fcm';

  @override
  Future<void> ensureReady() async {
    await _service.ensurePushReady();
  }
}
