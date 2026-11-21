import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tachyo/src/core/format.dart';
import 'package:tachyo/src/core/models.dart';
import 'package:tachyo/src/data/settings_store.dart';
import 'package:tachyo/src/data/usage_repository.dart';
import 'package:tachyo/src/platform/meter_platform.dart';
import 'package:tachyo/src/platform/native_bridge.dart';
import 'package:tachyo/src/speedtest/history.dart';
import 'package:tachyo/src/speedtest/speed_test_controller.dart';
import 'package:tachyo/src/state/meter_controller.dart';
import 'package:tachyo/src/ui/app.dart';

/// Scripted counters: each read advances one second and [step] bytes.
class FakeSource implements NetSource {
  FakeSource({this.stepRx = 2048, this.stepTx = 512});
  final int stepRx;
  final int stepTx;
  int _i = 0;

  @override
  Future<NetCounters> read() async {
    final i = _i++;
    return NetCounters(
      rx: i * stepRx,
      tx: i * stepTx,
      wifiRx: i * stepRx,
      wifiTx: i * stepTx,
      timestampMs: i * 1000,
    );
  }
}

/// Android-like by default; [windows] switches on the Windows behaviours
/// (always-on tray meter, floating meter, sign-in start).
class FakePlatform extends MeterPlatform {
  FakePlatform({this.inAppRecording = true, this.windows = false});
  final bool inAppRecording;
  final bool windows;
  @override
  final NetSource source = FakeSource();
  @override
  final MemoryUsageRepository usage = MemoryUsageRepository();
  @override
  final MemorySettingsStore settings = MemorySettingsStore();
  @override
  final MemorySpeedTestHistory speedTests = MemorySpeedTestHistory();
  bool running = false;
  int samples = 0;

  @override
  String get meterLabel => windows ? 'Tray meter' : 'Status bar meter';
  @override
  String get meterDescription => 'desc';
  @override
  String get otherLabel => 'Other';
  @override
  bool get hasMobile => !windows;
  @override
  bool get supportsBootStart => true;
  @override
  bool get supportsFloating => windows;
  @override
  bool get meterAlwaysOn => windows;
  @override
  Future<bool> isMeterRunning() async => running;
  @override
  Future<bool> setMeterEnabled(bool enabled) async => running = windows || enabled;
  @override
  bool recordsUsageInApp({required bool meterRunning}) => inAppRecording && !meterRunning;
  @override
  Future<void> onSample(SpeedSample sample, AppSettings settings, DailyUsage today) async => samples++;

  // Recorded side effects.
  AppSettings? applied;
  bool shownWindow = false;
  void Function(String action)? _native;
  @override
  Future<void> applySettings(AppSettings settings, {required bool meterRunning}) async => applied = settings;
  @override
  Future<void> showWindow() async => shownWindow = true;
  @override
  void onNativeAction(void Function(String action) handler) => _native = handler;

  /// Simulates a tray-menu / floating-meter action from the native side.
  Future<void> fire(String action) async {
    _native!(action);
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  final now = DateTime(2026, 11, 21, 12);

  test('controller samples speed, peaks and records usage', () async {
    final p = FakePlatform();
    final c = MeterController(p, interval: const Duration(hours: 1), clock: () => now);
    await c.start();
    await c.tick();
    await c.tick();
    expect(c.current.downBps, 2048);
    expect(c.current.upBps, 512);
    expect(c.history.length, 2);
    expect(c.peakDown, 2048);
    expect(c.sessionRx, 4096);
    expect(p.usage.data['2026-11-21']!.wifiRx, 4096);
    expect(c.today.wifiTx, 1024);
    expect(p.samples, 2);
    c.dispose();
  });

  test('no in-app recording while the background meter runs', () async {
    final p = FakePlatform()..running = true;
    final c = MeterController(p, interval: const Duration(hours: 1), clock: () => now);
    await c.start();
    await c.tick();
    expect(p.usage.data, isEmpty);
    c.dispose();
  });

  test('enabling the meter persists the setting', () async {
    final p = FakePlatform();
    final c = MeterController(p, interval: const Duration(hours: 1), clock: () => now);
    await c.start();
    await c.setMeterEnabled(true);
    expect(c.meterRunning, isTrue);
    expect(p.settings.value.meterEnabled, isTrue);
    await c.updateSettings(c.settings.copyWith(unit: SpeedUnit.bits, scale: SpeedScale.kilo));
    expect(p.settings.value.unit, SpeedUnit.bits);
    expect(p.settings.value.scale, SpeedScale.kilo);
    c.dispose();
  });

  test('Windows: tray meter always starts, settings reach the platform, tray toggles work', () async {
    final p = FakePlatform(windows: true);
    final c = MeterController(p, interval: const Duration(hours: 1), clock: () => now);
    await c.start(background: true);
    expect(c.meterRunning, isTrue); // even though meterEnabled was never saved
    expect(p.shownWindow, isFalse); // sign-in start stays in the tray
    expect(p.applied!.floatingMeter, isTrue); // floating meter on by default
    expect(p.applied!.bootStart, isTrue);

    await p.fire('toggleFloating');
    expect(p.settings.value.floatingMeter, isFalse);
    expect(p.applied!.floatingMeter, isFalse);
    await p.fire('toggleAutoStart');
    expect(p.applied!.bootStart, isFalse);
    c.dispose();
  });

  test('sign-in start with no visible meter shows the window', () async {
    final p = FakePlatform();
    final c = MeterController(p, interval: const Duration(hours: 1), clock: () => now);
    await c.start(background: true);
    expect(p.shownWindow, isTrue);
    c.dispose();
  });

  testWidgets('pages render and settings change unit and speed format', (tester) async {
    final p = FakePlatform();
    final c = MeterController(p, interval: const Duration(hours: 1), clock: () => now);
    final st = SpeedTestController(history: p.speedTests);
    await tester.runAsync(() async {
      await c.start();
      await c.tick();
    });
    await tester.pumpWidget(TachyoApp(controller: c, speedTest: st));
    await tester.pump();

    expect(find.byKey(const Key('download-tile')), findsOneWidget);
    expect(find.text('16.4'), findsWidgets); // 2048 B/s -> 16.4 Kbps (bits by default)
    expect(find.text('Wi‑Fi'), findsOneWidget);

    await tester.tap(find.text('Usage'));
    await tester.pumpAndSettle();
    expect(find.text('LAST 7 DAYS'), findsOneWidget);

    await tester.tap(find.text('Test'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('test-start')), findsOneWidget);
    expect(find.byKey(const Key('metric-Ping')), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Status bar meter'), findsOneWidget);
    expect(c.settings.unit, SpeedUnit.bits);
    await tester.tap(find.text('Kbps'));
    await tester.pumpAndSettle();
    expect(c.settings.scale, SpeedScale.kilo);
    await tester.tap(find.text('Bytes  (KB/s, MB/s)'));
    await tester.pumpAndSettle();
    expect(c.settings.unit, SpeedUnit.bytes);
    expect(find.text('KB/s'), findsOneWidget); // scale labels follow the unit

    c.dispose();
    st.dispose();
  });
}
