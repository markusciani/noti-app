import 'package:flutter/material.dart';

import '../models/registered_device.dart';
import '../services/device_service.dart';
import '../services/organization_service.dart';
import '../widgets/adaptive_page_body.dart';

class DeviceDashboardScreen extends StatefulWidget {
  const DeviceDashboardScreen({super.key});

  @override
  State<DeviceDashboardScreen> createState() => _DeviceDashboardScreenState();
}

class _DeviceDashboardScreenState extends State<DeviceDashboardScreen> {
  final DeviceService _deviceService = DeviceService();
  final OrganizationService _organizationService = OrganizationService();

  late Future<List<RegisteredDevice>> _devicesFuture;

  @override
  void initState() {
    super.initState();
    _devicesFuture = _deviceService.fetchDevicesForDashboard();
  }

  Future<void> _reload() async {
    final future = _deviceService.fetchDevicesForDashboard();
    if (mounted) {
      setState(() {
        _devicesFuture = future;
      });
    }
    await future;
  }

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

  Future<void> _renameDevice(RegisteredDevice device) async {
    final numberController = TextEditingController(text: device.deviceNumber);
    var deviceType = device.deviceType;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Rename device'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _deviceTypes.containsKey(deviceType)
                    ? deviceType
                    : 'other',
                decoration: const InputDecoration(labelText: 'Device type'),
                items: _deviceTypes.entries
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => deviceType = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: numberController,
                maxLength: 40,
                decoration: const InputDecoration(
                  labelText: 'Device number',
                  hintText: 'For example, 30',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (result != true || numberController.text.trim().isEmpty) {
      numberController.dispose();
      return;
    }
    try {
      await _organizationService.updateDeviceProfile(
        deviceId: device.id,
        deviceType: deviceType,
        displayName: 'Maranatha ${numberController.text.trim()}',
        deviceNumber: numberController.text,
      );
      await _reload();
    } finally {
      numberController.dispose();
    }
  }

  Future<void> _setDeviceDisabled(RegisteredDevice device) async {
    await _deviceService.setDeviceDisabled(device.id, !device.isDisabled);
    await _reload();
  }

  Future<void> _deleteDevice(RegisteredDevice device) async {
    await _deviceService.deleteDevice(device.id);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Connected Devices')),
      body: FutureBuilder<List<RegisteredDevice>>(
        future: _devicesFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final devices = snapshot.data ?? const <RegisteredDevice>[];
          final totalDevices = devices.length;
          final activeToday = devices.where((d) => _isToday(d.lastSeenAt)).length;
          final notificationsDisabled = devices
              .where((d) => !d.notificationsEnabled)
              .length;
          final outdated = devices.where((d) => d.isOutdated).length;
          final missingFcmToken = devices.where((d) => d.fcmToken.isEmpty).length;
          final listenerInactive = devices
              .where((d) => !d.songDeliveryListenerActive)
              .length;

          return RefreshIndicator(
            onRefresh: _reload,
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
                          SizedBox(
                            width: itemWidth,
                            child: _MetricCard(
                              label: 'Missing FCM token',
                              value: '$missingFcmToken',
                              icon: Icons.key_off_rounded,
                              color: colors.primary,
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _MetricCard(
                              label: 'Song listener inactive',
                              value: '$listenerInactive',
                              icon: Icons.sync_problem_rounded,
                              color: colors.tertiary,
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
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      devices.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (devices.isEmpty)
                    const _EmptyState(
                      icon: Icons.phonelink_off_rounded,
                      title: 'No devices registered yet',
                      message:
                          'Open Noti on each tablet and keep it on the home page for a moment. Pull down here afterward to reload the connected devices list.',
                    )
                  else
                    ...devices.map(
                      (device) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _DeviceTile(
                          device: device,
                          relativeTime: _formatRelative(device.lastSeenAt),
                          onDisableToggle: () => _setDeviceDisabled(device),
                          onDelete: () => _deleteDevice(device),
                          onRename: () => _renameDevice(device),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

const _deviceTypes = <String, String>{
  'tablet': 'Tablet',
  'phone': 'Phone',
  'director_tablet': 'Director tablet',
  'computer': 'Computer',
  'other': 'Other',
};

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
    required this.onRename,
  });

  final RegisteredDevice device;
  final String relativeTime;
  final VoidCallback onDisableToggle;
  final VoidCallback onDelete;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final statusColor = device.isDisabled ? colors.error : colors.primary;

    return Card(
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(
          device.displayName,
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
          if (!device.notificationsEnabled)
            Card(
              color: colors.errorContainer,
              child: ListTile(
                dense: true,
                leading: Icon(
                  Icons.notifications_off_rounded,
                  color: colors.error,
                ),
                title: const Text('Notifications are disabled'),
                subtitle: const Text(
                  'Ask someone to enable Noti notifications in Android Settings.',
                ),
              ),
            ),
          if (device.fcmToken.isEmpty)
            Card(
              color: colors.errorContainer,
              child: ListTile(
                dense: true,
                leading: Icon(Icons.key_off_rounded, color: colors.error),
                title: const Text('FCM token is missing'),
                subtitle: const Text(
                  'Open Noti on this tablet and leave it on the home screen so Firebase can register push delivery.',
                ),
              ),
            ),
          if (!device.songDeliveryListenerActive)
            Card(
              color: colors.tertiaryContainer,
              child: ListTile(
                dense: true,
                leading: Icon(
                  Icons.sync_problem_rounded,
                  color: colors.tertiary,
                ),
                title: const Text('Song listener is inactive'),
                subtitle: Text(
                  device.songDeliveryListenerStatus.isEmpty
                      ? 'Open Noti on this tablet to restart the song delivery listener.'
                      : device.songDeliveryListenerStatus,
                ),
              ),
            ),
          _DetailRow(
            label: 'Organization',
            value: device.organizationName.isEmpty
                ? device.organizationId
                : device.organizationName,
          ),
          _DetailRow(
            label: 'Type',
            value: _deviceTypes[device.deviceType] ?? device.deviceType,
          ),
          _DetailRow(label: 'Device ID', value: device.id),
          if (device.firstName.isNotEmpty)
            _DetailRow(label: 'First name', value: device.firstName),
          if (device.lastName.isNotEmpty)
            _DetailRow(label: 'Last name', value: device.lastName),
          if (device.deviceNumber.isNotEmpty)
            _DetailRow(label: 'Device number', value: device.deviceNumber),
          _DetailRow(
            label: 'Status',
            value: device.isDisabled ? 'Disabled' : 'Enabled',
          ),
          _DetailRow(
            label: 'Notifications',
            value: device.notificationsEnabled ? 'Enabled' : 'Off',
          ),
          _DetailRow(
            label: 'Permission',
            value: device.notificationPermissionStatus,
          ),
          _DetailRow(
            label: 'FCM token',
            value: device.fcmToken.isEmpty ? 'Missing' : 'Available',
          ),
          _DetailRow(
            label: 'Song listener',
            value: device.songDeliveryListenerActive ? 'Active' : 'Inactive',
          ),
          if (device.songDeliveryListenerStatus.isNotEmpty)
            _DetailRow(
              label: 'Listener status',
              value: device.songDeliveryListenerStatus,
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
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: onRename,
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Rename'),
              ),
              FilledButton.tonal(
                onPressed: onDisableToggle,
                child: Text(
                  device.isDisabled ? 'Enable device' : 'Disable device',
                ),
              ),
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
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(icon, size: 42, color: colors.primary),
            const SizedBox(height: 14),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
