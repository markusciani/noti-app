import 'package:flutter/material.dart';

import '../services/music_directory_service.dart';
import '../widgets/adaptive_page_body.dart';

class MusicFolderScreen extends StatefulWidget {
  const MusicFolderScreen({super.key});

  @override
  State<MusicFolderScreen> createState() => _MusicFolderScreenState();
}

class _MusicFolderScreenState extends State<MusicFolderScreen> {
  final _musicDirectoryService = MusicDirectoryService();
  bool _loading = true;
  bool _hasFolder = false;
  bool _choosing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final hasFolder = await _musicDirectoryService.hasMusicFolder;
      if (mounted) {
        setState(() {
          _hasFolder = hasFolder;
          _loading = false;
        });
      }
    } on Object catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Noti could not check the music folder.';
        });
      }
    }
  }

  Future<void> _chooseFolder() async {
    setState(() {
      _choosing = true;
      _error = null;
    });
    try {
      final selected = await _musicDirectoryService.chooseMusicFolder();
      if (mounted) setState(() => _hasFolder = selected);
    } on Object catch (_) {
      if (mounted) {
        setState(() => _error = 'Noti could not save access to that folder.');
      }
    } finally {
      if (mounted) setState(() => _choosing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Music folder access')),
      body: AdaptivePageBody(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _hasFolder
                          ? Icons.folder_shared_rounded
                          : Icons.folder_off_rounded,
                      size: 48,
                      color: _hasFolder ? colors.primary : colors.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _hasFolder
                          ? 'Music folder is ready'
                          : 'Allow Music folder access',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Noti uses the default Music folder on this tablet so directors can send song links that open locally on every device. Your files are not uploaded.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          _hasFolder
                              ? 'When a director sends a song, tap Open song in the notification and Android will launch your default file app.'
                              : 'This is required once per tablet. Android will ask for storage access so Noti can read the default Music folder directly.',
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: TextStyle(color: colors.error)),
                    ],
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _choosing ? null : _chooseFolder,
                        icon: _choosing
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.folder_open_rounded),
                        label: Text(
                          _hasFolder
                              ? 'Check Music folder access'
                              : 'Allow Music folder access',
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
