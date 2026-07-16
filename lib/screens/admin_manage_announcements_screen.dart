import 'package:flutter/material.dart';

import '../models/announcement.dart';
import '../services/firestore_service.dart';
import '../widgets/adaptive_page_body.dart';
import 'admin_create_announcement_screen.dart';

class AdminManageAnnouncementsScreen extends StatelessWidget {
  AdminManageAnnouncementsScreen({super.key});

  final FirestoreService _firestoreService = FirestoreService();

  Future<void> _deleteAnnouncement(
    BuildContext context,
    Announcement announcement,
  ) async {
    final colors = Theme.of(context).colorScheme;
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Delete announcement?'),
              content: Text(
                'This will permanently delete "${announcement.title}" from Firestore.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.error,
                    foregroundColor: colors.onError,
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (confirmed != true) return;
    await _firestoreService.deleteAnnouncement(announcement.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Announcement deleted')));
  }

  Future<void> _openActions(
    BuildContext context,
    Announcement announcement,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_note_rounded),
                title: const Text('Edit announcement'),
                onTap: () => Navigator.of(sheetContext).pop('edit'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('Delete announcement'),
                onTap: () => Navigator.of(sheetContext).pop('delete'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (!context.mounted) return;
    if (action == 'edit') {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              AdminCreateAnnouncementScreen(announcement: announcement),
        ),
      );
    } else if (action == 'delete') {
      await _deleteAnnouncement(context, announcement);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Announcements')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const AdminCreateAnnouncementScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('New'),
      ),
      body: StreamBuilder<List<Announcement>>(
        stream: _firestoreService.getAnnouncements(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Could not load announcements: ${snapshot.error}'),
            );
          }

          final announcements = snapshot.data ?? const <Announcement>[];
          if (announcements.isEmpty) {
            return const Center(child: Text('No announcements yet.'));
          }

          return AdaptivePageBody(
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: announcements.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final announcement = announcements[index];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: colors.primaryContainer,
                      foregroundColor: colors.primary,
                      child: Icon(
                        announcement.pinned
                            ? Icons.push_pin_rounded
                            : Icons.campaign_rounded,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      announcement.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      announcement.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.more_horiz_rounded),
                    onTap: () => _openActions(context, announcement),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
