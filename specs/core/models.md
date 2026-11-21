# models spec
Source: lib/src/core/models.dart | Language: Dart | Commit: no-vcs | Generated: 2026-11-21

## 1. Overview
Immutable/mutable value types that cross every layer. `NetCounters.fromMap` and
`DailyUsage.fromMap/toMap` define the wire shape used on the platform channel
(see `platform/channel.md`). Categories: Wi-Fi, mobile, other (other = total minus
Wi-Fi minus mobile; Ethernet on Windows, unused on Android).

## 2. APIs and Use Cases
| API | Entry point (file:line) | Use case |
| --- | --- | --- |
| `NetCounters.fromMap` | lib/src/core/models.dart:32 | decode `getCounters` reply |
| `NetCounters.otherRx/otherTx` | lib/src/core/models.dart:29-30 | derive non-Wi-Fi, non-mobile bytes |
| `UsageDelta.toMap` | lib/src/core/models.dart:80 | encode `addUsage` arguments |
| `DailyUsage.add` | lib/src/core/models.dart:116 | accumulate an interval into a day |
| `DailyUsage.fromMap/toMap` | lib/src/core/models.dart:145,135 | channel + JSON file encoding |
| `dayKey` | lib/src/core/models.dart:161 | local day key `yyyy-MM-dd` |

## 3. Data Flows
- Counter decode: `NativeBridge.read -> NetCounters.fromMap`
- Usage decode: `NativeBridge.dailyUsage -> DailyUsage.fromMap`
- Day accumulate: `MeterController._addToToday -> DailyUsage.add`

## 4. Entry Points
| Entry point (method) | Usage summary | Input parameters |
| --- | --- | --- |
| `NetCounters.fromMap` | missing keys read as 0 | map with rx, tx, wifiRx, wifiTx, mobileRx, mobileTx, t |
| `DailyUsage.add` | adds every category | `UsageDelta d` |
| `DailyUsage.fromMap` | missing keys -> 0, missing date -> '' | map |
| `dayKey` | zero-padded local date | `DateTime t` |

## 5. Edge Cases
- Missing/num-typed map values -> converted with `toInt()`, absent -> 0 (models.dart:33).
- other = total − wifi − mobile clamped to ≥ 0 (models.dart:29-30, 163).
- `dayKey` uses local time; must match Kotlin `SimpleDateFormat("yyyy-MM-dd")` (UsageStore.kt:48).

## 6. History
| Date | Commit | Change | Affected methods |
| --- | --- | --- | --- |
| 2026-11-21 | no-vcs | Initial spec | all |
