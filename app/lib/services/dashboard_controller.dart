import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../services/live_stream.dart';

/// Central store for everything the dashboard shows.
///
/// The controller owns the REST polling and the websocket subscription, and
/// exposes immutable snapshots to the widget tree.
class DashboardController extends ChangeNotifier {
  DashboardController({ApiClient? api, String? baseUrl})
      : api = api ?? ApiClient(baseUrl: baseUrl);

  final ApiClient api;

  // Connection
  bool _online = false;
  bool get online => _online;

  String _apiBaseUrl = ApiClient.defaultBaseUrl;
  String get apiBaseUrl => _apiBaseUrl;

  // Latest snapshots
  Metrics? _metrics;
  HostInfo? _host;
  List<Volume> _volumes = const [];
  List<Service> _services = const [];
  List<Disk> _disks = const [];
  Sensors _sensors = const Sensors(temperatures: [], fans: []);

  Metrics? get metrics => _metrics;
  HostInfo? get host => _host;
  List<Volume> get volumes => _volumes;
  List<Service> get services => _services;
  List<Disk> get disks => _disks;
  Sensors get sensors => _sensors;

  // Rolling history for the charts
  final List<Metrics> _history = <Metrics>[];
  List<Metrics> get history => List.unmodifiable(_history);

  static const int _historyLimit = 90;

  String? _error;
  String? get error => _error;

  bool _busy = false;
  bool get busy => _busy;

  LiveStream? _stream;
  Timer? _pollTimer;

  /// Starts polling and opens the live stream.
  Future<void> start() async {
    await refreshAll();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) => _poll());
    _openStream();
  }

  void setBaseUrl(String url) {
    if (url == _apiBaseUrl) return;
    _apiBaseUrl = url;
    _stream?.dispose();
    _stream = null;
    _openStream();
    refreshAll();
    notifyListeners();
  }

  void _openStream() {
    final stream = LiveStream(baseUrl: _apiBaseUrl);
    _stream = stream;
    stream.events.listen((event) {
      if (event.topic == 'metrics' && event.data is Map<String, dynamic>) {
        _applyMetrics(Metrics.fromJson(event.data as Map<String, dynamic>));
        _online = true;
        notifyListeners();
      }
    });
    stream.connection.listen((up) {
      _online = up;
      notifyListeners();
    });
    stream.connect();
  }

  Future<void> refreshAll() async {
    _busy = true;
    notifyListeners();

    final metrics = await _guard(api.currentMetrics);
    final host = await _guard(api.hostInfo);
    final volumes = await _guard(api.volumes);
    final services = await _guard(api.services);
    final disks = await _guard(api.disks);
    final sensors = await _guard(api.sensors);

    _busy = false;

    if (metrics != null) {
      _applyMetrics(metrics);
      _online = true;
    } else {
      _online = false;
    }

    if (host != null) _host = host;
    if (volumes != null) _volumes = volumes;
    if (services != null) _services = services;
    if (disks != null) _disks = disks;
    if (sensors != null) _sensors = sensors;

    notifyListeners();
  }

  Future<void> _poll() async {
    try {
      final metrics = await api.currentMetrics();
      _applyMetrics(metrics);
      _online = true;
      _error = null;
    } catch (e) {
      _online = false;
    }
    notifyListeners();
  }

  Future<T?> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (e) {
      _error = e.toString();
      return null;
    }
  }

  void _applyMetrics(Metrics m) {
    _metrics = m;
    _history.add(m);
    if (_history.length > _historyLimit) {
      _history.removeRange(0, _history.length - _historyLimit);
    }
  }

  /// Runs a container lifecycle action and refreshes the service list.
  Future<void> runServiceAction(Service service, String action) async {
    try {
      await api.serviceAction(service.id, action);
      _services = await api.services();
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _stream?.dispose();
    api.dispose();
    super.dispose();
  }
}
