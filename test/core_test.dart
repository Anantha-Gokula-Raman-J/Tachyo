import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tachyo/src/core/format.dart';
import 'package:tachyo/src/core/models.dart';
import 'package:tachyo/src/core/sampler.dart';
import 'package:tachyo/src/data/settings_store.dart';
import 'package:tachyo/src/data/usage_repository.dart';

NetCounters c(int rx, int tx, int t, {int wifiRx = 0, int wifiTx = 0, int mobileRx = 0, int mobileTx = 0}) =>
    NetCounters(rx: rx, tx: tx, wifiRx: wifiRx, wifiTx: wifiTx, mobileRx: mobileRx, mobileTx: mobileTx, timestampMs: t);

void main() {
  group('formatSpeed', () {
    test('bytes scale with 1024 base', () {
      expect(formatSpeed(0, SpeedUnit.bytes).toString(), '0 B/s');
      expect(formatSpeed(512, SpeedUnit.bytes).toString(), '512 B/s');
      expect(formatSpeed(1536, SpeedUnit.bytes).toString(), '1.50 KB/s');
      expect(formatSpeed(1024 * 1024 * 12.34, SpeedUnit.bytes).toString(), '12.3 MB/s');
      expect(formatSpeed(1024 * 300, SpeedUnit.bytes).toString(), '300 KB/s');
    });

    test('never shows four integer digits', () {
      expect(formatSpeed(1010, SpeedUnit.bytes).toString(), '0.99 KB/s');
      expect(formatSpeed(1024 * 1010, SpeedUnit.bytes).toString(), '0.99 MB/s');
    });

    test('bits scale with 1000 base', () {
      expect(formatSpeed(125000, SpeedUnit.bits).toString(), '1.0 Mbps');
      expect(formatSpeed(100, SpeedUnit.bits).toString(), '800 bps');
      // One decimal like other meters: 222 KB/s (1024-based) = 1.8 Mbps.
      expect(formatSpeed(222 * 1024, SpeedUnit.bits).toString(), '1.8 Mbps');
      expect(formatSpeed(103300 / 8, SpeedUnit.bits).toString(), '103.3 Kbps');
      expect(formatSpeed(144.4e6 / 8, SpeedUnit.bits).toString(), '144.4 Mbps');
      // 999.96 Kbps must not read "1000.0 Kbps".
      expect(formatSpeed(999960 / 8, SpeedUnit.bits).toString(), '1.0 Mbps');
    });

    test('invalid input is zero', () {
      expect(formatSpeed(double.nan, SpeedUnit.bytes).toString(), '0 B/s');
      expect(formatSpeed(-5, SpeedUnit.bytes).toString(), '0 B/s');
      expect(formatSpeed(double.infinity, SpeedUnit.bits).toString(), '0 bps');
    });

    test('compact fits the tray/status icon', () {
      expect(compactSpeed(0, SpeedUnit.bytes).toString(), '0 B');
      expect(compactSpeed(1536, SpeedUnit.bytes).toString(), '1.5 KB');
      expect(compactSpeed(1024 * 1024 * 45.6, SpeedUnit.bytes).toString(), '46 MB');
      expect(compactSpeed(125000, SpeedUnit.bits).toString(), '1.0 Mb');
    });

    test('fixed speed format keeps one unit', () {
      expect(formatSpeed(2048 * 1024, SpeedUnit.bytes, SpeedScale.kilo).toString(), '2048 KB/s');
      expect(formatSpeed(512, SpeedUnit.bytes, SpeedScale.kilo).toString(), '0.50 KB/s');
      expect(formatSpeed(300, SpeedUnit.bytes, SpeedScale.mega).toString(), '0.00 MB/s');
      expect(formatSpeed(1500, SpeedUnit.bytes, SpeedScale.base).toString(), '1500 B/s');
      expect(formatSpeed(125000, SpeedUnit.bits, SpeedScale.kilo).toString(), '1000 Kbps');
      expect(scaleLabel(SpeedScale.mega, SpeedUnit.bits), 'Mbps');
      expect(scaleLabel(SpeedScale.auto, SpeedUnit.bytes), 'Auto');
      // Icons fall back to auto when a fixed unit would need 4+ digits.
      expect(compactSpeed(5e6, SpeedUnit.bytes, SpeedScale.kilo).toString(), '4.8 MB');
      expect(compactSpeed(5000, SpeedUnit.bytes, SpeedScale.kilo).toString(), '4.9 KB');
    });

    test('formatBytes', () {
      expect(formatBytes(0), '0 B');
      expect(formatBytes(1024 * 1024 * 1024 * 3 ~/ 2), '1.50 GB');
      expect(formatBytes(-1), '0 B');
    });
  });

  group('SpeedSampler', () {
    test('first reading has no speed', () {
      expect(SpeedSampler().push(c(100, 100, 0)), isNull);
    });

    test('computes bytes/second and category deltas', () {
      final s = SpeedSampler()..push(c(0, 0, 1000, wifiRx: 0, mobileRx: 0));
      final r = s.push(c(3000, 1000, 3000, wifiRx: 2000, mobileRx: 500, wifiTx: 1000))!;
      expect(r.speed.downBps, 1500);
      expect(r.speed.upBps, 500);
      expect(r.delta.wifiRx, 2000);
      expect(r.delta.mobileRx, 500);
      expect(r.delta.otherRx, 500);
      expect(r.delta.wifiTx, 1000);
      expect(r.delta.otherTx, 0);
    });

    test('counter reset drops the interval instead of spiking', () {
      final s = SpeedSampler()..push(c(10000, 10000, 0));
      expect(s.push(c(5, 5, 1000)), isNull);
      final next = s.push(c(1029, 5, 2000))!;
      expect(next.speed.downBps, 1024);
    });

    test('non-advancing clock is ignored', () {
      final s = SpeedSampler()..push(c(0, 0, 1000));
      expect(s.push(c(10, 10, 1000)), isNull);
    });
  });

  group('DailyUsage & dayKey', () {
    test('dayKey is zero padded local date', () {
      expect(dayKey(DateTime(2026, 3, 7, 23, 59)), '2026-03-07');
    });

    test('totals add up', () {
      final d = DailyUsage(date: 'x')..add(const UsageDelta(wifiRx: 1, wifiTx: 2, mobileRx: 3, mobileTx: 4, otherRx: 5, otherTx: 6));
      expect(d.total, 21);
      expect(d.totalRx, 9);
      expect(d.wifi, 3);
    });
  });

  group('FileUsageRepository', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('tachyo_test'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('persists, fills gaps and survives corrupt files', () async {
      final file = File('${dir.path}/usage.json');
      final today = DateTime(2026, 11, 21);
      final repo = FileUsageRepository(file, flushEvery: 1);
      await repo.add('2026-11-21', const UsageDelta(wifiRx: 100, otherTx: 50));
      await repo.add('2026-11-19', const UsageDelta(mobileRx: 7));

      final reloaded = await FileUsageRepository(file).recent(3, today);
      expect(reloaded.map((d) => d.date), ['2026-11-21', '2026-11-20', '2026-11-19']);
      expect(reloaded[0].total, 150);
      expect(reloaded[1].total, 0);
      expect(reloaded[2].mobileRx, 7);

      file.writeAsStringSync('{not json');
      final broken = await FileUsageRepository(file).recent(2, today);
      expect(broken.every((d) => d.total == 0), isTrue);
    });

    test('keeps at most $historyDays days', () async {
      final file = File('${dir.path}/usage.json');
      final repo = FileUsageRepository(file, flushEvery: 1000);
      for (var i = 0; i < historyDays + 5; i++) {
        await repo.add(dayKey(DateTime(2026, 1, 1).add(Duration(days: i))), const UsageDelta(wifiRx: 1));
      }
      await repo.flush();
      final text = file.readAsStringSync();
      expect(text.contains('2026-01-01'), isFalse);
      expect(RegExp(r'\d{4}-\d{2}-\d{2}').allMatches(text).length, historyDays);
    });
  });

  test('FileSettingsStore round trip and defaults', () async {
    final dir = Directory.systemTemp.createTempSync('tachyo_settings');
    final store = FileSettingsStore(File('${dir.path}/settings.json'));
    expect((await store.load()).unit, SpeedUnit.bits); // Kbps/Mbps by default
    await store.save(const AppSettings(unit: SpeedUnit.bytes, meterEnabled: true));
    expect((await store.load()).unit, SpeedUnit.bytes);
    await store.save(const AppSettings(unit: SpeedUnit.bits, meterEnabled: true));
    final loaded = await store.load();
    expect(loaded.unit, SpeedUnit.bits);
    expect(loaded.meterEnabled, isTrue);
    dir.deleteSync(recursive: true);
  });
}
