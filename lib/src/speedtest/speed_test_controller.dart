import 'dart:async';

import 'package:flutter/foundation.dart';

import 'engine.dart';
import 'history.dart';
import 'models.dart';
import 'transport.dart';

/// UI state for the speed test page: the running test and saved results.
class SpeedTestController extends ChangeNotifier {
  SpeedTestController({
    required this.history,
    SpeedTestTransport Function()? transport,
    this.config = const SpeedTestConfig(),
    DateTime Function()? clock,
  })  : _transport = transport ?? HttpSpeedTestTransport.new,
        _clock = clock ?? DateTime.now;

  final SpeedTestHistory history;
  final SpeedTestConfig config;
  final SpeedTestTransport Function() _transport;
  final DateTime Function() _clock;

  SpeedTestProgress progress = SpeedTestProgress.idle;
  List<SpeedTestResult> results = [];
  SpeedTestEngine? _engine;
  StreamSubscription<SpeedTestProgress>? _sub;
  bool _loaded = false;
  bool _cancelledRun = false;
  bool _disposed = false;

  bool get running => progress.running;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    results = await history.load();
    _notify();
  }

  /// Starts a test; completes when it ends (done, error or cancel).
  Future<void> start() async {
    if (running) return;
    final transport = _transport();
    final engine = _engine = SpeedTestEngine(transport, config: config);
    final finished = Completer<void>();
    _cancelledRun = false;
    progress = const SpeedTestProgress(phase: SpeedTestPhase.latency);
    _notify();
    _sub = engine.run().listen(
      (p) {
        if (_cancelledRun) return; // late ticks after Cancel
        progress = p;
        _notify();
        if (p.phase == SpeedTestPhase.done) {
          final result = SpeedTestResult(
            time: _clock(),
            downBps: p.downBps ?? 0,
            upBps: p.upBps ?? 0,
            pingMs: p.pingMs ?? 0,
            jitterMs: p.jitterMs ?? 0,
            server: p.server,
            bytesUsed: p.bytesUsed,
            network: p.network,
          );
          results = [result, ...results].take(SpeedTestHistory.keep).toList();
          history.add(result);
        }
      },
      onDone: () {
        transport.close();
        if (identical(_engine, engine)) _engine = null;
        if (!finished.isCompleted) finished.complete();
      },
    );
    return finished.future;
  }

  void cancel() {
    final engine = _engine;
    if (engine == null) return;
    _cancelledRun = true;
    engine.cancel();
    progress = SpeedTestProgress.idle;
    _notify();
  }

  Future<void> clearHistory() async {
    results = [];
    _notify();
    await history.clear();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _engine?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}
