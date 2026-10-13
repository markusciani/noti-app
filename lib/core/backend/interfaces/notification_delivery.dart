abstract class NotificationDelivery {
  String get transport;
  Future<void> ensureReady();
}
