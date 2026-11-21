// Manual check against the real test server (needs internet; not part of
// `flutter test`, which only runs test/):
//   flutter test tool/speedtest_live_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tachyo/src/speedtest/engine.dart';
import 'package:tachyo/src/speedtest/models.dart';
import 'package:tachyo/src/speedtest/transport.dart';

void main() {
  test('live speed test completes with non-zero results', () async {
    final transport = HttpSpeedTestTransport();
    final engine = SpeedTestEngine(
      transport,
      config: const SpeedTestConfig(downloadTime: Duration(seconds: 6), uploadTime: Duration(seconds: 5)),
    );
    final last = (await engine.run().toList()).last;
    transport.close();
    // ignore: avoid_print
    print('phase=${last.phase} ping=${last.pingMs?.toStringAsFixed(1)} ms '
        'jitter=${last.jitterMs?.toStringAsFixed(1)} ms '
        'down=${((last.downBps ?? 0) * 8 / 1e6).toStringAsFixed(2)} Mbps '
        'up=${((last.upBps ?? 0) * 8 / 1e6).toStringAsFixed(2)} Mbps '
        'server=${last.server} used=${(last.bytesUsed / 1e6).toStringAsFixed(1)} MB ${last.error ?? ''}');
    expect(last.phase, SpeedTestPhase.done);
    expect(last.downBps, greaterThan(0));
    expect(last.upBps, greaterThan(0));
  }, timeout: const Timeout(Duration(minutes: 2)));
}
