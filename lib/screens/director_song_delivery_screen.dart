import 'dart:async';

import 'package:flutter/material.dart';

import '../models/song_delivery.dart';
import '../models/song_file.dart';
import '../services/music_directory_service.dart';
import '../services/song_delivery_service.dart';
import '../widgets/adaptive_page_body.dart';

/// Staff-only song delivery. Files stay on church tablets; Firebase carries
/// only the relative path from each tablet's Music folder.
class DirectorSongDeliveryScreen extends StatefulWidget {
  const DirectorSongDeliveryScreen({
    super.key,
    this.delivery,
    this.organizationId,
  });

  final SongDelivery? delivery;
  final String? organizationId;

  @override
  State<DirectorSongDeliveryScreen> createState() =>
      _DirectorSongDeliveryScreenState();
}

class _DirectorSongDeliveryScreenState
    extends State<DirectorSongDeliveryScreen> {
  final _musicDirectoryService = MusicDirectoryService();
  final _songDeliveryService = SongDeliveryService();
  final _titleController = TextEditingController();

  SongFile? _primarySong;
  SongFile? _secondarySong;
  bool _includeSecondSong = false;
  bool _hasFolder = false;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  Timer? _clock;

  bool get _isEditing => widget.delivery != null;

  @override
  void initState() {
    super.initState();
    final delivery = widget.delivery;
    if (delivery != null) {
      _titleController.text = delivery.title;
      _primarySong = delivery.primarySong;
      _secondarySong = delivery.secondarySong;
      _includeSecondSong = delivery.secondarySong != null;
    }
    _loadWorkspace();
    _clock = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _loadWorkspace() async {
    try {
      final hasFolder = await _musicDirectoryService.hasMusicFolder;
      if (!mounted) return;
      setState(() {
        _hasFolder = hasFolder;
        _loading = false;
      });
    } on Object catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Noti could not load the director workspace. Try again.';
      });
    }
  }

  Future<bool> _confirmSend({
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _chooseFolder() async {
    try {
      final selected = await _musicDirectoryService.chooseMusicFolder();
      if (!mounted) return;
      setState(() => _hasFolder = selected);
      if (selected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Music folder access is ready on this tablet.'),
          ),
        );
      }
    } on Object catch (error) {
      _showError(error);
    }
  }

  Future<void> _pickSong({required bool secondSong}) async {
    if (!_hasFolder) {
      await _chooseFolder();
      if (!_hasFolder) return;
    }

    try {
      final song = await _musicDirectoryService.pickSong();
      if (song == null || !mounted) return;
      setState(() {
        if (secondSong) {
          _secondarySong = song;
        } else {
          _primarySong = song;
        }
        _error = null;
      });
    } on Object catch (error) {
      _showError(error);
    }
  }

  Future<void> _saveDelivery() async {
    final primarySong = _primarySong;
    if (primarySong == null) {
      setState(() => _error = 'Choose the first song before sending.');
      return;
    }
    if (_includeSecondSong && _secondarySong == null) {
      setState(
        () => _error =
            'Choose the second song or turn off the second song option.',
      );
      return;
    }

    final confirmed = await _confirmSend(
      title: _isEditing ? 'Save song changes?' : 'Send songs to every tablet?',
      message: _isEditing
          ? 'This sends a corrected song notification to every connected tablet.'
          : 'Every tablet will receive a notification with a button to open the selected song file.',
    );
    if (!confirmed) return;
    if (!mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final title = _titleController.text.trim().isEmpty
          ? 'Songs are ready'
          : _titleController.text.trim();
      if (_isEditing) {
        await _songDeliveryService.updateDelivery(
          deliveryId: widget.delivery!.id,
          title: title,
          primarySong: primarySong,
          secondarySong: _includeSecondSong ? _secondarySong : null,
          organizationId: widget.organizationId,
        );
      } else {
        await _songDeliveryService.createDelivery(
          title: title,
          primarySong: primarySong,
          secondarySong: _includeSecondSong ? _secondarySong : null,
          organizationId: widget.organizationId,
        );
      }
      if (!mounted) return;
      if (_isEditing) {
        Navigator.of(context).pop();
      } else {
        setState(() {
          _primarySong = null;
          _secondarySong = null;
          _includeSecondSong = false;
          _titleController.text = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Song notification sent to every tablet.'),
          ),
        );
      }
    } on Object catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editDelivery(SongDelivery delivery) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DirectorSongDeliveryScreen(delivery: delivery),
      ),
    );
  }

  Future<void> _withdrawDelivery(SongDelivery delivery) async {
    final confirmed = await _confirmSend(
      title: 'Delete notification?',
      message:
          'Noti will remove this song delivery and send a withdrawal to every tablet. Android may still show an already delivered system notification.',
    );
    if (!confirmed) return;
    if (!mounted) return;
    try {
      await _songDeliveryService.withdrawDelivery(
        delivery.id,
        organizationId: widget.organizationId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Song notification deleted.')),
      );
    } on Object catch (error) {
      _showError(error);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    setState(() => _error = _friendlyError(error));
  }

  String _friendlyError(Object error) {
    final value = error.toString();
    if (value.contains('permission-denied')) {
      return 'This signed-in account is not approved as a director.';
    }
    if (value.contains('failed-precondition')) {
      return 'The five-minute correction window has ended.';
    }
    return 'Could not complete that song delivery. Check your connection and try again.';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit song delivery' : 'Music director'),
      ),
      body: AdaptivePageBody(
        maxWidth: 760,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              _isEditing
                  ? 'Correct song delivery'
                  : 'Send songs to every tablet',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Songs remain on the church tablets. Noti sends the matching path from each tablet\'s Music folder.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(
                  backgroundColor: _hasFolder
                      ? colors.primaryContainer
                      : colors.errorContainer,
                  foregroundColor: _hasFolder
                      ? colors.primary
                      : colors.onErrorContainer,
                  child: Icon(
                    _hasFolder
                        ? Icons.folder_rounded
                        : Icons.folder_off_rounded,
                  ),
                ),
                title: Text(
                  _hasFolder
                      ? 'Music folder access ready'
                      : 'Allow access to Music folder',
                ),
                subtitle: Text(
                  _hasFolder
                      ? 'This tablet can find song files in its Music folder.'
                      : 'Noti will ask Android for file access and find the Music folder.',
                ),
                trailing: TextButton(
                  onPressed: _chooseFolder,
                  child: Text(_hasFolder ? 'Change' : 'Choose'),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Notification title',
                hintText: 'Songs are ready',
                prefixIcon: Icon(Icons.notifications_active_rounded),
              ),
            ),
            const SizedBox(height: 8),
            _SongPickerCard(
              number: 1,
              song: _primarySong,
              onPick: () => _pickSong(secondSong: false),
              onClear: _primarySong == null
                  ? null
                  : () => setState(() => _primarySong = null),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Add a second song'),
              subtitle: const Text(
                'Include another file in the same delivery.',
              ),
              value: _includeSecondSong,
              onChanged: (value) {
                setState(() {
                  _includeSecondSong = value;
                  if (!value) _secondarySong = null;
                });
              },
            ),
            if (_includeSecondSong) ...[
              const SizedBox(height: 8),
              _SongPickerCard(
                number: 2,
                song: _secondarySong,
                onPick: () => _pickSong(secondSong: true),
                onClear: _secondarySong == null
                    ? null
                    : () => setState(() => _secondarySong = null),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: colors.error)),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : _saveDelivery,
              icon: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(_isEditing ? Icons.save_rounded : Icons.send_rounded),
              label: Text(
                _isEditing ? 'Save correction' : 'Send song notification',
              ),
            ),
            if (!_isEditing) ...[
              const SizedBox(height: 28),
              Text(
                'Recent song deliveries',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              StreamBuilder<List<SongDelivery>>(
                stream: _songDeliveryService.watchMyDeliveries(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const _InfoCard(
                      icon: Icons.cloud_off_rounded,
                      message: 'Recent deliveries are unavailable right now.',
                    );
                  }
                  final deliveries = snapshot.data ?? const <SongDelivery>[];
                  if (deliveries.isEmpty) {
                    return const _InfoCard(
                      icon: Icons.music_off_rounded,
                      message:
                          'No song deliveries have been sent from this account yet.',
                    );
                  }
                  return Column(
                    children: [
                      for (final delivery in deliveries) ...[
                        _DeliveryCard(
                          delivery: delivery,
                          onEdit: delivery.canCorrect
                              ? () => _editDelivery(delivery)
                              : null,
                          onDelete: delivery.canCorrect
                              ? () => _withdrawDelivery(delivery)
                              : null,
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  );
                },
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SongPickerCard extends StatelessWidget {
  const _SongPickerCard({
    required this.number,
    required this.song,
    required this.onPick,
    required this.onClear,
  });

  final int number;
  final SongFile? song;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: colors.primaryContainer,
          foregroundColor: colors.primary,
          child: Text('$number'),
        ),
        title: Text(song?.fileName ?? 'Select song $number'),
        subtitle: Text(
          song?.relativePath ?? 'Choose a file from the Music folder.',
        ),
        trailing: Wrap(
          spacing: 2,
          children: [
            IconButton(
              tooltip: 'Choose song',
              onPressed: onPick,
              icon: const Icon(Icons.folder_open_rounded),
            ),
            if (onClear != null)
              IconButton(
                tooltip: 'Remove song',
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
              ),
          ],
        ),
      ),
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({
    required this.delivery,
    required this.onEdit,
    required this.onDelete,
  });

  final SongDelivery delivery;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final expiresAt = delivery.correctionWindowEndsAt;
    final secondsLeft = expiresAt == null
        ? 0
        : expiresAt.difference(DateTime.now()).inSeconds.clamp(0, 300);
    final minutes = secondsLeft ~/ 60;
    final seconds = secondsLeft % 60;
    final correctionLabel = delivery.canCorrect
        ? 'Corrections available for $minutes:${seconds.toString().padLeft(2, '0')}'
        : delivery.isActive
        ? 'Correction window closed'
        : 'Deleted';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              delivery.title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(delivery.primarySong.fileName),
            if (delivery.secondarySong != null)
              Text(delivery.secondarySong!.fileName),
            const SizedBox(height: 8),
            Text(
              correctionLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: delivery.canCorrect
                    ? colors.primary
                    : colors.onSurfaceVariant,
              ),
            ),
            if (onEdit != null || onDelete != null) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('Edit'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Delete notification'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}
