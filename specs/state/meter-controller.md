# meter-controller spec
Source: lib/src/state/meter_controller.dart | Language: Dart | Commit: no-vcs | Generated: 2026-11-21

## 1. Overview
Drives everything the UI shows. Samples once per `interval` (1 s), never overlapping
reads. Records usage only when `MeterPlatform.recordsUsageInApp` says so (single
writer rule). Constants: `historyLength` 60, `usageDays` 30.

## 2. APIs and Use Cases
| API | Entry point (file:line) | Use case |
| --- | --- | --- |
| `start` | lib/src/state/meter_controller.dart:47 | load settings/usage, restore meter, start timer |
| `tick` | lib/src/state/meter_controller.dart:66 | one sample (public for tests) |
| `refreshUsage` | lib/src/state/meter_controller.dart:113 | reload 30 days |
| `updateSettings` | lib/src/state/meter_controller.dart:118 | persist settings |
| `setMeterEnabled` | lib/src/state/meter_controller.dart:124 | toggle background meter |
| `resetSession` | lib/src/state/meter_controller.dart:137 | clear peaks/session/history |
| `pause` | lib/src/state/meter_controller.dart:154 | flush on app pause |

## 3. Data Flows
- Startup: `main -> MeterController.start -> SettingsStore.load -> MeterPlatform.isMeterRunning -> MeterPlatform.setMeterEnabled (if saved on) -> MeterController.refreshUsage -> MeterController.tick`
- Sample (recording): `MeterController.tick -> NetSource.read -> SpeedSampler.push -> MeterController._apply -> UsageRepository.add -> MeterController._addToToday -> MeterPlatform.onSample`
- Sample (Android service running): `MeterController.tick -> ... -> MeterController.refreshUsage (every 5 ticks)`
- Tray action: `NativeBridge.onNativeCall -> MeterController._onNativeAction -> updateSettings (toggleFloating | toggleAutoStart) | UsageRepository.flush (flush) | UsageRepository.flush + MeterPlatform.quit (exit)`
- Start: `MeterController.start -> setMeterEnabled(true) when meterEnabled or platform.meterAlwaysOn (Windows tray) -> MeterPlatform.applySettings`; background start with no visible meter -> `MeterPlatform.showWindow`
- Settings change: `MeterController.updateSettings -> SettingsStore.save -> MeterPlatform.applySettings` (Windows: Run entry = bootStart && tray on)

## 4. Entry Points
| Entry point (method) | Usage summary | Input parameters |
| --- | --- | --- |
| `MeterController(platform, interval, clock)` | DI for tests | `MeterPlatform`, `Duration`, `DateTime Function()` |
| `start` | call once | – |
| `tick` | guarded by `_ticking` | – |
| `setMeterEnabled` | flush + refresh afterwards | `bool` |

## 5. Edge Cases
- Overlapping ticks skipped (`_ticking`) (meter_controller.dart:67).
- Read failures set `error` text and keep the loop alive (meter_controller.dart:88-90).
- Load failure at start -> error text, defaults kept (meter_controller.dart:55-57).
- Midnight in-app: a new head record is inserted when the day key changes (meter_controller.dart:104-110).
- Android with service running: app never writes usage (no double counting).
- `dispose` cancels timer and flushes.
- Tests: test/app_test.dart (recording, single-writer, settings, widget smoke).

- trayAction "flush" (Windows sign-out/shutdown) flushes usage without quitting.

## 6. History
| Date | Commit | Change | Affected methods |
| --- | --- | --- | --- |
| 2026-11-21 | no-vcs | Initial spec | all |
| 2026-11-21 | no-vcs | start(background), applySettings hook, floatingMeter persistence, flush action | start, updateSettings, setCompact, _onNativeAction |
| 2026-11-21 | no-vcs | Compact mode removed; Windows tray always on; tray toggles for floating meter and sign-in | start, _onNativeAction |
