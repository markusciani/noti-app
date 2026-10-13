import 'package:flutter_test/flutter_test.dart';
import 'package:noti/core/backend/backend_factory.dart';
import 'package:noti/core/backend/backend_provider.dart';
import 'package:noti/data/providers/firebase/firebase_notification_repository.dart';

void main() {
  test('firebase remains default provider implementation', () {
    final services = BackendFactory.create(
      overrideProvider: BackendProvider.firebase,
    );

    expect(services.provider, BackendProvider.firebase);
    expect(services.notificationRepository, isA<FirebaseNotificationRepository>());
    expect(services.notificationDelivery.transport, 'fcm');
  });

  test('non-firebase providers return a notification adapter', () {
    final providers = [
      BackendProvider.supabase,
      BackendProvider.convex,
      BackendProvider.postgresApi,
      BackendProvider.mysqlApi,
      BackendProvider.mongoApi,
      BackendProvider.customApi,
    ];

    for (final provider in providers) {
      final services = BackendFactory.create(overrideProvider: provider);
      expect(services.provider, provider);
      expect(services.notificationRepository, isNotNull);
    }
  });
}
