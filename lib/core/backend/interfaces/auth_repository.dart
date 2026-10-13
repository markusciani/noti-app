abstract class AuthRepository {
  Future<bool> isSignedIn();
  Future<String?> currentUserId();
  Future<String?> currentIdToken({bool forceRefresh = false});
}
