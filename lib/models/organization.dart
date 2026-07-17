import 'package:cloud_firestore/cloud_firestore.dart';

import '../theme/noti_theme.dart';

enum DeviceNamingPolicy {
  deviceName,
  firstName,
  firstAndLastName,
  deviceNumber,
  custom;

  String get storageValue => name;

  String get label => switch (this) {
    DeviceNamingPolicy.deviceName => 'Device name',
    DeviceNamingPolicy.firstName => 'First name',
    DeviceNamingPolicy.firstAndLastName => 'First and last name',
    DeviceNamingPolicy.deviceNumber => 'Device number',
    DeviceNamingPolicy.custom => 'Custom device name',
  };

  String get prompt => switch (this) {
    DeviceNamingPolicy.deviceName => 'Use the device name',
    DeviceNamingPolicy.firstName => 'Enter your first name',
    DeviceNamingPolicy.firstAndLastName => 'Enter your first and last name',
    DeviceNamingPolicy.deviceNumber => 'Enter the device number',
    DeviceNamingPolicy.custom => 'Enter a name for this device',
  };

  static DeviceNamingPolicy fromStorage(String? value) => values.firstWhere(
    (item) => item.storageValue == value,
    orElse: () => DeviceNamingPolicy.deviceName,
  );
}

class Organization {
  const Organization({
    required this.id,
    required this.name,
    required this.enabled,
    required this.namingPolicy,
    required this.namingPrompt,
    this.themePreset = NotiThemePreset.main,
    this.appearance = NotiAppearance.light,
  });

  static const defaultId = 'maranatha-romanian-church';
  static const defaultName = 'Maranatha Church';

  final String id;
  final String name;
  final bool enabled;
  final DeviceNamingPolicy namingPolicy;
  final String namingPrompt;
  final NotiThemePreset themePreset;
  final NotiAppearance appearance;

  static const fallback = Organization(
    id: defaultId,
    name: defaultName,
    enabled: true,
    namingPolicy: DeviceNamingPolicy.deviceName,
    namingPrompt: 'Choose how this device should be identified',
    themePreset: NotiThemePreset.main,
    appearance: NotiAppearance.light,
  );

  factory Organization.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    final policy = DeviceNamingPolicy.fromStorage(
      data['deviceNamingPolicy'] as String?,
    );
    return Organization(
      id: snapshot.id,
      name: data['name'] as String? ?? snapshot.id,
      enabled: data['enabled'] as bool? ?? true,
      namingPolicy: policy,
      namingPrompt: data['deviceNamingPrompt'] as String? ?? policy.prompt,
      themePreset: NotiThemePreset.fromStorage(data['themePreset'] as String?),
      appearance: NotiAppearance.fromStorage(data['appearanceMode'] as String?),
    );
  }
}
