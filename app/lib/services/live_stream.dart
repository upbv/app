import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

/// A live message pushed by the backend over the websocket.
class StreamEvent {
  StreamEvent(this.topic, this.data);

  final String topic;
  final dynamic data;
}

/// Keeps a websocket open and reconnects with a backoff when the link drops.
class LiveStream {
  LiveStream({required this.baseUrl});

  final String baseUrl;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _retry;
  bool _closed = false;
  int _attempt = 0;

  final _events = StreamController<StreamEvent>.broadcast();
  final _connection = StreamController<bool>.broadcast();

  Stream<StreamEvent> get events => _events.stream;

  /// Emits true when the link is up, false when it drops.
  Stream<bool> get connection => _connection.stream;

  bool get isConnected => _channel != null;

  void connect() {
    if (_closed) return;
    _open();
  }

  void _open() {
    try {
      final wsUrl = baseUrl.replaceFirst(RegExp(r'^http'), 'ws');
      final channel = WebSocketChannel.connect(Uri.parse('$wsUrl/ws'));
      _channel = channel;

      _sub = channel.stream.listen(
        (raw) {
          _attempt = 0;
          try {
            final decoded = jsonDecode(raw as String) as Map<String, dynamic>;
            _events.add(
              StreamEvent(decoded['topic'] as String? ?? '', decoded['data']),
            );
          } catch (_) {
            // Ignore frames we cannot parse.
          }
        },
        onError: (_) => _scheduleRetry(),
        onDone: _scheduleRetry,
        cancelOnError: true,
      );

      _connection.add(true);
    } catch (_) {
      _scheduleRetry();
    }
  }

  void _scheduleRetry() {
    _connection.add(false);
    _channel = null;
    _sub?.cancel();
    _sub = null;

    if (_closed) return;
    _retry?.cancel();
    final delay = Duration(seconds: (1 << _attempt.clamp(0, 5)));
    _attempt++;
    _retry = Timer(delay, _open);
  }

  void dispose() {
    _closed = true;
    _retry?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    _events.close();
    _connection.close();
  }
}
