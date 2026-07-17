import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../models/custom_notification_delivery.dart';
import '../services/push_notification_service.dart';
import '../widgets/adaptive_page_body.dart';

class AdminPushNotificationsScreen extends StatefulWidget {
  const AdminPushNotificationsScreen({super.key, this.organizationId});

  final String? organizationId;

  @override
  State<AdminPushNotificationsScreen> createState() =>
      _AdminPushNotificationsScreenState();
}

class _AdminPushNotificationsScreenState
    extends State<AdminPushNotificationsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _pushService = PushNotificationService();
  Timer? _clock;
  bool _sending = false;
  CustomNotificationDelivery? _editing;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendOrSave() async {
    if (!_formKey.currentState!.validate()) return;
    final isEditing = _editing != null;
    if (!mounted) return;
    setState(() => _sending = true);
    try {
      if (isEditing) {
        await _pushService.updateBroadcast(
          notificationId: _editing!.id,
          title: _titleController.text.trim(),
          message: _messageController.text.trim(),
          organizationId: widget.organizationId,
        );
      } else {
        await _pushService.createBroadcast(
          title: _titleController.text.trim(),
          message: _messageController.text.trim(),
          organizationId: widget.organizationId,
        );
      }
      if (!mounted) return;
      setState(() {
        _editing = null;
        _titleController.clear();
        _messageController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing
                ? 'Corrected broadcast sent to every tablet.'
                : 'Broadcast sent to every tablet.',
          ),
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      _showError(error.message ?? 'Could not send this broadcast.');
    } on Object catch (_) {
      _showError(
        'Could not send this broadcast. Check your connection and try again.',
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _deleteBroadcast(CustomNotificationDelivery delivery) async {
    if (!mounted) return;
    try {
      await _pushService.withdrawBroadcast(
        delivery.id,
        organizationId: widget.organizationId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Notification deleted.')));
    } on FirebaseFunctionsException catch (error) {
      _showError(error.message ?? 'Could not delete this broadcast.');
    } on Object catch (_) {
      _showError('Could not delete this broadcast.');
    }
  }

  void _beginEditing(CustomNotificationDelivery delivery) {
    setState(() {
      _editing = delivery;
      _titleController.text = delivery.title;
      _messageController.text = delivery.message;
    });
  }

  void _cancelEditing() {
    setState(() {
      _editing = null;
      _titleController.clear();
      _messageController.clear();
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isEditing = _editing != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Push notifications')),
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
                          backgroundColor: colors.primaryContainer,
                          foregroundColor: colors.primary,
                          child: const Icon(Icons.notifications_active_rounded),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            isEditing
                                ? 'Correct this broadcast before the five-minute window ends.'
                                : 'Send a custom broadcast to every tablet subscribed to Noti.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  isEditing ? 'Edit broadcast' : 'New broadcast',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
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
                  'For five minutes, this screen can edit or delete your broadcast. Devices already offline may still show the original system alert until they reconnect.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _sending ? null : _sendOrSave,
                  icon: _sending
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          isEditing ? Icons.save_rounded : Icons.send_rounded,
                        ),
                  label: Text(isEditing ? 'Save correction' : 'Send broadcast'),
                ),
                if (isEditing)
                  TextButton(
                    onPressed: _cancelEditing,
                    child: const Text('Cancel editing'),
                  ),
                const SizedBox(height: 28),
                Text(
                  'Recent broadcasts',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                StreamBuilder<List<CustomNotificationDelivery>>(
                  stream: _pushService.watchMyBroadcasts(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const _BroadcastInfo(
                        'Recent broadcasts are unavailable right now.',
                      );
                    }
                    final deliveries =
                        snapshot.data ?? const <CustomNotificationDelivery>[];
                    if (deliveries.isEmpty) {
                      return const _BroadcastInfo(
                        'No custom broadcasts have been sent from this account yet.',
                      );
                    }
                    return Column(
                      children: [
                        for (final delivery in deliveries) ...[
                          _BroadcastCard(
                            delivery: delivery,
                            onEdit: delivery.canCorrect
                                ? () => _beginEditing(delivery)
                                : null,
                            onDelete: delivery.canCorrect
                                ? () => _deleteBroadcast(delivery)
                                : null,
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BroadcastCard extends StatelessWidget {
  const _BroadcastCard({
    required this.delivery,
    required this.onEdit,
    required this.onDelete,
  });

  final CustomNotificationDelivery delivery;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final end = delivery.correctionWindowEndsAt;
    final secondsLeft = end == null
        ? 0
        : end.difference(DateTime.now()).inSeconds.clamp(0, 300);
    final label = delivery.canCorrect
        ? 'Corrections available for ${secondsLeft ~/ 60}:${(secondsLeft % 60).toString().padLeft(2, '0')}'
        : delivery.isActive
        ? 'Correction window closed'
        : 'Deleted';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              delivery.title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              delivery.message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            if (onEdit != null || onDelete != null) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('Edit'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Delete notification'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BroadcastInfo extends StatelessWidget {
  const _BroadcastInfo(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(16), child: Text(message)),
    );
  }
}
