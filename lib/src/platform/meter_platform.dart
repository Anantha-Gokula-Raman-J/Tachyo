import 'dart:io';

import '../core/format.dart';
import '../core/models.dart';
import '../data/settings_store.dart';
import '../data/usage_repository.dart';
import '../speedtest/history.dart';
import 'native_bridge.dart';

/// Everything that differs between Android and Windows, behind one interface
/// so the controller and UI stay platform-neutral and testable.
abstract class MeterPlatform {
  NetSource get source;
  UsageRepository get usage;
  SettingsStore get settings;

  /// Label for the always-visible meter: "Status bar meter" / "Tray meter".
  String get meterLabel;
  String get meterDescription;

  /// Name used for non-Wi-Fi, non-mobile traffic ("Ethernet" on Windows).
  String get otherLabel;
  bool get hasMobile;
  bool get supportsBootStart;
  String get bootStartLabel => 'Start after reboot';
  String get bootStartDescription => 'Bring the status bar meter back when the phone restarts';
  /// Windows: the desktop floating meter (native glass window).
  bool get supportsFloating => false;

  /// True when the always-visible meter cannot be switched off (Windows tray).
  bool get meterAlwaysOn => false;

  /// Saved speed test results.
  SpeedTestHistory get speedTests;

  /// Whether the background meter is currently running (Android service).
  Future<bool> isMeterRunning();

  /// Turns the always-visible meter on/off. Returns the resulting state.
  Future<bool> setMeterEnabled(bool enabled);

  /// True when the app process itself must record usage. On Android the
  /// meter service records usage whenever it runs, so the app must not.
  bool recordsUsageInApp({required bool meterRunning});

  /// Called once per sample (Windows: refresh the tray icon).
  Future<void> onSample(SpeedSample sample, AppSettings settings, DailyUsage today) async {}

  Future<void> quit() async {}

  /// Applies OS-level side effects of settings (Windows: sign-in entry,
  /// floating meter on/off and on-top).
  Future<void> applySettings(AppSettings settings, {required bool meterRunning}) async {}

  /// Reveals the main window (Windows background start with nothing to show).
  Future<void> showWindow() async {}

  void onNativeAction(void Function(String action) handler) {}
}

class AndroidMeterPlatform extends MeterPlatform {
  AndroidMeterPlatform(this.bridge)
      : usage = NativeUsageRepository(bridge),
        settings = NativeSettingsStore(bridge),
        speedTests = FileSpeedTestHistory.lazy(() async => File('${await bridge.dataDir()}/speedtests.json'));

  final NativeBridge bridge;
  @override
  final UsageRepository usage;
  @override
  final SettingsStore settings;
  @override
  final SpeedTestHistory speedTests;

  @override
  NetSource get source => bridge;
  @override
  String get meterLabel => 'Status bar meter';
  @override
  String get meterDescription => 'Live speed in the status bar and notification shade';
  @override
  String get otherLabel => 'Other';
  @override
  bool get hasMobile => true;
  @override
  bool get supportsBootStart => true;

  @override
  Future<bool> isMeterRunning() => bridge.isMeterRunning();

  @override
  Future<bool> setMeterEnabled(bool enabled) async {
    if (!enabled) {
      await bridge.stopMeter();
      return false;
    }
    await bridge.requestNotificationPermission();
    return bridge.startMeter();
  }

  @override
  bool recordsUsageInApp({required bool meterRunning}) => !meterRunning;
}

class WindowsMeterPlatform extends MeterPlatform {
  WindowsMeterPlatform(this.bridge, Directory dataDir)
      : usage = FileUsageRepository(File('${dataDir.path}${Platform.pathSeparator}usage.json')),
        settings = FileSettingsStore(File('${dataDir.path}${Platform.pathSeparator}settings.json')),
        speedTests = FileSpeedTestHistory(File('${dataDir.path}${Platform.pathSeparator}speedtests.json'));

  /// %APPDATA%\Tachyo
  static Directory defaultDataDir() {
    final base = Platform.environment['APPDATA'] ?? Directory.systemTemp.path;
    final sep = Platform.pathSeparator;
    return Directory('$base${sep}Tachyo');
  }

  final NativeBridge bridge;
  @override
  final UsageRepository usage;
  @override
  final SettingsStore settings;
  @override
  final SpeedTestHistory speedTests;
  bool _trayOn = false;

  @override
  NetSource get source => bridge;
  @override
  String get meterLabel => 'Tray meter';
  @override
  String get meterDescription => 'Live speed in the taskbar tray; closing the window keeps it running';
  @override
  bool get meterAlwaysOn => true;
  @override
  String get bootStartLabel => 'Start with Windows';
  @override
  String get bootStartDescription => 'Start in the tray when you sign in, with no window open';
  @override
  String get otherLabel => 'Ethernet';
  @override
  bool get hasMobile => false;
  @override
  bool get supportsBootStart => true;
  @override
  bool get supportsFloating => true;

  @override
  Future<bool> isMeterRunning() async => _trayOn;

  /// The tray icon is always on while Tachyo runs on Windows; only the tray
  /// menu's Exit quits.
  @override
  Future<bool> setMeterEnabled(bool enabled) async {
    await bridge.setTray(true);
    return _trayOn = true;
  }

  @override
  bool recordsUsageInApp({required bool meterRunning}) => true;

  @override
  Future<void> onSample(SpeedSample sample, AppSettings settings, DailyUsage today) async {
    final unit = settings.unit;
    final scale = settings.scale;
    final down = formatSpeed(sample.downBps, unit, scale);
    final up = formatSpeed(sample.upBps, unit, scale);
    if (settings.floatingMeter) await bridge.updateFloating(down.toString(), up.toString());
    if (!_trayOn) return;
    final iconDown = compactSpeed(sample.downBps, unit, scale);
    final iconUp = compactSpeed(sample.upBps, unit, scale);
    final tip = 'Tachyo\n↓ $down   ↑ $up\nToday ${formatBytes(today.total)}';
    await bridge.updateTray(iconDown.value, iconUp.value, tip);
  }

  @override
  Future<void> applySettings(AppSettings settings, {required bool meterRunning}) async {
    await bridge.setAutoStart(settings.bootStart);
    await bridge.setFloating(enabled: settings.floatingMeter, onTop: settings.alwaysOnTop);
  }

  @override
  Future<void> showWindow() => bridge.showWindow();

  @override
  Future<void> quit() => bridge.quit();

  @override
  void onNativeAction(void Function(String action) handler) {
    bridge.onNativeCall((method, args) {
      if (method == 'trayAction' && args is String) handler(args);
    });
  }
}
