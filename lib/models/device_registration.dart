class DeviceRegistration {
  const DeviceRegistration({
    required this.organizationId,
    required this.organizationName,
    required this.deviceType,
    required this.displayName,
    this.firstName = '',
    this.lastName = '',
    this.deviceNumber = '',
    this.staffAccessRequested = false,
  });

  final String organizationId;
  final String organizationName;
  final String deviceType;
  final String displayName;
  final String firstName;
  final String lastName;
  final String deviceNumber;
  final bool staffAccessRequested;
}
