import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/device_service.dart';
import 'admin_dashboard_screen.dart';

class AdminEntryScreen extends StatefulWidget {
  const AdminEntryScreen({super.key});

  @override
  State<AdminEntryScreen> createState() => _AdminEntryScreenState();
}

class _AdminEntryScreenState extends State<AdminEntryScreen> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _unlock();
  }

  Future<void> _unlock() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final auth = AuthService();
      final role = await auth.currentStaffRole();
      final deviceService = DeviceService();
      final localDirectorAccess = await deviceService.staffAccessEnabled();

      if (role != StaffRole.director && !localDirectorAccess) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Director tools are not enabled on this device.';
        });
        return;
      }

      await deviceService.enableStaffAccess();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            'Director access could not be verified. Check your connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Director access')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.shield_rounded,
                  size: 56,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 18),
                Text(
                  _loading
                      ? 'Opening director access...'
                      : (_error ?? 'Director access'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (_loading) ...[
                  const SizedBox(height: 20),
                  const CircularProgressIndicator(),
                ] else ...[
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _unlock,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try again'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Back to Noti'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
