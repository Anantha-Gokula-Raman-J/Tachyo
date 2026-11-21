import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Network side of the speed test, behind an interface so the engine's
/// timing and math are testable without a network.
abstract class SpeedTestTransport {
  /// One round trip with no payload. Returns the network round-trip time
  /// (server processing time removed when the server reports it).
  Future<Duration> ping();

  /// Downloads [bytes], reporting each received chunk's size.
  Future<void> download(int bytes, void Function(int received) onBytes);

  /// Uploads [bytes], reporting each chunk handed to the socket.
  Future<void> upload(int bytes, void Function(int sent) onBytes);

  /// Short test-server location code ("BOM"), or '' when unknown.
  String get server;

  /// Internet provider and the test server's city, as the server sees this
  /// connection from its IP address (no permission needed). Empty when unknown.
  Future<({String network, String serverCity})> lookup();

  /// Aborts every request in flight (end of a phase or cancel).
  void abortAll();

  void close();
}

/// Public speed test endpoints run by Cloudflare (speed.cloudflare.com):
/// `GET /__down?bytes=N` streams N bytes, `POST /__up` accepts a body.
/// Uses only dart:io, no packages.
class HttpSpeedTestTransport implements SpeedTestTransport {
  HttpSpeedTestTransport({this.host = 'speed.cloudflare.com'}) {
    _client = _newClient();
  }

  final String host;
  late HttpClient _client;
  final Set<HttpClientRequest> _active = {};
  String _server = '';

  @override
  String get server => _server;

  static HttpClient _newClient() => HttpClient()
    ..connectionTimeout = const Duration(seconds: 10)
    ..idleTimeout = const Duration(seconds: 5)
    ..userAgent = 'Tachyo';

  Uri _uri(String path, [Map<String, String>? query]) => Uri.https(host, path, query);

  void _noteServer(HttpClientResponse response) {
    // cf-ray: "8f1c2a3b4c5d6e7f-BOM" -> data center code.
    final rays = response.headers['cf-ray'];
    final ray = rays == null || rays.isEmpty ? null : rays.first;
    if (ray != null && ray.contains('-')) _server = ray.split('-').last;
  }

  @override
  Future<({String network, String serverCity})> lookup() async {
    final request = await _client.getUrl(_uri('/meta'));
    _active.add(request);
    try {
      // The endpoint answers {} without the speed test page's referer.
      request.headers.set(HttpHeaders.refererHeader, 'https://$host/');
      final response = await request.close().timeout(const Duration(seconds: 5));
      final data = jsonDecode(await response.transform(utf8.decoder).join());
      if (data is! Map) return (network: '', serverCity: '');
      final org = data['asOrganization'];
      final colo = data['colo'];
      final city = colo is Map ? colo['city'] : null;
      return (network: org is String ? org : '', serverCity: city is String ? city : '');
    } finally {
      _active.remove(request);
    }
  }

  @override
  Future<Duration> ping() async {
    final watch = Stopwatch()..start();
    final request = await _client.getUrl(_uri('/__down', {'bytes': '0'}));
    _active.add(request);
    try {
      final response = await request.close();
      watch.stop();
      _noteServer(response);
      await response.drain<void>();
      // The header can repeat; `headers.value` would throw, so read them all.
      final serverMs = serverTimeMs((response.headers['server-timing'] ?? const <String>[]).join(','));
      final micros = watch.elapsedMicroseconds - (serverMs * 1000).round();
      return Duration(microseconds: micros < 0 ? 0 : micros);
    } finally {
      _active.remove(request);
    }
  }

  /// Milliseconds the server spent on the request, from `Server-Timing`.
  /// Older form: `cfRequestDuration;dur=12`; current form (2026):
  /// `cfSpeedEdge;dur=1, cfSpeedWorker;dur=15`. The `cfL4` transport entry
  /// is not server time and is ignored.
  static double serverTimeMs(String timing) {
    var total = 0.0;
    for (final m in RegExp(r'(cfRequestDuration|cfSpeed\w*);dur=([\d.]+)').allMatches(timing)) {
      total += double.tryParse(m.group(2)!) ?? 0;
    }
    return total;
  }

  @override
  Future<void> download(int bytes, void Function(int received) onBytes) async {
    final request = await _client.getUrl(_uri('/__down', {'bytes': '$bytes'}));
    _active.add(request);
    try {
      final response = await request.close();
      _noteServer(response);
      if (response.statusCode != 200) {
        await response.drain<void>();
        throw HttpException('Test server answered ${response.statusCode}');
      }
      await for (final chunk in response) {
        onBytes(chunk.length);
      }
    } finally {
      _active.remove(request);
    }
  }

  @override
  Future<void> upload(int bytes, void Function(int sent) onBytes) async {
    final request = await _client.postUrl(_uri('/__up'));
    _active.add(request);
    try {
      request.contentLength = bytes;
      request.headers.contentType = ContentType.binary;
      await request.addStream(_payload(bytes, onBytes));
      final response = await request.close();
      _noteServer(response);
      await response.drain<void>();
    } finally {
      _active.remove(request);
    }
  }

  static final Uint8List _chunk = Uint8List(64 * 1024);

  /// Yields the body lazily; addStream pulls the next chunk only after the
  /// socket took the previous one, so counting here tracks real sending.
  static Stream<List<int>> _payload(int bytes, void Function(int) onBytes) async* {
    var left = bytes;
    while (left > 0) {
      final n = left < _chunk.length ? left : _chunk.length;
      yield n == _chunk.length ? _chunk : Uint8List.sublistView(_chunk, 0, n);
      onBytes(n);
      left -= n;
    }
  }

  @override
  void abortAll() {
    for (final r in _active.toList()) {
      r.abort();
    }
    _active.clear();
    // Drop pooled sockets too, so the next phase starts clean.
    _client.close(force: true);
    _client = _newClient();
  }

  @override
  void close() {
    for (final r in _active.toList()) {
      r.abort();
    }
    _active.clear();
    _client.close(force: true);
  }
}
