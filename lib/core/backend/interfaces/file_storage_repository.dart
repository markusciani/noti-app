abstract class FileStorageRepository {
  Future<String> upload({
    required String path,
    required List<int> bytes,
    required String contentType,
  });
}
