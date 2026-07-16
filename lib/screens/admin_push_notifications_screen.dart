import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/push_notification_service.dart';
import '../widgets/adaptive_page_body.dart';

class AdminPushNotificationsScreen extends StatefulWidget {
  const AdminPushNotificationsScreen({super.key});

  @override
  State<AdminPushNotificationsScreen> createState() =>
      _AdminPushNotificationsScreenState();
}

class _AdminPushNotificationsScreenState
    extends State<AdminPushNotificationsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController(text: 'Noti test alert');
  final _messageController = TextEditingController(
    text: 'This is a test notification from Noti Admin.',
  );
  final _authService = AuthService();
  final _pushService = PushNotificationService();
  bool _sending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<bool> _confirmPin() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _PinConfirmationDialog(onVerify: _authService.verifyPin),
    );
    return result == true;
  }

  Future<void> _sendBroadcast() async {
    if (!_formKey.currentState!.validate()) return;
    if (!await _confirmPin()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Broadcast cancelled or PIN incorrect.'),
          ),
        );
      }
      return;
    }

    setState(() => _sending = true);
    try {
      await _pushService.sendTestBroadcast(
        title: _titleController.text.trim(),
        message: _messageController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test notification sent to all devices.')),
      );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? 'Could not send notification.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send notification.')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Push Notifications')),
      body: SafeArea(
        child: AdaptivePageBody(
          maxWidth: 680,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          child: Icon(
                            Icons.notifications_active_rounded,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Send a test broadcast to every device subscribed to Noti announcements.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _titleController,
                  maxLength: 80,
                  decoration: const InputDecoration(
                    labelText: 'Notification title',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a title'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _messageController,
                  maxLength: 240,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Notification message',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a message'
                      : null,
                ),
                const SizedBox(height: 8),
                Text(
                  'A PIN is required before this is sent. Tapping the notification keeps members on the Noti home feed.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _sending ? null : _sendBroadcast,
                  icon: _sending
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: const Text('Send test broadcast'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PinConfirmationDialog extends StatefulWidget {
  const _PinConfirmationDialog({required this.onVerify});

  final Future<bool> Function(String pin) onVerify;

  @override
  State<_PinConfirmationDialog> createState() => _PinConfirmationDialogState();
}

class _PinConfirmationDialogState extends State<_PinConfirmationDialog> {
  final _controller = TextEditingController();
  bool _verifying = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final pin = _controller.text.trim();
    if (pin.isEmpty) {
      setState(() => _error = 'Enter your admin PIN.');
      return;
    }

    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      final valid = await widget.onVerify(pin);
      if (!mounted) return;
      if (valid) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _error = 'Incorrect PIN. Please try again.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not verify the PIN. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm broadcast'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        obscureText: true,
        keyboardType: TextInputType.number,
        onSubmitted: (_) => _verifying ? null : _verify(),
        decoration: InputDecoration(labelText: 'Admin PIN', errorText: _error),
      ),
      actions: [
        TextButton(
          onPressed: _verifying ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _verifying ? null : _verify,
          child: _verifying
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send'),
        ),
      ],
    );
  }
}
