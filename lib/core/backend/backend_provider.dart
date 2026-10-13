enum BackendProvider {
  firebase,
  supabase,
  convex,
  postgresApi,
  mysqlApi,
  mongoApi,
  customApi;

  static BackendProvider fromValue(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    return switch (normalized) {
      '' || 'firebase' || 'firestore' => BackendProvider.firebase,
      'supabase' || 'postgres' || 'postgresql' => BackendProvider.supabase,
      'convex' => BackendProvider.convex,
      'postgres_api' || 'postgres-api' => BackendProvider.postgresApi,
      'mysql_api' || 'mysql-api' => BackendProvider.mysqlApi,
      'mongodb_api' || 'mongodb-api' || 'mongo_api' || 'mongo-api' =>
        BackendProvider.mongoApi,
      'custom_api' || 'custom-api' || 'rest' || 'rest_api' || 'rest-api' =>
        BackendProvider.customApi,
      _ => BackendProvider.firebase,
    };
  }
}
