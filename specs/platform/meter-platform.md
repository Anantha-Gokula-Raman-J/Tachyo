# meter-platform spec
Source: lib/src/platform/meter_platform.dart | Language: Dart | Commit: no-vcs | Generated: 2026-11-21

## 1. Overview
`MeterPlatform` hides OS differences from the controller and UI: data stores,
labels, capabilities and the background meter. `AndroidMeterPlatform` = status-bar
foreground service; `WindowsMeterPlatform` = tray icon + floating meter.

## 2. APIs and Use Cases
| API | Entry point (file:line) | Use case |
| --- | --- | --- |
| `recordsUsageInApp` | lib/src/platform/meter_platform.dart:34 | single-writer rule for usage |
| `setMeterEnabled` | lib/src/platform/meter_platform.dart:30 | toggle background meter |
| `onSample` | lib/src/platform/meter_platform.dart:37 | per-sample hook (tray refresh) |
| `quit/onNativeAction` | lib/src/platform/meter_platform.dart | Windows exit + tray actions |
| `supportsFloating` / `meterAlwaysOn` / `speedTests` | lib/src/platform/meter_platform.dart:26-33 | Windows floating meter, always-on tray, speed test history |
| `applySettings` / `showWindow` / `bootStartLabel` | lib/src/platform/meter_platform.dart | Windows: sync sign-in entry, reveal window; per-platform boot-start wording |
| `WindowsMeterPlatform.defaultDataDir` | lib/src/platform/meter_platform.dart:95 | `%APPDATA%\Tachyo` |

## 3. Data Flows
- Android enable: `MeterController.setMeterEnabled -> AndroidMeterPlatform.setMeterEnabled -> NativeBridge.requestNotificationPermission -> NativeBridge.startMeter`
- Windows enable: `MeterController.setMeterEnabled -> WindowsMeterPlatform.setMeterEnabled -> NativeBridge.setTray`
- Tray + floating refresh: `MeterController.tick -> WindowsMeterPlatform.onSample -> formatSpeed(unit, scale) -> NativeBridge.updateFloating; compactSpeed(unit, scale) -> NativeBridge.updateTray`
- Settings side effects (Windows): `WindowsMeterPlatform.applySettings -> NativeBridge.setAutoStart(bootStart) + NativeBridge.setFloating(floatingMeter, alwaysOnTop)`

## 4. Entry Points
| Entry point (method) | Usage summary | Input parameters |
| --- | --- | --- |
| `AndroidMeterPlatform(bridge)` | native stores | `NativeBridge` |
| `WindowsMeterPlatform(bridge, dir)` | file stores in dir | `NativeBridge`, `Directory` |
| `recordsUsageInApp` | Android: `!meterRunning`; Windows: always | `meterRunning` |

## 5. Edge Cases
- Android: notification denied -> service still starts; icon not shown (OS rule). Meter state comes from `MeterService.running`.
- Windows: `isMeterRunning` reflects this process's tray state only; tray re-enabled at start when `meterEnabled` saved.
- Windows `onSample` does nothing while tray is off.
- Labels: Android other="Other", Windows other="Ethernet"; `hasMobile` false on Windows.

## 6. History
| Date | Commit | Change | Affected methods |
| --- | --- | --- | --- |
| 2026-11-21 | no-vcs | Initial spec | all |
| 2026-11-21 | no-vcs | Windows supportsBootStart = true (Start with Windows); applySettings, showWindow; data dir %APPDATA%\Tachyo | WindowsMeterPlatform |
| 2026-11-21 | no-vcs | Windows: tray always on (meterAlwaysOn), floating meter via setFloating/updateFloating, sign-in = bootStart; speedTests history on both | WindowsMeterPlatform, AndroidMeterPlatform |
