/// Internet speed test data types. Speeds are bytes per second, like the rest
/// of the app; the UI formats them with the user's unit setting.
library;

enum SpeedTestPhase { idle, latency, download, upload, done, error }

class SpeedTestResult {
  const SpeedTestResult({
    required this.time,
    required this.downBps,
    required this.upBps,
    required this.pingMs,
    required this.jitterMs,
    required this.server,
    required this.bytesUsed,
    this.network = '',
  });

  final DateTime time;
  final double downBps;
  final double upBps;
  final double pingMs;
  final double jitterMs;

  /// Test server location, e.g. "Mumbai (BOM)" or "BOM" (empty when unknown).
  final String server;

  /// Data the test itself transferred (download + upload).
  final int bytesUsed;

  /// Internet provider as the test server sees it ('' when unknown).
  final String network;

  Map<String, Object> toMap() => {
        'time': time.toIso8601String(),
        'down': downBps,
        'up': upBps,
        'ping': pingMs,
        'jitter': jitterMs,
        'server': server,
        'bytes': bytesUsed,
        'network': network,
      };

  static SpeedTestResult? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final time = DateTime.tryParse('${raw['time']}');
    double n(Object? v) => v is num && v.isFinite ? v.toDouble() : 0;
    if (time == null) return null;
    return SpeedTestResult(
      time: time,
      downBps: n(raw['down']),
      upBps: n(raw['up']),
      pingMs: n(raw['ping']),
      jitterMs: n(raw['jitter']),
      server: raw['server'] is String ? raw['server'] as String : '',
      bytesUsed: raw['bytes'] is int ? raw['bytes'] as int : 0,
      network: raw['network'] is String ? raw['network'] as String : '',
    );
  }
}

/// One update from a running test.
class SpeedTestProgress {
  const SpeedTestProgress({
    required this.phase,
    this.currentBps = 0,
    this.phaseFraction = 0,
    this.pingMs,
    this.jitterMs,
    this.downBps,
    this.upBps,
    this.server = '',
    this.bytesUsed = 0,
    this.network = '',
    this.error,
  });

  static const idle = SpeedTestProgress(phase: SpeedTestPhase.idle);

  final SpeedTestPhase phase;

  /// Live speed of the running download/upload phase.
  final double currentBps;

  /// 0..1 progress through the current phase.
  final double phaseFraction;
  final double? pingMs;
  final double? jitterMs;
  final double? downBps;
  final double? upBps;
  final String server;
  final int bytesUsed;
  final String network;
  final String? error;

  bool get running =>
      phase == SpeedTestPhase.latency || phase == SpeedTestPhase.download || phase == SpeedTestPhase.upload;

  SpeedTestProgress copyWith({
    SpeedTestPhase? phase,
    double? currentBps,
    double? phaseFraction,
    double? pingMs,
    double? jitterMs,
    double? downBps,
    double? upBps,
    String? server,
    int? bytesUsed,
    String? network,
    String? error,
  }) =>
      SpeedTestProgress(
        phase: phase ?? this.phase,
        currentBps: currentBps ?? this.currentBps,
        phaseFraction: phaseFraction ?? this.phaseFraction,
        pingMs: pingMs ?? this.pingMs,
        jitterMs: jitterMs ?? this.jitterMs,
        downBps: downBps ?? this.downBps,
        upBps: upBps ?? this.upBps,
        server: server ?? this.server,
        bytesUsed: bytesUsed ?? this.bytesUsed,
        network: network ?? this.network,
        error: error ?? this.error,
      );
}
