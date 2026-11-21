# android-native spec
Source: android/app/src/main (kotlin/app/tachyo, AndroidManifest.xml) | Language: Kotlin | Commit: no-vcs | Generated: 2026-11-21

## 1. Overview
Android side with zero third-party libraries (framework `Notification.Builder`,
`Icon.createWithBitmap`, `TrafficStats`). `MeterService` is a `specialUse` foreground
service that redraws the status-bar icon with the live total speed every second and
records per-day usage. `BootReceiver` restarts it. No INTERNET permission: the app
never sends data anywhere. Permissions: FOREGROUND_SERVICE, FOREGROUND_SERVICE_SPECIAL_USE,
POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED.

## 2. APIs and Use Cases
| API | Entry point (file:line) | Use case |
| --- | --- | --- |
| `MainActivity.handle` | MainActivity.kt:29 | channel dispatch (see channel.md) |
| `MainActivity.requestNotifications` | MainActivity.kt:78 | POST_NOTIFICATIONS on API 33+ |
| `TrafficReader.read` | TrafficReader.kt:29 | totals + mobile from TrafficStats, wifi = total − mobile |
| `MeterService.start/stop` | MeterService.kt:38,42 | startForegroundService / stopService |
| `MeterService.tick` | MeterService.kt:89 | speed, usage accumulation, notification update |
| `MeterService.createChannel` | MeterService.kt:128 | channel `tachyo_meter_v2`, IMPORTANCE_DEFAULT, silent |
| `MeterService.buildNotification` | MeterService.kt:144 | title ↓/↑, text today Mobile/Wi-Fi |
| `MeterService.speedIcon` | MeterService.kt:173 | white value+unit bitmap for the status bar |
| `UsageStore.add/get/recent` | UsageStore.kt:51,62,67 | prefs `tachyo_usage`, "wRx,wTx,mRx,mTx", 90 days |
| `Prefs` | Prefs.kt:6 | prefs `tachyo_settings` |
| `SpeedFormat` | SpeedFormat.kt:10 | mirror of core/format.dart |
| `BootReceiver.onReceive` | BootReceiver.kt:10 | BOOT_COMPLETED / MY_PACKAGE_REPLACED |

## 3. Data Flows
- Enable: `AndroidMeterPlatform.setMeterEnabled -> MainActivity.handle("startMeter") -> Prefs.setMeterEnabled -> MeterService.start -> MeterService.onCreate -> MeterService.createChannel -> startForeground`
- Meter loop: `tickRunnable.run -> MeterService.tick -> TrafficReader.read -> MeterService.flush (every 10 ticks) -> UsageStore.add -> MeterService.buildNotification -> MeterService.speedIcon -> SpeedFormat.compact`
- Boot: `BootReceiver.onReceive -> Prefs.meterEnabled/bootStart -> MeterService.start`
- Disable: `MainActivity.handle("stopMeter") -> MeterService.stop -> MeterService.onDestroy -> MeterService.flush`

## 4. Entry Points
| Entry point (method) | Usage summary | Input parameters |
| --- | --- | --- |
| `MainActivity.handle` | channel | MethodCall, Result |
| `MeterService.onStartCommand` | (re)starts loop, START_STICKY | Intent |
| `BootReceiver.onReceive` | conditional restart | Context, Intent |
| `UsageStore.add` | synchronized merge into a day | Context, date, UsageRecord |

## 5. Edge Cases
- IMPORTANCE_LOW icons are hidden from the status bar on modern Android -> channel is DEFAULT with no sound/vibration + `setOnlyAlertOnce`; old `tachyo_meter` channel deleted (MeterService.kt:130-140).
- TrafficStats UNSUPPORTED (-1) -> 0 (TrafficReader.kt:27).
- Counter reset or dt ≤ 0 -> interval dropped (MeterService.kt:104).
- Screen off -> tick every 5 s, usage still counted, notification not redrawn (MeterService.kt:55,114).
- Midnight -> pending flushed to the old day before counting the new day (MeterService.kt:95-98).
- Single writer: Dart records via `addUsage` only while the service is not running.
- Boot start refused by OS -> logged, resumes next app open (BootReceiver.kt:17-22). Verified on API 37: started via BOOT_COMPLETED allow-list.
- API 34+: `startForeground(..., FOREGROUND_SERVICE_TYPE_SPECIAL_USE)`; manifest subtype property explains the use.

- Notification title and status-bar icon follow `Prefs.speedScale` (fixed unit or Auto), read every tick, so a Settings change shows within a second.
- INTERNET permission is used only by the in-app speed test (Dart); the meter service makes no network calls.
- `getDataDir` returns `filesDir` for the speed test history file.

## 6. History
| Date | Commit | Change | Affected methods |
| --- | --- | --- | --- |
| 2026-11-21 | no-vcs | Initial spec | all |
| 2026-11-21 | no-vcs | Channel v2 at IMPORTANCE_DEFAULT (status-bar visibility); larger icon text | createChannel, speedIcon |
| 2026-11-21 | no-vcs | speedScale in notification/icon; INTERNET for speed test; getDataDir; Prefs.save stores Ints | MeterService.buildNotification, SpeedFormat.speed/compact, Prefs, MainActivity.handle |
