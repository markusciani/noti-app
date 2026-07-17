import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/app_settings_service.dart';
import '../theme/noti_theme.dart';
import '../widgets/adaptive_page_body.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final _settingsService = AppSettingsService();
  final _versionController = TextEditingController();

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;
  String _themePreset = NotiThemePreset.main.storageValue;
  String _appearanceMode = NotiAppearance.light.storageValue;
  bool _deviceRegistrationEnabled = true;
  bool _loaded = false;
  bool _saving = false;
  String? _settingsLoadError;

  @override
  void initState() {
    super.initState();
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
