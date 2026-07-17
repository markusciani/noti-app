import 'package:flutter/material.dart';

import '../models/device_registration.dart';
import '../models/organization.dart';
import '../widgets/adaptive_page_body.dart';

class DeviceOnboardingScreen extends StatefulWidget {
  const DeviceOnboardingScreen({super.key});

  @override
  State<DeviceOnboardingScreen> createState() => _DeviceOnboardingScreenState();
}

class _DeviceOnboardingScreenState extends State<DeviceOnboardingScreen> {
  final _deviceNumberController = TextEditingController();
  String _deviceType = 'tablet';

  static const _deviceTypes = <String, String>{
    'tablet': 'Tablet',
    'phone': 'Phone',
    'director_tablet': 'Director tablet',
    'computer': 'Computer',
    'other': 'Other',
  };

  @override
  void dispose() {
    _deviceNumberController.dispose();
    super.dispose();
  }

  void _continue() {
    final number = _deviceNumberController.text.trim();
    if (number.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter the tablet number.')));
      return;
    }

    Navigator.of(context).pop(
      DeviceRegistration(
        organizationId: Organization.defaultId,
        organizationName: Organization.defaultName,
        deviceType: _deviceType,
        displayName: 'Maranatha $number',
        deviceNumber: number,
        staffAccessRequested: _deviceType == 'director_tablet',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Set up this device')),
      body: AdaptivePageBody(
        maxWidth: 620,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Text(
              'Welcome to Noti',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Set up this tablet for Maranatha Church. Director tablets are available immediately; regular member tablets wait for approval.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            Card(
              color: colors.primaryContainer,
              child: const ListTile(
                leading: Icon(Icons.church_rounded),
                title: Text('Maranatha Church'),
                subtitle: Text('The only church group available in this app.'),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _deviceType,
                      decoration: const InputDecoration(
                        labelText: 'Device type',
                        prefixIcon: Icon(Icons.devices_other_rounded),
                      ),
                      items: _deviceTypes.entries
                          .map(
                            (entry) => DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _deviceType = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _deviceNumberController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Tablet number',
                        hintText: '30',
                        prefixIcon: Icon(Icons.tag_rounded),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: colors.secondaryContainer,
              child: const ListTile(
                leading: Icon(Icons.info_outline_rounded),
                title: Text('Director access stays hidden'),
                subtitle: Text(
                  'If this is a director tablet, choose Yes when Noti asks. Access is protected by the tablet lock screen.',
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _continue,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
