import '../../../core/backend/interfaces/auth_repository.dart';
import '../../../core/backend/interfaces/device_repository.dart';
import '../../../core/backend/interfaces/file_storage_repository.dart';
import '../../../core/backend/interfaces/organization_repository.dart';
import '../../../core/backend/interfaces/realtime_updates.dart';
import '../../../core/backend/interfaces/user_repository.dart';

class UnsupportedAuthRepository implements AuthRepository {
  UnsupportedAuthRepository(this.backendLabel);

  final String backendLabel;

  @override
  Future<String?> currentIdToken({bool forceRefresh = false}) {
    throw UnsupportedError(
      '$backendLabel auth is not implemented yet. Configure server-side auth first.',
    );
  }

  @override
  Future<String?> currentUserId() {
    throw UnsupportedError(
      '$backendLabel auth is not implemented yet. Configure server-side auth first.',
    );
  }

  @override
  Future<bool> isSignedIn() {
    throw UnsupportedError(
      '$backendLabel auth is not implemented yet. Configure server-side auth first.',
    );
  }
}

class UnsupportedUserRepository implements UserRepository {
  UnsupportedUserRepository(this.backendLabel);

  final String backendLabel;

  @override
  Future<Map<String, dynamic>?> currentUserProfile() {
    throw UnsupportedError(
      '$backendLabel user profiles are not implemented yet.',
    );
  }
}

class UnsupportedOrganizationRepository implements OrganizationRepository {
  UnsupportedOrganizationRepository(this.backendLabel);

  final String backendLabel;

  @override
  Future<List<Map<String, dynamic>>> listOrganizations() {
    throw UnsupportedError(
      '$backendLabel organizations are not implemented yet.',
    );
  }
}

class UnsupportedDeviceRepository implements DeviceRepository {
  UnsupportedDeviceRepository(this.backendLabel);

  final String backendLabel;

  @override
  Future<void> upsertDevice(Map<String, dynamic> payload) {
    throw UnsupportedError('$backendLabel devices are not implemented yet.');
  }
}

class UnsupportedRealtimeUpdates implements RealtimeUpdates {
  UnsupportedRealtimeUpdates(this.backendLabel);

  final String backendLabel;

  @override
  Stream<T> watch<T>(String channel, T Function(dynamic payload) decode) {
    throw UnsupportedError('$backendLabel realtime updates are not implemented yet.');
  }
}

class UnsupportedFileStorageRepository implements FileStorageRepository {
  UnsupportedFileStorageRepository(this.backendLabel);

  final String backendLabel;

  @override
  Future<String> upload({
    required String path,
    required List<int> bytes,
    required String contentType,
  }) {
    throw UnsupportedError('$backendLabel file storage is not implemented yet.');
  }
}
