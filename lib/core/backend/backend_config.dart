import 'backend_provider.dart';

class BackendConfig {
  const BackendConfig._();

  static BackendProvider get provider =>
      BackendProvider.fromValue(const String.fromEnvironment('NOTI_BACKEND_PROVIDER'));

  static String get apiBaseUrl =>
      const String.fromEnvironment('NOTI_BACKEND_API_BASE_URL');

  static String get supabaseUrl =>
      const String.fromEnvironment('NOTI_SUPABASE_URL');

  static String get supabaseAnonKey =>
      const String.fromEnvironment('NOTI_SUPABASE_ANON_KEY');

  static String get convexUrl =>
      const String.fromEnvironment('NOTI_CONVEX_URL');

  static String get customApiUrl =>
      const String.fromEnvironment('NOTI_CUSTOM_API_URL');

  static String get notificationTransport =>
      const String.fromEnvironment('NOTI_NOTIFICATION_TRANSPORT', defaultValue: 'fcm');
}
