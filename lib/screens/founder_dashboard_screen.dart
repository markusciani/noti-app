import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/registered_device.dart';
import '../services/auth_service.dart';
import '../services/organization_service.dart';
import '../widgets/adaptive_page_body.dart';
import 'admin_entry_screen.dart';
import 'admin_create_announcement_screen.dart';
import 'admin_manage_announcements_screen.dart';
import 'admin_profile_screen.dart';
import 'admin_push_notifications_screen.dart';
import 'device_dashboard_screen.dart';
import 'director_song_delivery_screen.dart';
import 'founder_staff_screen.dart';
import 'organization_settings_screen.dart';

class FounderDashboardScreen extends StatelessWidget {
  const FounderDashboardScreen({super.key});

  Future<String?> _selectOrganization(BuildContext context) async {
    final organizations = await OrganizationService()
        .getAvailableOrganizations();
    if (!context.mounted) return null;
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Choose an organization'),
        content: SizedBox(
          width: 420,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: organizations.length,
            itemBuilder: (context, index) {
              final organization = organizations[index];
              return ListTile(
                leading: const Icon(Icons.groups_rounded),
                title: Text(organization.name),
                onTap: () => Navigator.pop(dialogContext, organization.id),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _openOrganizationScreen(
    BuildContext context,
    Widget Function(String organizationId) builder,
  ) async {
    final organizationId = await _selectOrganization(context);
    if (organizationId == null || !context.mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => builder(organizationId)));
  }

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
    final firestore = FirebaseFirestore.instance;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Noti Founder'),
        actions: [
          IconButton(
            tooltip: 'Organizations',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const OrganizationSettingsScreen(),
              ),
            ),
            icon: const Icon(Icons.groups_rounded),
          ),
          IconButton(
            tooltip: 'Profile',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdminProfileScreen()),
            ),
            icon: const Icon(Icons.person_rounded),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => _signOut(context),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: AdaptivePageBody(
        maxWidth: 1100,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Text(
              'Founder console',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Global visibility for organizations, staff, devices, and notification activity.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            _FounderActionTile(
              icon: Icons.add_circle_rounded,
              title: 'Send a message to a group',
              subtitle: 'Choose an organization and publish an announcement.',
              onTap: () => _openOrganizationScreen(
                context,
                (organizationId) => AdminCreateAnnouncementScreen(
                  organizationId: organizationId,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _FounderActionTile(
              icon: Icons.notifications_active_rounded,
              title: 'Send a group broadcast',
              subtitle: 'Send a custom push notification to one organization.',
              onTap: () => _openOrganizationScreen(
                context,
                (organizationId) => AdminPushNotificationsScreen(
                  organizationId: organizationId,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _FounderActionTile(
              icon: Icons.library_music_rounded,
              title: 'Act as a director',
              subtitle: 'Send one or two songs to a selected organization.',
              onTap: () => _openOrganizationScreen(
                context,
                (organizationId) =>
                    DirectorSongDeliveryScreen(organizationId: organizationId),
              ),
            ),
            const SizedBox(height: 12),
            _FounderActionTile(
              icon: Icons.edit_note_rounded,
              title: 'Manage group announcements',
              subtitle: 'Edit or delete announcements for one organization.',
              onTap: () => _openOrganizationScreen(
                context,
                (organizationId) => AdminManageAnnouncementsScreen(
                  organizationId: organizationId,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _FounderActionTile(
              icon: Icons.devices_rounded,
              title: 'Manage all connected devices',
              subtitle: 'Review devices across every organization.',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const DeviceDashboardScreen(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _FounderActionTile(
              icon: Icons.manage_accounts_rounded,
              title: 'Manage staff access',
              subtitle:
                  'Assign existing Firebase accounts as admins or directors.',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FounderStaffScreen()),
              ),
            ),
            const SizedBox(height: 20),
            _UsersSection(stream: firestore.collection('users').snapshots()),
            const SizedBox(height: 12),
            _DevicesSection(
              stream: firestore.collection('devices').snapshots(),
            ),
            const SizedBox(height: 12),
            _OrganizationsSection(
              stream: firestore.collection('organizations').snapshots(),
            ),
            const SizedBox(height: 12),
            _LogsSection(
              stream: firestore
                  .collection('notification_logs')
                  .orderBy('sentAt', descending: true)
                  .limit(100)
                  .snapshots(),
            ),
          ],
        ),
      ),
    );
  }
}

class _FounderActionTile extends StatelessWidget {
  const _FounderActionTile({
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
        borderRadius: BorderRadius.circular(20),
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
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(subtitle),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _UsersSection extends StatelessWidget {
  const _UsersSection({required this.stream});

  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;

  @override
  Widget build(BuildContext context) {
    return _FounderSection(
      title: 'All staff accounts',
      icon: Icons.manage_accounts_rounded,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Text('Could not load staff: ${snapshot.error}');
          }
          if (!snapshot.hasData) {
            return const LinearProgressIndicator();
          }
          final users = snapshot.data!.docs;
          if (users.isEmpty) {
            return const Text('No staff profiles have been created.');
          }
          return Column(
            children: users.map((doc) {
              final data = doc.data();
              final email = data['email'] as String? ?? doc.id;
              final role = data['role'] as String? ?? 'unknown';
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  child: Text(
                    role.isEmpty ? '?' : role.substring(0, 1).toUpperCase(),
                  ),
                ),
                title: Text(email),
                subtitle: Text(
                  '${role.toUpperCase()} • ${data['enabled'] == false ? 'Disabled' : 'Enabled'}',
                ),
                trailing: Text(
                  doc.id,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _DevicesSection extends StatelessWidget {
  const _DevicesSection({required this.stream});

  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;

  @override
  Widget build(BuildContext context) {
    return _FounderSection(
      title: 'All connected devices',
      icon: Icons.devices_rounded,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Text('Could not load devices: ${snapshot.error}');
          }
          if (!snapshot.hasData) {
            return const LinearProgressIndicator();
          }
          final devices = snapshot.data!.docs
              .map(RegisteredDevice.fromFirestore)
              .toList();
          if (devices.isEmpty) {
            return const Text('No devices registered.');
          }
          return Column(
            children: devices
                .map(
                  (device) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.tablet_android_rounded),
                    title: Text(device.displayName),
                    subtitle: Text(
                      '${device.organizationName.isEmpty ? device.organizationId : device.organizationName} • ${device.joinStatus}',
                    ),
                    trailing: Text(device.appVersion),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }
}

class _OrganizationsSection extends StatelessWidget {
  const _OrganizationsSection({required this.stream});

  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;

  @override
  Widget build(BuildContext context) {
    return _FounderSection(
      title: 'All organizations',
      icon: Icons.groups_rounded,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Text('Could not load organizations: ${snapshot.error}');
          }
          if (!snapshot.hasData) {
            return const LinearProgressIndicator();
          }
          final organizations = snapshot.data!.docs;
          if (organizations.isEmpty) {
            return const Text('No organization records yet.');
          }
          return Column(
            children: organizations.map((doc) {
              final data = doc.data();
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.business_rounded),
                title: Text(data['name'] as String? ?? doc.id),
                subtitle: Text(doc.id),
                trailing: Text(data['enabled'] == false ? 'Paused' : 'Active'),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _LogsSection extends StatelessWidget {
  const _LogsSection({required this.stream});

  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;

  @override
  Widget build(BuildContext context) {
    return _FounderSection(
      title: 'Notification logs',
      icon: Icons.receipt_long_rounded,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Text('Could not load logs: ${snapshot.error}');
          }
          if (!snapshot.hasData) {
            return const LinearProgressIndicator();
          }
          final logs = snapshot.data!.docs;
          if (logs.isEmpty) {
            return const Text('No notification logs yet.');
          }
          return Column(
            children: logs.map((doc) {
              final data = doc.data();
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.notifications_active_rounded),
                title: Text(
                  data['title'] as String? ??
                      data['type'] as String? ??
                      'Notification',
                ),
                subtitle: Text(
                  '${data['topic'] ?? 'Unknown organization'} • ${data['status'] ?? 'unknown'}',
                ),
                trailing: Text(
                  doc.id,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _FounderSection extends StatelessWidget {
  const _FounderSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}
