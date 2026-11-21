# channel spec
Source: lib/src/platform/native_bridge.dart, MainActivity.kt, windows/runner/native_bridge.cpp | Language: Dart/Kotlin/C++ | Commit: no-vcs | Generated: 2026-11-21

## 1. Overview
Shared contract for `MethodChannel('app.tachyo/native')`
(StandardMethodCodec). Any change must update Dart, Kotlin and C++ together and this table.

## 2. APIs and Use Cases
| Method | Dir | Platforms | Args | Reply |
| --- | --- | --- | --- | --- |
| getCounters | D→N | A, W | – | map rx, tx, wifiRx, wifiTx, mobileRx, mobileTx (int64), t (ms, monotonic) |
| startMeter | D→N | A | – | bool |
| stopMeter | D→N | A | – | null |
| isMeterRunning | D→N | A | – | bool |
| requestNotificationPermission | D→N | A | – | bool granted (true below API 33) |
| getDailyUsage | D→N | A | days:int | list of map date, wifiRx..otherTx (stored days only, newest first) |
| addUsage | D→N | A | date + wifiRx, wifiTx, mobileRx, mobileTx, otherRx, otherTx | null (other folded into Wi-Fi) |
| getSettings / saveSettings | D→N | A | map: bools unitBits, meterEnabled, bootStart, alwaysOnTop, floatingMeter; int speedScale | map / null |
| getDataDir | D→N | A | – | app files folder (speed test history) |
| setTray | D→N | W | enabled:bool | null |
| updateTray | D→N | W | down, up (short values), tooltip | null |
| setFloating | D→N | W | enabled:bool, onTop:bool | null |
| updateFloating | D→N | W | down, up (full labels, e.g. "94.1 Kbps") | null |
| setAutoStart | D→N | W | enabled:bool | bool (HKCU Run entry written/removed) |
| showWindow | D→N | W | – | null (reveal main window) |
| quit | D→N | W | – | null, then window destroyed |
| trayAction | N→D | W | "open" / "toggleFloating" / "toggleAutoStart" / "flush" / "exit" | – |

Dart side: lib/src/platform/native_bridge.dart. Kotlin: MainActivity.kt. C++: native_bridge.cpp:90.

## 3. Data Flows
- Counters: `MeterController.tick -> NativeBridge.read -> [Kotlin TrafficReader.read | C++ NativeBridge::ReadCounters] -> NetCounters.fromMap`
- Exit (Windows): `NativeBridge::ShowTrayMenu -> NativeBridge::RequestExit -> trayAction("exit") -> MeterController._onNativeAction -> UsageRepository.flush -> NativeBridge.quit -> DestroyWindow`
- Tray toggles (Windows): `NativeBridge::ShowTrayMenu -> trayAction("toggleFloating" | "toggleAutoStart") -> MeterController.updateSettings -> WindowsMeterPlatform.applySettings -> setFloating / setAutoStart`
- Sign-in start (Windows): `HKCU Run "tachyo.exe --background" -> wWinMain (window kept hidden) -> main(args) -> MeterController.start(background)` -> tray icon + floating meter only
- Sign-out/shutdown (Windows): `WM_QUERYENDSESSION -> trayAction("flush") -> UsageRepository.flush`
- Speed test history (Android): `FileSpeedTestHistory.lazy -> NativeBridge.dataDir -> getDataDir -> Context.filesDir`

## 4. Entry Points
| Entry point (method) | Usage summary | Input parameters |
| --- | --- | --- |
| `NativeBridge.read` (Dart) | `getCounters` | – |
| `NativeBridge.onNativeCall` (Dart) | receives `trayAction` | handler |
| `MainActivity.handle` (Kotlin) | dispatch by method name | MethodCall |
| `NativeBridge::HandleCall` (C++) | dispatch by method name | MethodCall |

## 5. Edge Cases
- Unknown method -> notImplemented on both sides.
- Kotlin exceptions -> `result.error("native_error")`; Dart controller surfaces it as `error` text.
- Windows counters start at 0 and only grow (accumulated deltas), Android counters are since boot; Dart only uses differences.
- Windows `quit` fallback: native destroys the window 1.5 s after "exit" if Dart never calls quit.
- `saveSettings` on Android stores Booleans and Numbers (as Int); other types are ignored.
- trayAction "open" needs no Dart work (native already showed the window). Unknown values are ignored.

## 6. History
| Date | Commit | Change | Affected methods |
| --- | --- | --- | --- |
| 2026-11-21 | no-vcs | Initial contract | all |
| 2026-11-21 | no-vcs | Rebrand to app.tachyo channel; setAutoStart, showWindow, trayAction flush | HandleCall, _onNativeAction |
| 2026-11-21 | no-vcs | Removed setCompact/setAlwaysOnTop/startDrag; added setFloating, updateFloating, getDataDir, speedScale, trayAction toggles | HandleCall, MainActivity.handle, _onNativeAction |
