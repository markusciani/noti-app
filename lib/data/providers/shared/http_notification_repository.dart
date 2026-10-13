import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/backend/interfaces/notification_repository.dart';
import '../../../models/announcement.dart';
import 'announcement_mapper.dart';

typedef TokenProvider = Future<String?> Function();

enum HttpNotificationMode { genericApi, supabaseEdge, convexHttp }

class HttpNotificationRepository implements NotificationRepository {
  HttpNotificationRepository({
    required String baseUrl,
    required TokenProvider tokenProvider,
    required Map<String, String> staticHeaders,
    this.mode = HttpNotificationMode.genericApi,
    http.Client? client,
    Duration? pollingInterval,
  }) : _baseUrl = baseUrl,
       _tokenProvider = tokenProvider,
       _staticHeaders = staticHeaders,
       _client = client ?? http.Client(),
       _pollingInterval = pollingInterval ?? const Duration(seconds: 8);

  final String _baseUrl;
  final TokenProvider _tokenProvider;
  final Map<String, String> _staticHeaders;
  final HttpNotificationMode mode;
  final http.Client _client;
  final Duration _pollingInterval;

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$_baseUrl$path').replace(queryParameters: query);

  Future<Map<String, String>> _headers() async {
    final token = await _tokenProvider();
    return {
      'Content-Type': 'application/json',
      ..._staticHeaders,
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer ' + token,
    };
  }

  Future<List<Announcement>> _fetchAnnouncements({String? organizationId}) async {
    if (_baseUrl.trim().isEmpty) {
      return const <Announcement>[];
    }

    final query = <String, String>{
      if (organizationId != null && organizationId.trim().isNotEmpty)
        'organizationId': organizationId.trim(),
    };

    final response = await _client.get(
      _uri('/announcements', query),
      headers: await _headers(),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Failed to fetch announcements: HTTP ${response.statusCode}');
    }

    final payload = jsonDecode(response.body);
    final records = switch (payload) {
      final List<dynamic> items => items,
      final Map<String, dynamic> map when map['announcements'] is List<dynamic> =>
        map['announcements'] as List<dynamic>,
      _ => const <dynamic>[],
    };

    final announcements = records.whereType<Map>().map((entry) {
      final map = Map<String, dynamic>.from(entry);
      final id = map.remove('id')?.toString() ??
          map.remove('announcementId')?.toString() ??
          '';
      return announcementFromMap(id, map);
    }).toList(growable: false);

    announcements.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return announcements;
  }

  @override
  Stream<List<Announcement>> watchAnnouncements({String? organizationId}) async* {
    if (_baseUrl.trim().isEmpty) {
      yield const <Announcement>[];
      return;
    }

    yield await _fetchAnnouncements(organizationId: organizationId);

    yield* Stream<List<Announcement>>.periodic(_pollingInterval)
        .asyncMap((_) => _fetchAnnouncements(organizationId: organizationId));
  }

  @override
  Future<void> createAnnouncement({
    required String title,
    required String message,
    required String author,
    required bool pinned,
    String? organizationId,
  }) async {
    await _write(
      method: 'POST',
      path: '/announcements',
      body: {
        'title': title,
        'message': message,
        'author': author,
        'pinned': pinned,
        if (organizationId != null && organizationId.isNotEmpty)
          'organizationId': organizationId,
      },
    );
  }

  @override
  Future<void> updateAnnouncement({
    required String id,
    required String title,
    required String message,
    required String author,
    required bool pinned,
    String? organizationId,
  }) async {
    await _write(
      method: 'PATCH',
      path: '/announcements/$id',
      body: {
        'title': title,
        'message': message,
        'author': author,
        'pinned': pinned,
        if (organizationId != null && organizationId.isNotEmpty)
          'organizationId': organizationId,
      },
    );
  }

  @override
  Future<void> deleteAnnouncement(String id, {String? organizationId}) async {
    await _write(
      method: 'DELETE',
      path: '/announcements/$id',
      body: {
        if (organizationId != null && organizationId.isNotEmpty)
          'organizationId': organizationId,
      },
    );
  }

  Future<void> _write({
    required String method,
    required String path,
    required Map<String, dynamic> body,
  }) async {
    if (_baseUrl.trim().isEmpty) {
      throw StateError('Backend API base URL is not configured.');
    }

    final request = http.Request(method, _uri(path));
    request.headers.addAll(await _headers());
    request.body = jsonEncode(body);

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Announcement request failed: HTTP ${response.statusCode}');
    }
  }
}
