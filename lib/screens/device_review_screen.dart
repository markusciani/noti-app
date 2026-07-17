import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/registered_device.dart';
import '../services/device_service.dart';
import '../services/organization_service.dart';
import '../widgets/adaptive_page_body.dart';

class DeviceReviewScreen extends StatelessWidget {
  const DeviceReviewScreen({super.key, required this.deviceId});

  final String deviceId;

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;
    final organizationService = OrganizationService();
    final deviceService = DeviceService();

    return Scaffold(
      appBar: AppBar(title: const Text('Review device')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: firestore.collection('devices').doc(deviceId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final doc = snapshot.data!;
          if (!doc.exists) {
            return const Center(child: Text('This device could not be found.'));
          }

          final device = RegisteredDevice.fromFirestore(doc);
          return AdaptivePageBody(
            maxWidth: 760,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  device.displayName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Review this tablet and decide whether it should be approved or disabled.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _DetailRow(
                          label: 'Join status',
                          value: device.joinStatus,
                        ),
                        _DetailRow(label: 'Type', value: device.deviceType),
                        _DetailRow(
                          label: 'Device number',
                          value: device.deviceNumber,
                        ),
                        _DetailRow(
                          label: 'Model',
                          value: '${device.manufacturer} ${device.model}'
                              .trim(),
                        ),
                        _DetailRow(
                          label: 'Android',
                          value: device.platformVersion,
                        ),
                        _DetailRow(
                          label: 'App version',
                          value: device.appVersion,
                        ),
                        _DetailRow(
                          label: 'Notifications',
                          value: device.notificationsEnabled
                              ? 'Enabled'
                              : 'Off',
                        ),
                        _DetailRow(
                          label: 'Disabled',
                          value: device.isDisabled ? 'Yes' : 'No',
                        ),
                        _DetailRow(label: 'Device ID', value: device.id),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: device.joinStatus == 'approved'
                          ? null
                          : () async {
                              await organizationService.approveDevice(
                                device.id,
                              );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Device approved.'),
                                ),
                              );
                            },
                      icon: const Icon(Icons.how_to_reg_rounded),
                      label: Text(
                        device.joinStatus == 'approved'
                            ? 'Already approved'
                            : 'Approve device',
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () async {
                        await deviceService.setDeviceDisabled(
                          device.id,
                          !device.isDisabled,
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              device.isDisabled
                                  ? 'Device enabled.'
                                  : 'Device disabled.',
                            ),
                          ),
                        );
                      },
                      icon: Icon(
                        device.isDisabled
                            ? Icons.check_circle_outline_rounded
                            : Icons.block_rounded,
                      ),
                      label: Text(
                        device.isDisabled ? 'Enable device' : 'Disable device',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
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
