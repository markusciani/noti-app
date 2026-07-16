import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/app_settings_service.dart';
import '../services/auth_service.dart';
import '../theme/noti_theme.dart';
import '../widgets/adaptive_page_body.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final _settingsService = AppSettingsService();
  final _authService = AuthService();
  final _versionController = TextEditingController();

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;
  String _themePreset = NotiThemePreset.main.storageValue;
  String _appearanceMode = NotiAppearance.light.storageValue;
  bool _deviceRegistrationEnabled = true;
  bool _hasPin = false;
  bool _loaded = false;
  bool _saving = false;
  String? _settingsLoadError;

  @override
  void initState() {
    super.initState();
    _loadPinState();
    _subscription = _settingsService.watchSettings().listen(
      _loadSettings,
      onError: (_) {
        if (mounted) {
          setState(() {
            _loaded = true;
            _settingsLoadError =
                'Settings could not be loaded. You can try again when your connection returns.';
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _versionController.dispose();
    super.dispose();
  }

  Future<void> _loadPinState() async {
    try {
      final hasPin = await _authService.hasPin();
      if (mounted) setState(() => _hasPin = hasPin);
    } catch (_) {
      _showMessage('Could not load PIN status. Please try again.');
    }
  }

  void _loadSettings(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    if (!mounted || _loaded) return;
    final data = snapshot.data() ?? const <String, dynamic>{};
    setState(() {
      _versionController.text =
          data['minimumSupportedVersion'] as String? ?? '';
      _deviceRegistrationEnabled =
          data['deviceRegistrationEnabled'] as bool? ?? true;
      _themePreset = NotiThemePreset.fromStorage(
        data['themePreset'] as String?,
      ).storageValue;
      _appearanceMode = NotiAppearance.fromStorage(
        data['appearanceMode'] as String?,
      ).storageValue;
      _loaded = true;
      _settingsLoadError = null;
    });
  }

  Future<void> _saveSettings() async {
    if (!_hasPin) {
      _showMessage('Set an admin PIN before saving global settings.');
      return;
    }
    if (!await _confirmPin()) return;

    setState(() => _saving = true);
    try {
      await _settingsService.saveSettings(
        minimumSupportedVersion: _versionController.text.trim(),
        deviceRegistrationEnabled: _deviceRegistrationEnabled,
        themePreset: _themePreset,
        appearanceMode: _appearanceMode,
      );
      _showMessage('Settings saved for all connected devices.');
    } catch (_) {
      _showMessage('Could not save settings. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirmPin() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _PinVerificationDialog(onVerify: _authService.verifyPin),
    );
    if (result != true) _showMessage('Incorrect PIN.');
    return result == true;
  }

  Future<void> _showPinEditor() async {
    if (_hasPin && !await _confirmPin()) return;
    if (!mounted) return;

    final result = await showDialog<String>(
      context: context,
      builder: (_) => _PinEditorDialog(hasExistingPin: _hasPin),
    );
    if (result == null) return;

    try {
      await _authService.setPin(result);
      if (mounted) setState(() => _hasPin = true);
      _showMessage('Admin PIN saved.');
    } catch (_) {
      _showMessage('Could not save the PIN. Please try again.');
    }
  }

  Future<void> _resetPin() async {
    final password = await showDialog<String>(
      context: context,
      builder: (_) => const _PasswordConfirmationDialog(),
    );
    if (password == null) return;

    try {
      await _authService.reauthenticateWithPassword(password);
      await _authService.clearPin();
      if (mounted) setState(() => _hasPin = false);
      await _showPinEditor();
    } catch (_) {
      _showMessage('Could not reset the PIN. Please try again.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final preset = NotiThemePreset.fromStorage(_themePreset);
    final appearance = NotiAppearance.fromStorage(_appearanceMode);
    final palette = NotiPalette.forPreset(preset, appearance: appearance);
    final userEmail = _authService.currentUser?.email ?? 'Signed-in admin';

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: AdaptivePageBody(
        maxWidth: 680,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            if (_settingsLoadError != null) ...[
              Card(
                child: ListTile(
                  leading: const Icon(Icons.cloud_off_rounded),
                  title: const Text('Settings unavailable'),
                  subtitle: Text(_settingsLoadError!),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(userEmail, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Appearance',
              child: Column(
                children: [
                  SegmentedButton<String>(
                    segments: NotiThemePreset.values
                        .map(
                          (item) => ButtonSegment(
                            value: item.storageValue,
                            label: Text(item.label.replaceFirst(' Theme', '')),
                          ),
                        )
                        .toList(),
                    selected: {_themePreset},
                    onSelectionChanged: (value) {
                      setState(() => _themePreset = value.first);
                    },
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Dark appearance'),
                    subtitle: const Text(
                      'Changes the app colors, not the icon.',
                    ),
                    value: appearance == NotiAppearance.dark,
                    onChanged: (isDark) {
                      setState(() {
                        _appearanceMode = isDark
                            ? NotiAppearance.dark.storageValue
                            : NotiAppearance.light.storageValue;
                      });
                    },
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: palette.outline.withValues(alpha: .45),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: palette.primary,
                          foregroundColor: palette.onPrimary,
                          child: const Icon(Icons.notifications_rounded),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${preset.label} ${appearance.label.toLowerCase()}',
                            style: TextStyle(
                              color: palette.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Devices',
              child: Column(
                children: [
                  TextField(
                    controller: _versionController,
                    decoration: const InputDecoration(
                      labelText: 'Minimum app version',
                      hintText: 'Leave empty to allow every version',
                    ),
                  ),
                  const SizedBox(height: 4),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Allow new devices'),
                    subtitle: const Text(
                      'Turn off to pause new registrations.',
                    ),
                    value: _deviceRegistrationEnabled,
                    onChanged: (value) {
                      setState(() => _deviceRegistrationEnabled = value);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Security',
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.pin_rounded),
                    title: Text(
                      _hasPin ? 'Admin PIN is set' : 'Admin PIN is not set',
                    ),
                    subtitle: Text(
                      _hasPin
                          ? 'Required before global changes are saved.'
                          : 'Set a PIN to protect global changes.',
                    ),
                    trailing: TextButton(
                      onPressed: _showPinEditor,
                      child: Text(_hasPin ? 'Change' : 'Set'),
                    ),
                  ),
                  if (_hasPin)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _resetPin,
                        child: const Text('Forgot PIN? Reset it securely'),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : _saveSettings,
              icon: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded),
              label: const Text('Save changes'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _PinVerificationDialog extends StatefulWidget {
  const _PinVerificationDialog({required this.onVerify});

  final Future<bool> Function(String pin) onVerify;

  @override
  State<_PinVerificationDialog> createState() => _PinVerificationDialogState();
}

class _PinVerificationDialogState extends State<_PinVerificationDialog> {
  final _controller = TextEditingController();
  bool _checking = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final matches = await widget.onVerify(_controller.text.trim());
      if (!mounted) return;
      if (matches) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _error = 'Incorrect PIN.');
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not verify the PIN.');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm PIN'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        obscureText: true,
        onSubmitted: (_) => _checking ? null : _confirm(),
        decoration: InputDecoration(labelText: 'Admin PIN', errorText: _error),
      ),
      actions: [
        TextButton(
          onPressed: _checking ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _checking ? null : _confirm,
          child: _checking
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Continue'),
        ),
      ],
    );
  }
}

class _PinEditorDialog extends StatefulWidget {
  const _PinEditorDialog({required this.hasExistingPin});

  final bool hasExistingPin;

  @override
  State<_PinEditorDialog> createState() => _PinEditorDialogState();
}

class _PinEditorDialogState extends State<_PinEditorDialog> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _save() {
    final pin = _pinController.text.trim();
    if (pin.length < 4) {
      setState(() => _error = 'Use at least 4 digits.');
      return;
    }
    if (pin != _confirmController.text.trim()) {
      setState(() => _error = 'The PINs do not match.');
      return;
    }
    Navigator.of(context).pop(pin);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.hasExistingPin ? 'Change admin PIN' : 'Set admin PIN'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _pinController,
            autofocus: true,
            keyboardType: TextInputType.number,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'New PIN'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmController,
            keyboardType: TextInputType.number,
            obscureText: true,
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: 'Confirm PIN',
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save PIN')),
      ],
    );
  }
}

class _PasswordConfirmationDialog extends StatefulWidget {
  const _PasswordConfirmationDialog();

  @override
  State<_PasswordConfirmationDialog> createState() =>
      _PasswordConfirmationDialogState();
}

class _PasswordConfirmationDialogState
    extends State<_PasswordConfirmationDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reset admin PIN'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Enter your account password, then choose a new PIN.'),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            obscureText: true,
            onSubmitted: (value) => Navigator.of(context).pop(value),
            decoration: const InputDecoration(labelText: 'Password'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
