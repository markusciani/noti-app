class SongFile {
  const SongFile({
    required this.relativePath,
    required this.fileName,
    required this.mimeType,
  });

  final String relativePath;
  final String fileName;
  final String mimeType;

  factory SongFile.fromMap(Map<String, dynamic> data) {
    return SongFile(
      relativePath: data['relativePath'] as String? ?? '',
      fileName: data['fileName'] as String? ?? 'Song file',
      mimeType: data['mimeType'] as String? ?? 'application/octet-stream',
    );
  }

  Map<String, dynamic> toMap() => {
    'relativePath': relativePath,
    'fileName': fileName,
    'mimeType': mimeType,
  };
}
