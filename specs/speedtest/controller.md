# controller spec
Source: lib/src/speedtest/speed_test_controller.dart, lib/src/speedtest/history.dart, lib/src/ui/pages/speed_test_page.dart | Language: Dart | Commit: no-vcs | Generated: 2026-11-21

## 1. Overview
`SpeedTestController` (ChangeNotifier) holds the running test's progress and the saved
results; `SpeedTestHistory` persists the last 50 runs; `SpeedTestPage` is the Test tab:
a 270° dial (logo geometry, non-linear scale), status line, Start/Cancel, Ping / Jitter /
Download / Upload tiles, History, and the server/data note.

## 2. APIs and Use Cases
| API | Entry point (file:line) | Use case |
| --- | --- | --- |
| `SpeedTestController.load` | lib/src/speedtest/speed_test_controller.dart:35 | read history once |
| `SpeedTestController.start` | lib/src/speedtest/speed_test_controller.dart:43 | run; save on done; completes when the run ends |
| `SpeedTestController.cancel` | lib/src/speedtest/speed_test_controller.dart:80 | stop, back to idle, nothing saved |
| `SpeedTestController.clearHistory` | lib/src/speedtest/speed_test_controller.dart:89 | empty history |
| `FileSpeedTestHistory` | lib/src/speedtest/history.dart:17 | JSON file, tmp + rename, newest first, keep 50 |
| `SpeedTestPage` / `SpeedDialPainter` | lib/src/ui/pages/speed_test_page.dart | Test tab UI |

## 3. Data Flows
- Start: `SpeedTestPage Start button -> SpeedTestController.start -> SpeedTestEngine.run -> progress -> notifyListeners -> SpeedTestPage rebuild`
- Save: `progress.phase == done -> SpeedTestResult -> results.insert(0) -> SpeedTestHistory.add`
- History location: Windows `WindowsMeterPlatform.speedTests = FileSpeedTestHistory(%APPDATA%\Tachyo\speedtests.json)`; Android `AndroidMeterPlatform.speedTests = FileSpeedTestHistory.lazy(NativeBridge.dataDir)`
- Dial: `SpeedTestPage._dialValue(bps, unit) -> SpeedDialPainter.fraction(value, stops)`; stops Mbps 0,1,5,10,20,50,100,250,500,1000 or MB/s 0,0.1,0.5,1,2.5,5,10,25,50,100

## 4. Entry Points
| Entry point (method) | Usage summary | Input parameters |
| --- | --- | --- |
| `SpeedTestController({history, transport, config, clock})` | created in main.dart | history; transport factory for tests |
| `SpeedTestPage(controller, meter)` | Test tab | controller, MeterController (units) |

## 5. Edge Cases
- `start` while running -> ignored.
- Corrupt or missing history file -> empty list, never blocks a test.
- After done the dial rests on the download result; during upload the dial is green.
- Values in Mbps (bits) or MB/s (bytes) regardless of the Speed format setting. In bytes mode the dial also shows "= N Mbps" (key `dial-mbps`), because other speed tests report megabits (MB/s here is 1024-based: 3.88 MB/s = 32.5 Mbps).
- Done status: "Server Mumbai (BOM) · used N MB" plus the provider on a second line; history rows show the provider too (`network`, '' in old rows).
- Keys used by tests: `test-start`, `test-cancel`, `test-status`, `dial-value`, `metric-<Label>`.

## 6. History
| Date | Commit | Change | Affected methods |
| --- | --- | --- | --- |
| 2026-11-21 | no-vcs | Initial spec | all |
| 2026-11-21 | no-vcs | Provider in status/history, Mbps line in bytes mode | SpeedTestController.start, SpeedTestPage |
