# platform module spine
Source: lib/src/platform, android/app/src/main, windows/runner | Language: Dart, Kotlin, C++ | Commit: no-vcs | Generated: 2026-11-21

## Responsibility
Everything OS-specific. One method channel `app.tachyo/native`
(no third-party plugins), a `MeterPlatform` abstraction with Android and Windows
implementations, and the native code on each side.

## Shared types
| Type | File:line |
| --- | --- |
| `NetSource` | lib/src/platform/native_bridge.dart:6 |
| `NativeBridge` (Dart) | lib/src/platform/native_bridge.dart:15 |
| `MeterPlatform` | lib/src/platform/meter_platform.dart:11 |
| `MainActivity` (Kotlin channel) | android/app/src/main/kotlin/app/tachyo/MainActivity.kt:15 |
| `NativeBridge` (C++ channel) | windows/runner/native_bridge.cpp:86 |

## Submodules
- `channel.md` – method contract (both directions).
- `meter-platform.md` – Dart platform abstraction and the per-OS policies.
- `android-native.md` – TrafficStats, MeterService (status bar), UsageStore, Prefs, BootReceiver.
- `windows-native.md` – GetIfTable2 counters, tray icon (always on), glass floating meter, close-to-tray, start with Windows, exit.

## Cross-module flows
- `main -> AndroidMeterPlatform|WindowsMeterPlatform -> MeterController` (lib/main.dart:12).
- Windows tray menu -> `trayAction` -> `MeterController._onNativeAction`.

## Calls into other modules
core (models, format), data (repositories, stores).
