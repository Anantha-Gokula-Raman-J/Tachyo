import 'dart:convert';
import 'dart:io';

import '../core/format.dart';
import '../platform/native_bridge.dart';

class AppSettings {
  const AppSettings({
    this.unit = SpeedUnit.bits,
    this.meterEnabled = false,
    this.bootStart = true,
    this.alwaysOnTop = true,
    this.floatingMeter = true,
    this.scale = SpeedScale.auto,
  });

  /// Bits (Kbps, Mbps) by default, like ISP plans and speed tests.
  final SpeedUnit unit;

  /// Android: status-bar meter service. Windows: tray meter icon.
  final bool meterEnabled;

  /// Android: restart the status-bar meter after reboot.
  /// Windows: start in the tray at sign-in (HKCU Run entry, needs the tray meter).
  final bool bootStart;

  /// Windows only: keep the compact floating meter above other windows.
  final bool alwaysOnTop;

  /// Windows only: show the glass floating meter on the desktop (default on).
  final bool floatingMeter;

  /// Auto (B/s, KB/s, MB/s by size) or one fixed unit everywhere speeds show.
  final SpeedScale scale;

  AppSettings copyWith({SpeedUnit? unit, bool? meterEnabled, bool? bootStart, bool? alwaysOnTop, bool? floatingMeter, SpeedScale? scale}) =>
      AppSettings(
        unit: unit ?? this.unit,
        meterEnabled: meterEnabled ?? this.meterEnabled,
        bootStart: bootStart ?? this.bootStart,
        alwaysOnTop: alwaysOnTop ?? this.alwaysOnTop,
        floatingMeter: floatingMeter ?? this.floatingMeter,
        scale: scale ?? this.scale,
      );

  Map<String, Object> toMap() => {
        'unitBits': unit == SpeedUnit.bits,
        'meterEnabled': meterEnabled,
        'bootStart': bootStart,
        'alwaysOnTop': alwaysOnTop,
        'floatingMeter': floatingMeter,
        'speedScale': scale.index,
      };

  factory AppSettings.fromMap(Map<Object?, Object?> map) => AppSettings(
        unit: map['unitBits'] == false ? SpeedUnit.bytes : SpeedUnit.bits,
        meterEnabled: map['meterEnabled'] == true,
        bootStart: map['bootStart'] != false,
        alwaysOnTop: map['alwaysOnTop'] != false,
        floatingMeter: map['floatingMeter'] != false,
        scale: _scaleFrom(map['speedScale']),
      );
}

SpeedScale _scaleFrom(Object? v) =>
    v is int && v >= 0 && v < SpeedScale.values.length ? SpeedScale.values[v] : SpeedScale.auto;

abstract class SettingsStore {
  Future<AppSettings> load();
  Future<void> save(AppSettings settings);
}

/// Android: settings live in native SharedPreferences so the meter service
/// and boot receiver can read them without a Flutter engine.
class NativeSettingsStore implements SettingsStore {
  NativeSettingsStore(this._bridge);
  final NativeBridge _bridge;

  @override
  Future<AppSettings> load() async => AppSettings.fromMap(await _bridge.getSettings());

  @override
  Future<void> save(AppSettings settings) => _bridge.saveSettings(settings.toMap());
}

/// Windows: a JSON file next to the usage history.
class FileSettingsStore implements SettingsStore {
  FileSettingsStore(this.file);
  final File file;

  @override
  Future<AppSettings> load() async {
    try {
      if (!await file.exists()) return const AppSettings();
      final decoded = jsonDecode(await file.readAsString());
      return decoded is Map ? AppSettings.fromMap(decoded) : const AppSettings();
    } on Object {
      return const AppSettings(); // corrupt file -> defaults, never crash
    }
  }

  @override
  Future<void> save(AppSettings settings) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(settings.toMap()));
  }
}

class MemorySettingsStore implements SettingsStore {
  MemorySettingsStore([this.value = const AppSettings()]);
  AppSettings value;

  @override
  Future<AppSettings> load() async => value;

  @override
  Future<void> save(AppSettings settings) async => value = settings;
}
