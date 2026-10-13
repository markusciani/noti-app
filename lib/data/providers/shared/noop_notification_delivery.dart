import '../../../core/backend/interfaces/notification_delivery.dart';

class NoopNotificationDelivery implements NotificationDelivery {
  NoopNotificationDelivery({required this.transport});

  @override
  final String transport;

  @override
  Future<void> ensureReady() async {}
}
