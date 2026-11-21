// Manual probe: how download throughput depends on the number of parallel
// streams on a device (e.g. the Android emulator). Prints to the device log.
//   flutter run -d emulator-5554 --release -t tool/speedtest_probe_main.dart
// Read results with: adb logcat -s flutter
import 'package:flutter/material.dart';
import 'package:tachyo/src/speedtest/engine.dart';
import 'package:tachyo/src/speedtest/transport.dart';

Future<void> main() async {
  runApp(const MaterialApp(home: Scaffold(body: Center(child: Text('probe running – see logcat')))));
  for (final streams in [1, 2, 4, 6]) {
    final transport = HttpSpeedTestTransport();
    final engine = SpeedTestEngine(
      transport,
      config: SpeedTestConfig(
        pings: 2,
        downloadTime: const Duration(seconds: 6),
        uploadTime: const Duration(seconds: 4),
        downloadStreams: streams,
        uploadStreams: streams,
      ),
    );
    final last = (await engine.run().toList()).last;
    transport.close();
    // ignore: avoid_print
    print('PROBE streams=$streams down=${((last.downBps ?? 0) * 8 / 1e6).toStringAsFixed(1)} Mbps '
        'up=${((last.upBps ?? 0) * 8 / 1e6).toStringAsFixed(1)} Mbps ${last.error ?? ''}');
  }
  // ignore: avoid_print
  print('PROBE done');
}
