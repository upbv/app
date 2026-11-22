import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';

/// Thrown when the backend cannot be reached or answers with an error.
class ApiException implements Exception {
  ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// REST client for the dashboard backend.
///
/// The base URL is overridable at build time:
///   flutter run --dart-define=DASH_API=http://192.168.1.10:9747
class ApiClient {
  ApiClient({String? baseUrl, http.Client? client})
      : baseUrl = baseUrl ?? defaultBaseUrl,
        _client = client ?? http.Client();

  static const defaultBaseUrl = String.fromEnvironment(
    'DASH_API',
    defaultValue: 'http://127.0.0.1:9747',
  );

  final String baseUrl;
  final http.Client _client;

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = Uri.parse(baseUrl);
    return base.replace(
      path: path,
      queryParameters: (query == null || query.isEmpty) ? null : query,
    );
  }

  Future<dynamic> _get(String path, [Map<String, String>? query]) async {
    final res = await _client
        .get(_uri(path, query))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw ApiException('GET $path failed (${res.statusCode})');
    }
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  Future<Metrics> currentMetrics() async {
    final data = await _get('/api/metrics/current');
    return Metrics.fromJson(data as Map<String, dynamic>);
  }

  Future<HostInfo> hostInfo() async {
    final data = await _get('/api/host');
    return HostInfo.fromJson(data as Map<String, dynamic>);
  }

  Future<List<Volume>> volumes() async {
    final data = await _get('/api/volumes') as List<dynamic>;
    return data.map((e) => Volume.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Service>> services() async {
    final data = await _get('/api/services') as List<dynamic>;
    return data.map((e) => Service.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Disk>> disks() async {
    final data = await _get('/api/disks') as List<dynamic>;
    return data.map((e) => Disk.fromJson(e as Map<String, dynamic>).copyWith())
        .toList();
  }

  Future<Sensors> sensors() async {
    final data = await _get('/api/sensors');
    return Sensors.fromJson(data as Map<String, dynamic>);
  }

  Future<String> serviceAction(String id, String action) async {
    final res = await _client
        .post(
          _uri('/api/services'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'id': id, 'action': action}),
        )
        .timeout(const Duration(seconds: 30));
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw ApiException(body['error'] as String? ?? 'action failed');
    }
    return body['output'] as String? ?? '';
  }

  Future<bool> ping() async {
    try {
      await _get('/api/health');
      return true;
    } catch (_) {
      return false;
    }
  }

  void dispose() => _client.close();
}

extension on Disk {
  Disk copyWith() => this;
}
