import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/registered_device.dart';
import '../services/device_service.dart';
import '../widgets/adaptive_page_body.dart';

class DeviceDashboardScreen extends StatelessWidget {
  const DeviceDashboardScreen({super.key});

  String _formatRelative(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays} d ago';
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final deviceService = DeviceService();
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Connected Devices')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: deviceService.watchDevices(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? const [];
          final devices = docs.map(RegisteredDevice.fromFirestore).toList();

          final totalDevices = devices.length;
          final activeToday = devices
              .where((d) => _isToday(d.lastSeenAt))
              .length;
          final notificationsDisabled = devices
              .where((d) => !d.notificationsEnabled)
              .length;
          final outdated = devices.where((d) => d.isOutdated).length;

          return RefreshIndicator(
            onRefresh: () async {
              await deviceService.updatePresence();
            },
            child: AdaptivePageBody(
              maxWidth: 1080,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Device Health',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Track which devices are connected to Noti, whether notifications are enabled, and which installs need updates.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 920
                          ? 4
                          : constraints.maxWidth >= 560
                          ? 2
                          : 1;
                      final itemWidth =
                          (constraints.maxWidth - (12 * (columns - 1))) /
                          columns;

                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: itemWidth,
                            child: _MetricCard(
                              label: 'Total devices',
                              value: '$totalDevices',
                              icon: Icons.devices_rounded,
                              color: colors.primary,
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _MetricCard(
                              label: 'Active today',
                              value: '$activeToday',
                              icon: Icons.bolt_rounded,
                              color: colors.secondary,
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _MetricCard(
                              label: 'Notifications disabled',
                              value: '$notificationsDisabled',
                              icon: Icons.notifications_off_rounded,
                              color: colors.tertiary,
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _MetricCard(
                              label: 'Outdated versions',
                              value: '$outdated',
                              icon: Icons.system_update_alt_rounded,
                              color: colors.error,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Text(
                        'Recent Devices',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${devices.length} tracked',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (devices.isEmpty)
                    _EmptyState(
                      icon: Icons.phonelink_off_rounded,
                      title: 'No devices registered yet',
                      message:
                          'Once members open Noti, each install will appear here automatically.',
                    )
                  else
                    ...devices.map(
                      (device) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _DeviceTile(
                          device: device,
                          relativeTime: _formatRelative(device.lastSeenAt),
                          onDisableToggle: () async {
                            await deviceService.setDeviceDisabled(
                              device.id,
                              !device.isDisabled,
                            );
                          },
                          onDelete: () async {
                            await deviceService.deleteDevice(device.id);
                          },
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.device,
    required this.relativeTime,
    required this.onDisableToggle,
    required this.onDelete,
  });

  final RegisteredDevice device;
  final String relativeTime;
  final VoidCallback onDisableToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final statusColor = device.isDisabled ? colors.error : colors.primary;

    return Card(
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(
          device.deviceName,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '${device.manufacturer} ${device.model}'.trim(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: colors.onSurfaceVariant,
        ),
        children: [
          _DetailRow(
            label: 'Status',
            value: device.isDisabled ? 'Disabled' : 'Enabled',
          ),
          _DetailRow(
            label: 'Notifications',
            value: device.notificationsEnabled ? 'Enabled' : 'Off',
          ),
          _DetailRow(label: 'App version', value: device.appVersion),
          _DetailRow(label: 'Android', value: device.platformVersion),
          _DetailRow(label: 'Last seen', value: relativeTime),
          _DetailRow(
            label: 'Minimum version',
            value: device.minimumSupportedVersion.isEmpty
                ? 'Not set'
                : device.minimumSupportedVersion,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.tonal(
                onPressed: onDisableToggle,
                child: Text(
                  device.isDisabled ? 'Enable device' : 'Disable device',
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: onDelete,
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.error,
                  side: BorderSide(color: colors.error),
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Chip(
              label: Text(
                device.isOutdated ? 'Outdated' : 'Up to date',
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              backgroundColor: statusColor.withValues(alpha: 0.12),
              side: BorderSide.none,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'Unknown' : value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(icon, size: 64, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
