import 'package:flutter/services.dart';

import '../models/song_file.dart';

class MusicDirectoryService {
  static const MethodChannel _channel = MethodChannel(
    'org.ciani01.noti/music_directory',
  );

  Future<bool> get hasMusicFolder async {
    final uri = await _channel.invokeMethod<String>('getMusicDirectory');
    return uri != null && uri.isNotEmpty;
  }

  Future<bool> chooseMusicFolder() async {
    final uri = await _channel.invokeMethod<String>('requestMusicAccess');
    return uri != null && uri.isNotEmpty;
  }

  Future<SongFile?> pickSong() async {
    final data = await _channel.invokeMapMethod<String, dynamic>(
      'pickMusicFile',
    );
    if (data == null) return null;
    return SongFile.fromMap(data);
  }

  Future<List<SongFile>> listSongs() async {
    final files = await _channel.invokeListMethod<dynamic>('listMusicFiles');
    if (files == null) return const [];
    return files
        .whereType<Map>()
        .map(
          (file) => SongFile.fromMap(
            file.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList(growable: false);
  }

  Future<void> openSong(SongFile song) async {
    await _channel.invokeMethod<void>('openMusicFile', song.toMap());
  }
}
