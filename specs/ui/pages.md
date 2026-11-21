# pages spec
Source: lib/src/ui/app.dart, lib/src/ui/pages/*, lib/src/ui/widgets/widgets.dart | Language: Dart | Commit: no-vcs | Generated: 2026-11-21

## 1. Overview
- **Live**: download/upload tiles with peaks, 60 s chart, Today by connection, session totals + Reset, meter switch (Android only; the Windows tray meter is always on).
- **Usage**: 7- and 30-day totals, daily stacked bars (Wi-Fi + Mobile on Android, Wi-Fi + Ethernet on Windows), pull to refresh, hint when background counting is off (Android).
- **Test**: internet speed test (see `speedtest/controller.md`).
- **Settings**: units (bytes/bits), Speed format (Auto default, or fixed B/s · KB/s · MB/s), meter switch (Android), Start after reboot / Start with Windows, Floating meter + Keep on top (Windows), tray note (Windows), About + Licenses.
- The Windows floating meter is native (`platform/windows-native.md`), not a Flutter page.

## 2. APIs and Use Cases
| API | Entry point (file:line) | Use case |
| --- | --- | --- |
| `TachyoApp.build` | lib/src/ui/app.dart:20 | theme + HomeShell |
| `_HomeShellState.build` | lib/src/ui/app.dart:64 | app bar, tabs, max width 720 |
| `_HomeShellState.didChangeAppLifecycleState` | lib/src/ui/app.dart:56 | flush on pause, refresh on resume |
| `LivePage.build` | lib/src/ui/pages/live_page.dart:13 | Live tab |
| `UsagePage.build` | lib/src/ui/pages/usage_page.dart:16 | Usage tab |
| `SettingsPage.build` | lib/src/ui/pages/settings_page.dart:15 | Settings tab |
| `SpeedTestPage` | lib/src/ui/pages/speed_test_page.dart | Test tab |
| `SpeedChart` / `_ChartPainter.paint` | lib/src/ui/widgets/widgets.dart:102,161 | two-series chart, right aligned |

## 3. Data Flows
- Meter toggle: `_MeterBanner Switch.onChanged -> MeterController.setMeterEnabled`
- Units: `SettingsPage SegmentedButton.onSelectionChanged -> MeterController.updateSettings`
- Speed format: `SettingsPage SegmentedButton<SpeedScale> -> MeterController.updateSettings -> SpeedTile(scale) / WindowsMeterPlatform.onSample / Android Prefs.speedScale`
- Floating meter (Windows): `SettingsPage floating-switch -> MeterController.updateSettings -> WindowsMeterPlatform.applySettings -> NativeBridge.setFloating`

## 4. Entry Points
| Entry point (method) | Usage summary | Input parameters |
| --- | --- | --- |
| `TachyoApp(controller, speedTest)` | root widget | `MeterController`, `SpeedTestController` |
| `LivePage/UsagePage/SettingsPage(controller)` | stateless views | `MeterController` |

## 5. Edge Cases
- Before `ready` -> spinner (app.dart).
- Chart with < 2 samples or max 0 -> grid only (widgets.dart:171).
- Values use `FittedBox` so long values never overflow narrow phones.
- Keys used by tests: `download-tile`, `upload-tile`, `meter-switch`, `scale-picker`, `floating-switch`, `boot-switch`.
- Speed-format labels follow the unit (bps/Kbps/Mbps for bits).
- Tests: test/app_test.dart `pages render and settings change unit and speed format`.

## 6. History
| Date | Commit | Change | Affected methods |
| --- | --- | --- | --- |
| 2026-11-21 | no-vcs | Initial spec | all |
| 2026-11-21 | no-vcs | Whole meter card toggles (InkWell) – accessibility merges it into one switch node | _MeterBanner.build |
| 2026-11-21 | no-vcs | Test tab, Speed format picker, Windows floating-meter switches; CompactMeter removed | HomeShell, SettingsPage, SpeedTestPage |
