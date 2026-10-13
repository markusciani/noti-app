import 'package:flutter_test/flutter_test.dart';
import 'package:noti/core/backend/backend_provider.dart';

void main() {
  test('backend provider parsing falls back to firebase', () {
    expect(BackendProvider.fromValue(null), BackendProvider.firebase);
    expect(BackendProvider.fromValue(''), BackendProvider.firebase);
    expect(BackendProvider.fromValue('unknown'), BackendProvider.firebase);
  });

  test('backend provider parsing supports aliases', () {
    expect(BackendProvider.fromValue('firestore'), BackendProvider.firebase);
    expect(BackendProvider.fromValue('supabase'), BackendProvider.supabase);
    expect(BackendProvider.fromValue('postgresql'), BackendProvider.supabase);
    expect(BackendProvider.fromValue('convex'), BackendProvider.convex);
    expect(BackendProvider.fromValue('postgres_api'), BackendProvider.postgresApi);
    expect(BackendProvider.fromValue('mysql-api'), BackendProvider.mysqlApi);
    expect(BackendProvider.fromValue('mongo-api'), BackendProvider.mongoApi);
    expect(BackendProvider.fromValue('custom_api'), BackendProvider.customApi);
  });
}
