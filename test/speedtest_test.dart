import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tachyo/src/speedtest/engine.dart';
import 'package:tachyo/src/speedtest/history.dart';
import 'package:tachyo/src/speedtest/models.dart';
import 'package:tachyo/src/speedtest/speed_test_controller.dart';
import 'package:tachyo/src/speedtest/transport.dart';

/// Moves [chunk] bytes every 10 ms per stream; never touches the network.
class FakeTransport implements SpeedTestTransport {
  FakeTransport({this.chunk = 10000, this.rtts = const [30, 20, 22, 18, 24], this.fail = false});
  final int chunk;
  final List<int> rtts;
  final bool fail;
  int _ping = 0;
  bool _aborted = false;
  int aborts = 0;

  @override
  String get server => 'TST';

  @override
  Future<({String network, String serverCity})> lookup() async => (network: 'Test ISP', serverCity: 'Testville');

  @override
  Future<Duration> ping() async {
    if (fail) throw const SocketException('Failed host lookup');
    await Future<void>.delayed(const Duration(milliseconds: 1));
    return Duration(milliseconds: rtts[_ping++ % rtts.length]);
  }

  Future<void> _move(int bytes, void Function(int) onBytes) async {
    _aborted = false;
    var left = bytes;
    while (left > 0) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      if (_aborted) throw const HttpException('aborted');
      final n = left < chunk ? left : chunk;
      onBytes(n);
      left -= n;
    }
  }

  @override
  Future<void> download(int bytes, void Function(int) onBytes) => _move(bytes, onBytes);

  @override
  Future<void> upload(int bytes, void Function(int) onBytes) => _move(bytes, onBytes);

  @override
  void abortAll() {
    _aborted = true;
    aborts++;
  }

  @override
  void close() {}
}

const fast = SpeedTestConfig(
  pings: 4,
  downloadTime: Duration(milliseconds: 600),
  uploadTime: Duration(milliseconds: 600),
  warmUp: Duration(milliseconds: 150),
  downloadStreams: 2,
  uploadStreams: 1,
  downloadRequestBytes: 1000000,
  uploadRequestBytes: 1000000,
  tick: Duration(milliseconds: 50),
);

void main() {
  test('latency stats: lowest round trip and mean consecutive difference', () {
    final (ping, jitter) = SpeedTestEngine.latencyStats([20, 22, 18, 24]);
    expect(ping, 18);
    expect(jitter, closeTo((2 + 4 + 6) / 3, 1e-9));
    expect(SpeedTestEngine.latencyStats([]), (0.0, 0.0));
  });

  test('server time is read from both Server-Timing forms', () {
    expect(HttpSpeedTestTransport.serverTimeMs('cfRequestDuration;dur=12.5'), 12.5);
    expect(
      HttpSpeedTestTransport.serverTimeMs(
          'cfSpeedEdge;dur=1, cfSpeedWorker;dur=15,cfL4;desc="?proto=TCP&rtt=13057&min_rtt=6413"'),
      16,
    );
    expect(HttpSpeedTestTransport.serverTimeMs(''), 0);
  });

  test('rate limiting gets its own message', () {
    expect(SpeedTestEngine.describeError(const HttpException('Test server answered 429')), contains('Try again in a few minutes'));
  });

  test('runs latency, download and upload in order with plausible numbers', () async {
    final engine = SpeedTestEngine(FakeTransport(), config: fast);
    final updates = await engine.run().toList();
    final phases = updates.map((u) => u.phase).toSet().toList();
    expect(phases, [SpeedTestPhase.latency, SpeedTestPhase.download, SpeedTestPhase.upload, SpeedTestPhase.done]);
    final last = updates.last;
    // First ping (connection setup) dropped: [20, 22, 18, 24].
    expect(last.pingMs, 18);
    expect(last.server, 'Testville (TST)');
    expect(last.network, 'Test ISP');
    // 10 kB / 10 ms = ~1 MB/s per stream; timers only ever run late, so the
    // measured rate is at or below that.
    expect(last.downBps, inInclusiveRange(0.8e6, 2.1e6)); // two streams
    expect(last.upBps, inInclusiveRange(0.4e6, 1.05e6)); // one stream
    expect(last.bytesUsed, greaterThan(0));
  });

  test('a dead network reports an error instead of zero speeds', () async {
    final engine = SpeedTestEngine(FakeTransport(fail: true), config: fast);
    final last = (await engine.run().toList()).last;
    expect(last.phase, SpeedTestPhase.error);
    expect(last.error, contains('Could not reach'));
  });

  test('controller saves finished runs and cancel returns to idle', () async {
    final history = MemorySpeedTestHistory();
    final c = SpeedTestController(history: history, transport: FakeTransport.new, config: fast);
    await c.start();
    expect(c.progress.phase, SpeedTestPhase.done);
    expect(c.results, hasLength(1));
    final saved = (await history.load()).single;
    expect(saved.server, 'Testville (TST)');
    expect(saved.network, 'Test ISP');

    final running = c.start();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    c.cancel();
    await running;
    expect(c.progress.phase, SpeedTestPhase.idle);
    expect(c.results, hasLength(1)); // cancelled run is not saved
    c.dispose();
  });

  test('file history keeps newest first and survives a corrupt file', () async {
    final dir = await Directory.systemTemp.createTemp('tachyo_st');
    final file = File('${dir.path}/speedtests.json');
    final h = FileSpeedTestHistory(file);
    for (var i = 0; i < 3; i++) {
      await h.add(SpeedTestResult(
        time: DateTime(2026, 11, 21, 10, i),
        downBps: i * 1.0,
        upBps: 0,
        pingMs: 1,
        jitterMs: 0,
        server: 'X',
        bytesUsed: 1,
      ));
    }
    expect((await h.load()).map((r) => r.downBps), [2, 1, 0]);
    await file.writeAsString('{not json');
    expect(await h.load(), isEmpty);
    await dir.delete(recursive: true);
  });
}
