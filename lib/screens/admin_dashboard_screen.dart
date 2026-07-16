import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'admin_create_announcement_screen.dart';
import 'admin_entry_screen.dart';
import 'admin_manage_announcements_screen.dart';
import 'admin_profile_screen.dart';
import 'admin_push_notifications_screen.dart';
import 'admin_settings_screen.dart';
import 'device_dashboard_screen.dart';
import '../widgets/adaptive_page_body.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key, this.firstRun = false});

  final bool firstRun;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _authService = AuthService();
  final _pinController = TextEditingController();
  bool _pinSet = false;
  bool _pinVerified = false;
  bool _loadingPinState = true;
  String? _pinLoadError;

  @override
  void initState() {
    super.initState();
    _loadPinState();
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _loadPinState() async {
    try {
      final hasPin = await _authService.hasPin();
      if (!mounted) return;
      setState(() {
        _pinSet = hasPin;
        _pinVerified = !widget.firstRun && hasPin ? false : widget.firstRun;
        _loadingPinState = false;
        _pinLoadError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingPinState = false;
        _pinLoadError = 'Noti could not load your admin security settings.';
      });
    }
  }

  Future<void> _savePin() async {
    if (_pinController.text.trim().length < 4) return;
    try {
      await _authService.setPin(_pinController.text.trim());
      if (!mounted) return;
      setState(() {
        _pinSet = true;
        _pinVerified = true;
        _pinController.clear();
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save the PIN. Please try again.'),
        ),
      );
    }
  }

  Future<void> _verifyPin() async {
    try {
      final ok = await _authService.verifyPin(_pinController.text.trim());
      if (!mounted) return;
      if (ok) {
        setState(() {
          _pinVerified = true;
          _pinController.clear();
        });
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Incorrect PIN')));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not verify the PIN. Please try again.'),
        ),
      );
    }
  }

  Future<void> _verifyWithBiometrics() async {
    final ok = await _authService.authenticateWithBiometrics(
      reason: 'Unlock Noti Admin to continue.',
    );
    if (!mounted) return;
    if (ok) {
      setState(() {
        _pinVerified = true;
        _pinController.clear();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Biometric verification failed')),
      );
    }
  }

  Future<void> _signOut() async {
    await _authService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AdminEntryScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingPinState) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading admin security...'),
            ],
          ),
        ),
      );
    }

    if (_pinLoadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Noti Admin')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_rounded, size: 44),
                  const SizedBox(height: 16),
                  Text(
                    _pinLoadError!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () {
                      setState(() {
                        _loadingPinState = true;
                        _pinLoadError = null;
                      });
                      _loadPinState();
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try again'),
                  ),
                  TextButton(
                    onPressed: _signOut,
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (!_pinSet) {
      return Scaffold(
        appBar: AppBar(title: const Text('Create Admin PIN')),
        body: _PinPanel(
          title: 'Create a PIN',
          message:
              'This PIN is stored on the device and will be required before sending or managing announcements.',
          controller: _pinController,
          actionLabel: 'Save PIN',
          onAction: _savePin,
        ),
      );
    }

    if (!_pinVerified) {
      return Scaffold(
        appBar: AppBar(title: const Text('Verify PIN')),
        body: _PinPanel(
          title: 'Verify your PIN',
          message:
              'Enter your device PIN to continue into the admin dashboard.',
          controller: _pinController,
          actionLabel: 'Verify PIN',
          onAction: _verifyPin,
          onBiometricAction: _verifyWithBiometrics,
        ),
      );
    }

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
            tooltip: 'Sign out',
            onPressed: _signOut,
            icon: const Icon(Icons.logout_rounded),
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
                      ? 'Church Admin Dashboard'
                      : 'Hello there, $firstName',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Create announcements, keep your device list healthy, and prepare push-ready updates for every registered device.',
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
              subtitle: 'Review the device dashboard from the member app.',
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
          ],
        ),
      ),
    );
  }
}

class _PinPanel extends StatelessWidget {
  const _PinPanel({
    required this.title,
    required this.message,
    required this.controller,
    required this.actionLabel,
    required this.onAction,
    this.onBiometricAction,
  });

  final String title;
  final String message;
  final TextEditingController controller;
  final String actionLabel;
  final Future<void> Function() onAction;
  final Future<void> Function()? onBiometricAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'PIN',
                  prefixIcon: Icon(Icons.lock_outline_rounded),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onAction,
                  child: Text(actionLabel),
                ),
              ),
              if (onBiometricAction != null) ...[
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: onBiometricAction,
                  icon: const Icon(Icons.fingerprint_rounded),
                  label: const Text('Use biometrics'),
                ),
              ],
            ],
          ),
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
