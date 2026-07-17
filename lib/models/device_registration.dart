class DeviceRegistration {
  const DeviceRegistration({
    required this.organizationId,
    required this.organizationName,
    required this.deviceType,
    required this.displayName,
  });

  final String organizationId;
  final String organizationName;
  final String deviceType;
  final String displayName;
}
