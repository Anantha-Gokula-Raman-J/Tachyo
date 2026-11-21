# settings spec
Source: lib/src/data/settings_store.dart | Language: Dart | Commit: no-vcs | Generated: 2026-11-21

## 1. Overview
`AppSettings`: `unit` (bytes|bits), `meterEnabled` (Android status-bar service /
Windows tray icon), `bootStart` (Android: restart after reboot; Windows: start in tray at sign-in), `alwaysOnTop` and `floatingMeter` (Windows glass floating meter: on-top, shown — default on), `scale` (Speed format: Auto default or a fixed unit, stored as int `speedScale`).
Wire keys: `unitBits`, `meterEnabled`, `bootStart`, `alwaysOnTop`, `floatingMeter` (booleans), `speedScale` (int 0..3) – shared
with Kotlin `Prefs` (Prefs.kt:6).

## 2. APIs and Use Cases
| API | Entry point (file:line) | Use case |
| --- | --- | --- |
| `AppSettings.toMap/fromMap` | lib/src/data/settings_store.dart:34,41 | encode for file/channel |
| `SettingsStore.load/save` | lib/src/data/settings_store.dart:50-51 | read/write |
| `NativeSettingsStore` | lib/src/data/settings_store.dart:56 | Android via `getSettings/saveSettings` |
| `FileSettingsStore` | lib/src/data/settings_store.dart:68 | Windows `settings.json` |

## 3. Data Flows
- Startup: `MeterController.start -> SettingsStore.load -> AppSettings.fromMap`
- Change: `SettingsPage onChanged -> MeterController.updateSettings -> SettingsStore.save -> AppSettings.toMap`
- Android service reads unit each notification: `MeterService.buildNotification -> Prefs.unitBits`

## 4. Entry Points
| Entry point (method) | Usage summary | Input parameters |
| --- | --- | --- |
| `SettingsStore.load` | defaults when missing | – |
| `SettingsStore.save` | full overwrite | `AppSettings settings` |

## 5. Edge Cases
- Missing/corrupt settings file -> defaults (settings_store.dart:74-81).
- Defaults: bits (Kbps/Mbps; `unitBits` missing -> bits, only an explicit `false` means bytes; Android `Prefs.unitBits` default true), meter off, bootStart on, alwaysOnTop on (`!= false` reads), floatingMeter on (`!= false` read; Android stores it but never uses it), speedScale 0 = Auto (out-of-range -> Auto) (settings_store.dart:41-46).
- Android `Prefs.save` stores only boolean values (Prefs.kt:23).

## 6. History
| Date | Commit | Change | Affected methods |
| --- | --- | --- | --- |
| 2026-11-21 | no-vcs | Initial spec | all |
| 2026-11-21 | no-vcs | Added floatingMeter; bootStart also drives the Windows sign-in entry | AppSettings |
| 2026-11-21 | no-vcs | floatingMeter default on; speedScale | AppSettings |
| 2026-11-21 | no-vcs | Default unit bits (Kbps/Mbps) | AppSettings, AppSettings.fromMap, Prefs.unitBits |
