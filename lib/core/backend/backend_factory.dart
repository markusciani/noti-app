import '../../data/providers/convex/convex_notification_repository.dart';
import '../../data/providers/custom_api/custom_api_notification_repository.dart';
import '../../data/providers/firebase/firebase_auth_repository.dart';
import '../../data/providers/firebase/firebase_device_repository.dart';
import '../../data/providers/firebase/firebase_notification_delivery.dart';
import '../../data/providers/firebase/firebase_notification_repository.dart';
import '../../data/providers/firebase/firebase_organization_repository.dart';
import '../../data/providers/firebase/firebase_user_repository.dart';
import '../../data/providers/shared/noop_notification_delivery.dart';
import '../../data/providers/shared/noop_repositories.dart';
import '../../data/providers/supabase/supabase_notification_repository.dart';
import 'backend_config.dart';
import 'backend_provider.dart';
import 'interfaces/auth_repository.dart';
import 'interfaces/device_repository.dart';
import 'interfaces/file_storage_repository.dart';
import 'interfaces/notification_delivery.dart';
import 'interfaces/notification_repository.dart';
import 'interfaces/organization_repository.dart';
import 'interfaces/realtime_updates.dart';
import 'interfaces/user_repository.dart';

class BackendServices {
  const BackendServices({
    required this.provider,
    required this.authRepository,
    required this.userRepository,
    required this.organizationRepository,
    required this.deviceRepository,
    required this.notificationRepository,
    required this.notificationDelivery,
    required this.realtimeUpdates,
    required this.fileStorageRepository,
  });

  final BackendProvider provider;
  final AuthRepository authRepository;
  final UserRepository userRepository;
  final OrganizationRepository organizationRepository;
  final DeviceRepository deviceRepository;
  final NotificationRepository notificationRepository;
  final NotificationDelivery notificationDelivery;
  final RealtimeUpdates realtimeUpdates;
  final FileStorageRepository fileStorageRepository;
}

class BackendFactory {
  const BackendFactory._();

  static BackendServices create({BackendProvider? overrideProvider}) {
    final provider = overrideProvider ?? BackendConfig.provider;

    return switch (provider) {
      BackendProvider.firebase => BackendServices(
        provider: provider,
        authRepository: FirebaseAuthRepository(),
        userRepository: FirebaseUserRepository(),
        organizationRepository: FirebaseOrganizationRepository(),
        deviceRepository: FirebaseDeviceRepository(),
        notificationRepository: FirebaseNotificationRepository(),
        notificationDelivery: FirebaseCloudMessagingDelivery(),
        realtimeUpdates: UnsupportedRealtimeUpdates('Firebase'),
        fileStorageRepository: UnsupportedFileStorageRepository('Firebase'),
      ),
      BackendProvider.supabase => _httpBackedServices(
        provider: provider,
        label: 'Supabase',
        notificationRepository: SupabaseNotificationRepository(),
      ),
      BackendProvider.convex => _httpBackedServices(
        provider: provider,
        label: 'Convex',
        notificationRepository: ConvexNotificationRepository(),
      ),
      BackendProvider.postgresApi => _httpBackedServices(
        provider: provider,
        label: 'PostgreSQL API',
        notificationRepository: CustomApiNotificationRepository(),
      ),
      BackendProvider.mysqlApi => _httpBackedServices(
        provider: provider,
        label: 'MySQL API',
        notificationRepository: CustomApiNotificationRepository(),
      ),
      BackendProvider.mongoApi => _httpBackedServices(
        provider: provider,
        label: 'MongoDB API',
        notificationRepository: CustomApiNotificationRepository(),
      ),
      BackendProvider.customApi => _httpBackedServices(
        provider: provider,
        label: 'Custom API',
        notificationRepository: CustomApiNotificationRepository(),
      ),
    };
  }

  static BackendServices _httpBackedServices({
    required BackendProvider provider,
    required String label,
    required NotificationRepository notificationRepository,
  }) {
    return BackendServices(
      provider: provider,
      authRepository: UnsupportedAuthRepository(label),
      userRepository: UnsupportedUserRepository(label),
      organizationRepository: UnsupportedOrganizationRepository(label),
      deviceRepository: UnsupportedDeviceRepository(label),
      notificationRepository: notificationRepository,
      notificationDelivery: NoopNotificationDelivery(
        transport: BackendConfig.notificationTransport,
      ),
      realtimeUpdates: UnsupportedRealtimeUpdates(label),
      fileStorageRepository: UnsupportedFileStorageRepository(label),
    );
  }
}
