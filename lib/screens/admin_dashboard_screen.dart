import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'admin_create_announcement_screen.dart';
import 'admin_manage_announcements_screen.dart';
import 'admin_profile_screen.dart';
import 'admin_push_notifications_screen.dart';
import 'admin_settings_screen.dart';
import 'device_dashboard_screen.dart';
import 'director_song_delivery_screen.dart';
import '../widgets/adaptive_page_body.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Future<void> _exitPanel() async {
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Noti Admin'),
        actions: [
          IconButton(
            tooltip: 'Profile',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminProfileScreen()),
              );
            },
            icon: const Icon(Icons.person_rounded),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminSettingsScreen()),
              );
            },
            icon: const Icon(Icons.settings_rounded),
          ),
          IconButton(
            tooltip: 'Exit',
            onPressed: _exitPanel,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      body: AdaptivePageBody(
        maxWidth: 880,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            StreamBuilder<User?>(
              stream: FirebaseAuth.instance.userChanges(),
              builder: (context, snapshot) {
                final displayName = snapshot.data?.displayName?.trim() ?? '';
                final firstName = displayName.isEmpty
                    ? ''
                    : displayName.split(RegExp(r'\s+')).first;
                return Text(
                  firstName.isEmpty
                      ? 'Director Dashboard'
                      : 'Hello there, $firstName',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Manage Maranatha Church announcements, connected tablets, and notifications.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            _ActionTile(
              icon: Icons.add_circle_rounded,
              title: 'Create announcement',
              subtitle: 'Publish a church update to all devices.',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AdminCreateAnnouncementScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _ActionTile(
              icon: Icons.edit_note_rounded,
              title: 'Manage announcements',
              subtitle: 'Edit or delete existing posts.',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AdminManageAnnouncementsScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _ActionTile(
              icon: Icons.devices_rounded,
              title: 'Connected devices',
              subtitle: 'Rename, disable, or delete devices.',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const DeviceDashboardScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _ActionTile(
              icon: Icons.notifications_active_rounded,
              title: 'Push notifications',
              subtitle: 'Send a protected test broadcast to all devices.',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AdminPushNotificationsScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _ActionTile(
              icon: Icons.library_music_rounded,
              title: 'Song notifications',
              subtitle:
                  'Edit or delete song alerts during the five-minute window.',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const DirectorSongDeliveryScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          foregroundColor: Theme.of(context).colorScheme.primary,
          child: Icon(icon, size: 22),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
