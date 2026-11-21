# Tachyo architecture

Product: **Tachyo – Net Speed Meter**. Targets: Android, Windows.
Everything is free; no telemetry, usage data stays on the device. The only network traffic is a speed test
the user starts (Cloudflare public endpoints, see specs/speedtest).

## Layers
```
UI (lib/src/ui)            Live · Usage · Test · Settings   ← Astryx tokens (ThemeExtension)
  │ ListenableBuilder
State (lib/src/state)      MeterController: 1 s tick, history(60), peaks, session, usage(30 d)
Speed test (lib/src/speedtest) SpeedTestController → SpeedTestEngine → HttpSpeedTestTransport (dart:io)
  │
Platform (lib/src/platform) MeterPlatform ─┬─ AndroidMeterPlatform → NativeUsageRepository / NativeSettingsStore
  │                                        └─ WindowsMeterPlatform → FileUsageRepository / FileSettingsStore (%APPDATA%)
  │ MethodChannel "app.tachyo/native"
Native  Android (Kotlin): MainActivity · TrafficReader · MeterService (foreground, status-bar icon) · UsageStore · Prefs · BootReceiver
        Windows (C++):    NativeBridge (GetIfTable2 · tray icon · close-to-tray · sign-in entry · exit handshake)
                          FloatingMeter (layered glass window · adaptive text · always in front)
Core (lib/src/core)         NetCounters · SpeedSampler · DailyUsage · format (pure Dart, unit-tested)
```

## Module catalog
| Module | Path | Spec |
| --- | --- | --- |
| core | lib/src/core | specs/core/common/README.md |
| data | lib/src/data | specs/data/common/README.md |
| platform | lib/src/platform, android/app/src/main, windows/runner | specs/platform/common/README.md |
| state | lib/src/state | specs/state/common/README.md |
| ui | lib/src/ui | specs/ui/common/README.md |
| speedtest | lib/src/speedtest | specs/speedtest/common/README.md |

## API catalog (platform channel)
See `specs/platform/channel.md` – getCounters, startMeter, stopMeter, isMeterRunning,
requestNotificationPermission, getDailyUsage, addUsage, getSettings, saveSettings, getDataDir (Android);
getCounters, setTray, updateTray, setFloating, updateFloating, setAutoStart, showWindow, quit, ←trayAction (Windows).

## Key decisions
1. **No third-party packages.** License policy allows only MIT/Apache-2.0; platform features are written natively instead of via plugins. Only the Flutter SDK is used.
2. **Single usage writer.** Android: the meter service writes while it runs, otherwise the app. Windows: the app (it keeps running in the tray).
3. **Spike safety.** Dart drops intervals where totals go backwards; Windows accumulates per-adapter deltas so new adapters start at zero.
4. **Status-bar visibility.** Android channel is IMPORTANCE_DEFAULT but silent – LOW importance icons are hidden from the status bar.
. **Windows lives in the tray.** Tray icon always on; closing hides the window; only tray Exit quits. The floating meter is a native layered window so it survives a hidden app window.
7. **Speed format.** Auto (default) or one fixed unit, applied to every speed shown (app, floating meter, tray, Android notification).

## Testing
- `flutter test` – core math, formatting, file stores, controller rules, widget smoke (19 tests).
- Windows smoke: `tool/win_drive.ps1` (click + screenshot of the running build).
- Android: `harness/android_test.ps1 -Wipe` (wipe emulator, install, status-bar check, reboot check).

## Production readiness gaps
- Release signing (Android keystore, Windows code signing/MSIX) not configured – APK is debug-signed.
- Play Store listing must justify the `specialUse` foreground service.
- No localization yet (English only).
