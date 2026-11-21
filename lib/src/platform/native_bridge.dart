import 'package:flutter/services.dart';

import '../core/models.dart';

/// Reads cumulative OS byte counters.
abstract class NetSource {
  Future<NetCounters> read();
}

/// The single method channel to the native side.
///
/// Android: android/app/src/main/kotlin/.../MainActivity.kt
/// Windows: windows/runner/native_bridge.cpp
/// The method names below are the shared contract (specs/platform/channel.md).
class NativeBridge implements NetSource {
  NativeBridge([MethodChannel? channel]) : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'app.tachyo/native';
  final MethodChannel _channel;

  @override
  Future<NetCounters> read() async {
    final map = await _channel.invokeMapMethod<Object?, Object?>('getCounters');
    return NetCounters.fromMap(map ?? const {});
  }

  // ---- Android ----
  Future<bool> startMeter() async => await _channel.invokeMethod<bool>('startMeter') ?? false;
  Future<void> stopMeter() => _channel.invokeMethod<void>('stopMeter');
  Future<bool> isMeterRunning() async => await _channel.invokeMethod<bool>('isMeterRunning') ?? false;
  Future<bool> requestNotificationPermission() async =>
      await _channel.invokeMethod<bool>('requestNotificationPermission') ?? true;

  Future<List<DailyUsage>> dailyUsage(int days) async {
    final list = await _channel.invokeListMethod<Object?>('getDailyUsage', {'days': days});
    return (list ?? const [])
        .whereType<Map<Object?, Object?>>()
        .map(DailyUsage.fromMap)
        .toList();
  }

  Future<void> addUsage(String date, UsageDelta delta) =>
      _channel.invokeMethod<void>('addUsage', {'date': date, ...delta.toMap()});

  Future<Map<Object?, Object?>> getSettings() async =>
      await _channel.invokeMapMethod<Object?, Object?>('getSettings') ?? const {};

  Future<void> saveSettings(Map<String, Object> values) =>
      _channel.invokeMethod<void>('saveSettings', values);

  // ---- Windows ----
  Future<void> setTray(bool enabled) => _channel.invokeMethod<void>('setTray', {'enabled': enabled});
  Future<void> updateTray(String down, String up, String tooltip) =>
      _channel.invokeMethod<void>('updateTray', {'down': down, 'up': up, 'tooltip': tooltip});
  Future<void> quit() => _channel.invokeMethod<void>('quit');
  Future<void> setFloating({required bool enabled, required bool onTop}) =>
      _channel.invokeMethod<void>('setFloating', {'enabled': enabled, 'onTop': onTop});
  Future<void> updateFloating(String down, String up) =>
      _channel.invokeMethod<void>('updateFloating', {'down': down, 'up': up});
  Future<bool> setAutoStart(bool enabled) async =>
      await _channel.invokeMethod<bool>('setAutoStart', {'enabled': enabled}) ?? false;
  Future<void> showWindow() => _channel.invokeMethod<void>('showWindow');

  // ---- Android ----
  /// App-private files folder (Context.filesDir) for the speed test history.
  Future<String> dataDir() async => await _channel.invokeMethod<String>('getDataDir') ?? '';

  /// Native -> Dart calls (Windows tray menu and floating meter: "open", "toggleFloating",
  /// "toggleAutoStart", "flush", "exit").
  void onNativeCall(void Function(String method, Object? args) handler) {
    _channel.setMethodCallHandler((call) async => handler(call.method, call.arguments));
  }
}
