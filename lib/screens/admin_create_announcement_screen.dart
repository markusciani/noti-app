import 'package:flutter/material.dart';

import '../models/announcement.dart';
import '../services/firestore_service.dart';
import '../widgets/adaptive_page_body.dart';

class AdminCreateAnnouncementScreen extends StatefulWidget {
  const AdminCreateAnnouncementScreen({super.key, this.announcement});

  final Announcement? announcement;

  @override
  State<AdminCreateAnnouncementScreen> createState() =>
      _AdminCreateAnnouncementScreenState();
}

class _AdminCreateAnnouncementScreenState
    extends State<AdminCreateAnnouncementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _authorController = TextEditingController(text: 'Admin');
  final _firestoreService = FirestoreService();

  bool _pinned = false;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.announcement != null;

  @override
  void initState() {
    super.initState();
    final announcement = widget.announcement;
    if (announcement != null) {
      _titleController.text = announcement.title;
      _messageController.text = announcement.message;
      _authorController.text = announcement.author.isEmpty
          ? 'Admin'
          : announcement.author;
      _pinned = announcement.pinned;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  Future<bool> _confirmPublish() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(_isEditing ? 'Save changes?' : 'Publish announcement?'),
          content: Text(
            _isEditing
                ? 'This will update the announcement for every device.'
                : 'This will publish the announcement to every device and prepare it for push delivery.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(_isEditing ? 'Save' : 'Publish'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  Future<void> _publish() async {
    if (!_formKey.currentState!.validate()) return;
    final confirmed = await _confirmPublish();
    if (!confirmed) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      if (_isEditing) {
        await _firestoreService.updateAnnouncement(
          id: widget.announcement!.id,
          title: _titleController.text.trim(),
          message: _messageController.text.trim(),
          author: _authorController.text.trim(),
          pinned: _pinned,
        );
      } else {
        await _firestoreService.addAnnouncement(
          title: _titleController.text.trim(),
          message: _messageController.text.trim(),
          author: _authorController.text.trim(),
          pinned: _pinned,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing ? 'Announcement updated' : 'Announcement published',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final previewTitle = _titleController.text.trim().isEmpty
        ? 'Preview title'
        : _titleController.text.trim();
    final previewMessage = _messageController.text.trim().isEmpty
        ? 'Preview text will appear here as the admin types.'
        : _messageController.text.trim();
    final previewAuthor = _authorController.text.trim().isEmpty
        ? 'Admin'
        : _authorController.text.trim();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Announcement' : 'Create Announcement'),
      ),
      body: AdaptivePageBody(
        maxWidth: 760,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              _isEditing ? 'Edit announcement' : 'Create announcement',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Write the message, preview it, then publish after confirming.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Live preview',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: colors.primary.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: colors.primaryContainer,
                                foregroundColor: colors.primary,
                                child: Icon(
                                  _pinned
                                      ? Icons.push_pin_rounded
                                      : Icons.campaign_rounded,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  previewTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            previewMessage,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: colors.onSurfaceVariant,
                                  height: 1.45,
                                ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Text(
                                previewAuthor,
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const Spacer(),
                              if (_pinned)
                                Chip(
                                  label: const Text('Pinned'),
                                  backgroundColor: colors.primaryContainer,
                                  labelStyle: TextStyle(
                                    color: colors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  side: BorderSide.none,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Title'),
                    onChanged: (_) => setState(() {}),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter a title'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _messageController,
                    minLines: 5,
                    maxLines: 10,
                    decoration: const InputDecoration(labelText: 'Message'),
                    onChanged: (_) => setState(() {}),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter a message'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _authorController,
                    decoration: const InputDecoration(labelText: 'Author'),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Pinned'),
                    subtitle: const Text('Keep this announcement at the top.'),
                    value: _pinned,
                    onChanged: (value) => setState(() => _pinned = value),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: colors.error)),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saving ? null : _publish,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_isEditing ? 'Save changes' : 'Publish'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
