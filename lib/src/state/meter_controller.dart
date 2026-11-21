import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/models.dart';
import '../core/sampler.dart';
import '../data/settings_store.dart';
import '../platform/meter_platform.dart';

/// App state: samples the counters once per [interval], keeps a short speed
/// history, accumulates usage and mirrors the platform meter.
class MeterController extends ChangeNotifier {
  MeterController(
    this.platform, {
    this.interval = const Duration(seconds: 1),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static const historyLength = 60;
  static const usageDays = 30;

  final MeterPlatform platform;
  final Duration interval;
  final DateTime Function() _clock;
  final SpeedSampler _sampler = SpeedSampler();

  Timer? _timer;
  bool _ticking = false;
  int _tickCount = 0;
  bool _disposed = false;

  AppSettings settings = const AppSettings();
  SpeedSample current = SpeedSample.zero;
  final List<SpeedSample> history = [];
  double peakDown = 0;
  double peakUp = 0;
  int sessionRx = 0;
  int sessionTx = 0;
  bool meterRunning = false;
  bool ready = false;
  String? error;
  List<DailyUsage> days = [];

  DailyUsage get today => days.isNotEmpty ? days.first : DailyUsage(date: dayKey(_clock()));

  /// [background]: Windows sign-in start. The window stays hidden; only the
  /// tray icon and (if enabled) the floating meter appear.
  Future<void> start({bool background = false}) async {
    try {
      settings = await platform.settings.load();
      meterRunning = await platform.isMeterRunning();
      if ((settings.meterEnabled || platform.meterAlwaysOn) && !meterRunning) {
        meterRunning = await platform.setMeterEnabled(true);
      }
      await platform.applySettings(settings, meterRunning: meterRunning);
      await refreshUsage();
    } on Object catch (e) {
      error = 'Could not load saved data: $e';
    }
    platform.onNativeAction(_onNativeAction);
    ready = true;
    _notify();
    if (background && !meterRunning) {
      await platform.showWindow(); // nothing else would be visible
    }
    await tick();
    _timer = Timer.periodic(interval, (_) => tick());
  }

  /// One sampling step. Public for tests.
  Future<void> tick() async {
    if (_ticking || _disposed) return; // never overlap slow platform reads
    _ticking = true;
    try {
      final counters = await platform.source.read();
      final result = _sampler.push(counters);
      if (result != null) {
        _apply(result);
        final key = dayKey(_clock());
        if (platform.recordsUsageInApp(meterRunning: meterRunning)) {
          await platform.usage.add(key, result.delta);
          _addToToday(key, result.delta);
        }
        await platform.onSample(current, settings, today);
      }
      _tickCount++;
      // The Android service writes usage on its own; re-read it periodically.
      if (!platform.recordsUsageInApp(meterRunning: meterRunning) && _tickCount % 5 == 0) {
        await refreshUsage();
      }
      error = null;
    } on Object catch (e) {
      error = 'Reading network counters failed: $e';
    }
    _ticking = false;
    _notify();
  }

  void _apply(SampleResult r) {
    current = r.speed;
    history.add(r.speed);
    if (history.length > historyLength) history.removeAt(0);
    if (r.speed.downBps > peakDown) peakDown = r.speed.downBps;
    if (r.speed.upBps > peakUp) peakUp = r.speed.upBps;
    sessionRx += r.delta.wifiRx + r.delta.mobileRx + r.delta.otherRx;
    sessionTx += r.delta.wifiTx + r.delta.mobileTx + r.delta.otherTx;
  }

  void _addToToday(String key, UsageDelta delta) {
    if (days.isEmpty || days.first.date != key) {
      // Day rolled over at midnight: start a fresh record at the head.
      days.insert(0, DailyUsage(date: key));
      if (days.length > usageDays) days.removeLast();
    }
    days.first.add(delta);
  }

  Future<void> refreshUsage() async {
    days = await platform.usage.recent(usageDays, _clock());
    _notify();
  }

  Future<void> updateSettings(AppSettings next) async {
    settings = next;
    _notify();
    await platform.settings.save(next);
    await platform.applySettings(next, meterRunning: meterRunning);
  }

  Future<void> setMeterEnabled(bool enabled) async {
    meterRunning = await platform.setMeterEnabled(enabled);
    await updateSettings(settings.copyWith(meterEnabled: meterRunning));
    await platform.usage.flush();
    await refreshUsage();
  }

  void resetSession() {
    peakDown = peakUp = 0;
    sessionRx = sessionTx = 0;
    history.clear();
    _notify();
  }

  Future<void> _onNativeAction(String action) async {
    // Tray menu / floating meter (Windows). "open" needs nothing here: the
    // native side already showed the window.
    if (action == 'toggleFloating') await updateSettings(settings.copyWith(floatingMeter: !settings.floatingMeter));
    if (action == 'toggleAutoStart') await updateSettings(settings.copyWith(bootStart: !settings.bootStart));
    if (action == 'flush') await platform.usage.flush(); // Windows sign-out / shutdown
    if (action == 'exit') {
      _timer?.cancel();
      await platform.usage.flush(); // never lose the last seconds of usage
      await platform.quit();
    }
  }

  Future<void> pause() => platform.usage.flush();

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    platform.usage.flush();
    super.dispose();
  }
}
