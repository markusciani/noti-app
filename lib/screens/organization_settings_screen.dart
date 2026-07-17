import 'package:flutter/material.dart';

import '../models/organization.dart';
import '../services/organization_service.dart';
import '../theme/noti_theme.dart';
import '../widgets/adaptive_page_body.dart';

class OrganizationSettingsScreen extends StatelessWidget {
  const OrganizationSettingsScreen({super.key});

  Future<void> _addOrganization(BuildContext context) async {
    final nameController = TextEditingController();
    final idController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add organization'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Organization name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: idController,
              decoration: const InputDecoration(
                labelText: 'Organization ID',
                hintText: 'letters, numbers, and hyphens',
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
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (result != true) {
      nameController.dispose();
      idController.dispose();
      return;
    }
    final name = nameController.text.trim();
    final id = idController.text.trim().toLowerCase();
    nameController.dispose();
    idController.dispose();
    if (name.isEmpty || id.isEmpty || !RegExp(r'^[a-z0-9-]+$').hasMatch(id)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enter a valid name and organization ID.'),
          ),
        );
      }
      return;
    }
    try {
      await OrganizationService().saveOrganization(
        id: id,
        name: name,
        enabled: true,
        namingPolicy: DeviceNamingPolicy.deviceName,
        namingPrompt: DeviceNamingPolicy.deviceName.prompt,
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not add the organization.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = OrganizationService();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Organizations'),
        actions: [
          IconButton(
            tooltip: 'Add organization',
            onPressed: () => _addOrganization(context),
            icon: const Icon(Icons.add_business_rounded),
          ),
        ],
      ),
      body: StreamBuilder<List<Organization>>(
        stream: service.watchOrganizations(includeDisabled: true),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Could not load organizations: ${snapshot.error}'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return AdaptivePageBody(
            maxWidth: 760,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                Text(
                  'Organization settings',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Rename groups, choose how new devices identify themselves, and enable or pause membership. Pending devices are approved from Connected Devices.',
                ),
                const SizedBox(height: 20),
                ...snapshot.data!.map(
                  (organization) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _OrganizationEditor(organization: organization),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _OrganizationEditor extends StatefulWidget {
  const _OrganizationEditor({required this.organization});

  final Organization organization;

  @override
  State<_OrganizationEditor> createState() => _OrganizationEditorState();
}

class _OrganizationEditorState extends State<_OrganizationEditor> {
  late final TextEditingController _nameController;
  late final TextEditingController _promptController;
  late DeviceNamingPolicy _policy;
  late bool _enabled;
  late NotiThemePreset _themePreset;
  late NotiAppearance _appearance;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.organization.name);
    _promptController = TextEditingController(
      text: widget.organization.namingPrompt,
    );
    _policy = widget.organization.namingPolicy;
    _enabled = widget.organization.enabled;
    _themePreset = widget.organization.themePreset;
    _appearance = widget.organization.appearance;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await OrganizationService().saveOrganization(
        id: widget.organization.id,
        name: _nameController.text,
        enabled: _enabled,
        namingPolicy: _policy,
        namingPrompt: _promptController.text,
        themePreset: _themePreset,
        appearance: _appearance,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Organization settings saved.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save organization settings.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (widget.organization.id == Organization.defaultId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The default organization cannot be deleted.'),
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete organization?'),
        content: Text(
          'Delete ${widget.organization.name}? Existing device records will remain for review.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await OrganizationService().deleteOrganization(widget.organization.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete this organization.')),
        );
      }
    }
  }

  Future<void> _rotatePin() async {
    final options = await showDialog<_OrganizationPinOptions>(
      context: context,
      builder: (_) => const _OrganizationPinOptionsDialog(),
    );
    if (options == null) return;
    try {
      final pin = await OrganizationService().rotateOrganizationPin(
        organizationId: widget.organization.id,
        pin: options.pin,
        adminEmail: options.adminEmail,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            pin == null
                ? 'Organization PIN rotated'
                : 'Organization PIN created',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (pin != null) ...[
                const Text('Write this down. It will not be shown again.'),
                const SizedBox(height: 12),
                SelectableText(
                  pin,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    letterSpacing: 6,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ] else
                const Text(
                  'The PIN was generated and requested for email delivery. Only the founder can view the plaintext PIN in Noti.',
                ),
              if (options.adminEmail.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Email requested for ${options.adminEmail}.'),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('I wrote it down'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not create the organization PIN.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.organization.id,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Organization name'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<DeviceNamingPolicy>(
              initialValue: _policy,
              decoration: const InputDecoration(
                labelText: 'New device naming requirement',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              items: DeviceNamingPolicy.values
                  .map(
                    (policy) => DropdownMenuItem(
                      value: policy,
                      child: Text(policy.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _policy = value;
                    if (_promptController.text.trim().isEmpty) {
                      _promptController.text = value.prompt;
                    }
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _promptController,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Prompt shown to members',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<NotiThemePreset>(
              initialValue: _themePreset,
              decoration: const InputDecoration(
                labelText: 'Organization theme color',
                prefixIcon: Icon(Icons.palette_outlined),
              ),
              items: NotiThemePreset.values
                  .map(
                    (preset) => DropdownMenuItem(
                      value: preset,
                      child: Text(preset.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _themePreset = value);
              },
            ),
            const SizedBox(height: 4),
            SegmentedButton<NotiAppearance>(
              segments: NotiAppearance.values
                  .map(
                    (appearance) => ButtonSegment(
                      value: appearance,
                      label: Text(appearance.label),
                      icon: Icon(
                        appearance == NotiAppearance.dark
                            ? Icons.dark_mode_outlined
                            : Icons.light_mode_outlined,
                      ),
                    ),
                  )
                  .toList(),
              selected: {_appearance},
              onSelectionChanged: (value) {
                setState(() => _appearance = value.first);
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Allow new members to join'),
              value: _enabled,
              onChanged: (value) => setState(() => _enabled = value),
            ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_rounded),
                  label: const Text('Save'),
                ),
                if (widget.organization.id != Organization.defaultId)
                  OutlinedButton.icon(
                    onPressed: _delete,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Delete'),
                  ),
                OutlinedButton.icon(
                  onPressed: _rotatePin,
                  icon: const Icon(Icons.password_rounded),
                  label: const Text('New 6-digit PIN'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OrganizationPinOptions {
  const _OrganizationPinOptions({required this.pin, required this.adminEmail});

  final String pin;
  final String adminEmail;
}

class _OrganizationPinOptionsDialog extends StatefulWidget {
  const _OrganizationPinOptionsDialog();

  @override
  State<_OrganizationPinOptionsDialog> createState() =>
      _OrganizationPinOptionsDialogState();
}

class _OrganizationPinOptionsDialogState
    extends State<_OrganizationPinOptionsDialog> {
  final _pinController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _pinController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _submit() {
    final pin = _pinController.text.trim();
    if (pin.isNotEmpty && !RegExp(r'^\d{6}$').hasMatch(pin)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Use exactly six digits or leave it blank for a random PIN.',
          ),
        ),
      );
      return;
    }
    Navigator.of(context).pop(
      _OrganizationPinOptions(
        pin: pin,
        adminEmail: _emailController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set organization PIN'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _pinController,
            maxLength: 6,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Exact PIN (founder only)',
              hintText: 'Leave blank to randomize',
            ),
          ),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email PIN to admin (optional for founder)',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Create PIN')),
      ],
    );
  }
}
