import 'dart:async';
import 'dart:math' as math;

import 'models.dart';
import 'transport.dart';

/// Timing and limits for one test. Defaults suit real networks; tests pass
/// short durations.
class SpeedTestConfig {
  const SpeedTestConfig({
    this.pings = 20,
    this.downloadTime = const Duration(seconds: 10),
    this.uploadTime = const Duration(seconds: 8),
    this.warmUp = const Duration(milliseconds: 1500),
    this.downloadStreams = 6,
    this.uploadStreams = 4,
    this.downloadRequestBytes = 25 * 1000 * 1000,
    this.uploadRequestBytes = 4 * 1000 * 1000,
    this.downloadCapBytes = 400 * 1000 * 1000,
    this.uploadCapBytes = 150 * 1000 * 1000,
    this.tick = const Duration(milliseconds: 200),
  });

  final int pings;
  final Duration downloadTime;
  final Duration uploadTime;

  /// Ignored at the start of each transfer phase (TCP slow start).
  final Duration warmUp;
  final int downloadStreams;
  final int uploadStreams;
  final int downloadRequestBytes;
  final int uploadRequestBytes;

  /// A phase also ends once this much data moved, to bound data use on
  /// very fast links.
  final int downloadCapBytes;
  final int uploadCapBytes;
  final Duration tick;
}

/// Runs latency -> download -> upload and streams progress.
///
/// Latency: the lowest of [SpeedTestConfig.pings] round trips (the first,
/// which includes connection setup, is dropped). That is the idle latency of
/// the path; Wi-Fi power saving and queueing only ever add to it. Jitter is
/// the mean difference between consecutive round trips.
/// Throughput: several parallel streams for a fixed time; the result is the
/// data moved after the warm-up divided by the time after the warm-up.
class SpeedTestEngine {
  SpeedTestEngine(this.transport, {this.config = const SpeedTestConfig()});

  final SpeedTestTransport transport;
  final SpeedTestConfig config;
  bool _cancelled = false;

  void cancel() {
    _cancelled = true;
    transport.abortAll();
  }

  Stream<SpeedTestProgress> run() {
    _cancelled = false;
    final out = StreamController<SpeedTestProgress>();
    () async {
      var p = const SpeedTestProgress(phase: SpeedTestPhase.latency);
      out.add(p);
      var city = '';
      String where() {
        final code = transport.server;
        if (city.isEmpty) return code;
        return code.isEmpty ? city : '$city ($code)';
      }

      try {
        // Provider and server city: best effort, never blocks the test.
        try {
          final info = await transport.lookup();
          city = info.serverCity;
          p = p.copyWith(network: info.network);
        } on Object {
          // Unknown provider is fine.
        }
        if (_cancelled) return;

        // Latency.
        final rtts = <double>[];
        for (var i = 0; i <= config.pings && !_cancelled; i++) {
          final rtt = await transport.ping();
          if (i > 0) rtts.add(rtt.inMicroseconds / 1000);
          p = p.copyWith(phaseFraction: i / config.pings, server: where());
          out.add(p);
        }
        if (_cancelled) return;
        final stats = latencyStats(rtts);
        p = p.copyWith(pingMs: stats.$1, jitterMs: stats.$2);

        // Download.
        p = p.copyWith(phase: SpeedTestPhase.download, phaseFraction: 0, currentBps: 0);
        out.add(p);
        final down = await _transfer(
          streams: config.downloadStreams,
          duration: config.downloadTime,
          capBytes: config.downloadCapBytes,
          request: (onBytes) => transport.download(config.downloadRequestBytes, onBytes),
          onTick: (speed, fraction, moved) =>
              out.add(p.copyWith(currentBps: speed, phaseFraction: fraction, bytesUsed: moved)),
        );
        if (_cancelled) return;
        p = p.copyWith(downBps: down.$1, bytesUsed: down.$2, currentBps: down.$1, server: where());

        // Upload.
        p = p.copyWith(phase: SpeedTestPhase.upload, phaseFraction: 0, currentBps: 0);
        out.add(p);
        final usedBefore = p.bytesUsed;
        final up = await _transfer(
          streams: config.uploadStreams,
          duration: config.uploadTime,
          capBytes: config.uploadCapBytes,
          request: (onBytes) => transport.upload(config.uploadRequestBytes, onBytes),
          onTick: (speed, fraction, moved) =>
              out.add(p.copyWith(currentBps: speed, phaseFraction: fraction, bytesUsed: usedBefore + moved)),
        );
        if (_cancelled) return;
        p = p.copyWith(
          phase: SpeedTestPhase.done,
          upBps: up.$1,
          currentBps: up.$1,
          phaseFraction: 1,
          bytesUsed: usedBefore + up.$2,
          server: where(),
        );
        out.add(p);
      } on Object catch (e) {
        if (!_cancelled) {
          out.add(p.copyWith(phase: SpeedTestPhase.error, error: describeError(e)));
        }
      } finally {
        transport.abortAll();
        await out.close();
      }
    }();
    return out.stream;
  }

  /// Returns (bytes per second after warm-up, total bytes moved).
  Future<(double, int)> _transfer({
    required int streams,
    required Duration duration,
    required int capBytes,
    required Future<void> Function(void Function(int) onBytes) request,
    required void Function(double speed, double fraction, int moved) onTick,
  }) async {
    final watch = Stopwatch()..start();
    var moved = 0;
    int? movedAtWarmUp;
    Duration? warmUpAt;
    Object? failure;
    var done = false;
    void count(int n) => moved += n;

    bool finished() => _cancelled || done || watch.elapsed >= duration || moved >= capBytes;

    Future<void> worker() async {
      while (!finished()) {
        try {
          await request(count);
        } on Object catch (e) {
          // Aborts at the end of the phase are expected; real failures are
          // kept so a dead network is reported instead of "0 Mbps".
          if (!finished()) failure ??= e;
          return;
        }
      }
    }

    final workers = [for (var i = 0; i < streams; i++) worker()];

    // Sliding one-second window for the live needle.
    final window = <(int, int)>[(0, 0)]; // (elapsed ms, moved)
    while (!finished()) {
      await Future<void>.delayed(config.tick);
      final ms = watch.elapsedMilliseconds;
      if (movedAtWarmUp == null && watch.elapsed >= config.warmUp) {
        movedAtWarmUp = moved;
        warmUpAt = watch.elapsed;
      }
      window.add((ms, moved));
      while (window.length > 2 && ms - window[1].$1 >= 1000) {
        window.removeAt(0);
      }
      final first = window.first;
      final span = (ms - first.$1) / 1000;
      final live = span > 0 ? (moved - first.$2) / span : 0.0;
      onTick(live, math.min(1, ms / duration.inMilliseconds), moved);
      if (failure != null && moved == 0) break;
    }
    done = true;
    final elapsed = watch.elapsed;
    transport.abortAll();
    await Future.wait(workers);
    if (failure != null && moved == 0) throw failure!;

    final double speed;
    final warmBytes = movedAtWarmUp;
    final warmTime = warmUpAt;
    if (warmBytes != null && warmTime != null && elapsed - warmTime >= const Duration(milliseconds: 500)) {
      speed = (moved - warmBytes) / ((elapsed - warmTime).inMicroseconds / 1e6);
    } else {
      speed = elapsed.inMicroseconds > 0 ? moved / (elapsed.inMicroseconds / 1e6) : 0;
    }
    return (speed, moved);
  }

  /// (ping ms, jitter ms): the lowest round trip and the mean difference
  /// between consecutive round trips.
  static (double, double) latencyStats(List<double> rtts) {
    if (rtts.isEmpty) return (0, 0);
    final lowest = rtts.reduce(math.min);
    var jitter = 0.0;
    for (var i = 1; i < rtts.length; i++) {
      jitter += (rtts[i] - rtts[i - 1]).abs();
    }
    return (lowest, rtts.length > 1 ? jitter / (rtts.length - 1) : 0);
  }

  static String describeError(Object e) {
    final text = '$e';
    if (text.contains('SocketException') || text.contains('Failed host lookup') || text.contains('HandshakeException')) {
      return 'Could not reach the test server. Check your internet connection.';
    }
    if (text.contains('answered 429')) {
      return 'The test server is limiting tests from your connection right now. Try again in a few minutes.';
    }
    if (text.contains('TimeoutException') || text.contains('timed out')) {
      return 'The test server did not answer in time.';
    }
    return 'The test stopped: $text';
  }
}
