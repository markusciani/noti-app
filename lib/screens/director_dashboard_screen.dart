import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../widgets/adaptive_page_body.dart';
import 'admin_entry_screen.dart';
import 'admin_profile_screen.dart';
import 'director_song_delivery_screen.dart';

class DirectorDashboardScreen extends StatelessWidget {
  const DirectorDashboardScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    await AuthService().signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AdminEntryScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final email = FirebaseAuth.instance.currentUser?.email ?? 'Director';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Noti Director'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => _signOut(context),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: AdaptivePageBody(
          maxWidth: 760,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Director panel',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Send song files to every tablet and manage your director profile.',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 6),
              Text(
                email,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              _DirectorActionTile(
                icon: Icons.library_music_rounded,
                title: 'Send songs',
                subtitle: 'Choose one or two songs and notify every tablet.',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const DirectorSongDeliveryScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _DirectorActionTile(
                icon: Icons.person_rounded,
                title: 'Profile',
                subtitle: 'Set the first name shown on song notifications.',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AdminProfileScreen()),
                ),
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.timer_outlined, color: colors.primary),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'After sending, you have five minutes to edit or delete a song notification. The files stay on the tablets and are never uploaded.',
                        ),
                      ),
                    ],
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

class _DirectorActionTile extends StatelessWidget {
  const _DirectorActionTile({
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
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: colors.primaryContainer,
                foregroundColor: colors.primary,
                child: Icon(icon),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
