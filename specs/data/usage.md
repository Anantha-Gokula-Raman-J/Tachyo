# usage spec
Source: lib/src/data/usage_repository.dart | Language: Dart | Commit: no-vcs | Generated: 2026-11-21

## 1. Overview
Per-day usage history (`DailyUsage`) keyed by `dayKey`. Three implementations:
`FileUsageRepository` (Windows; JSON map date -> record, buffered writes, atomic
replace, keeps 90 days), `NativeUsageRepository` (Android; native `UsageStore` is
the source of truth, shared with `MeterService`), `MemoryUsageRepository` (tests).

## 2. APIs and Use Cases
| API | Entry point (file:line) | Use case |
| --- | --- | --- |
| `UsageRepository.recent` | lib/src/data/usage_repository.dart:11 | last N days, newest first, gaps filled |
| `UsageRepository.add` | lib/src/data/usage_repository.dart:13 | add one interval to a day |
| `UsageRepository.flush` | lib/src/data/usage_repository.dart:16 | persist buffered writes (pause/exit/toggle) |
| `fillDays` | lib/src/data/usage_repository.dart:21 | zero records for missing days |
| `FileUsageRepository._load` | lib/src/data/usage_repository.dart:40 | lazy parse, tolerant of corruption |
| `FileUsageRepository.flush` | lib/src/data/usage_repository.dart:75 | prune to 90 days, write tmp, rename |

## 3. Data Flows
- Windows record: `MeterController.tick -> FileUsageRepository.add -> FileUsageRepository._load -> DailyUsage.add -> FileUsageRepository.flush (every 10 adds)`
- Windows read: `MeterController.refreshUsage -> FileUsageRepository.recent -> fillDays`
- Android record (meter off): `MeterController.tick -> NativeUsageRepository.add -> NativeBridge.addUsage -> MainActivity.handle("addUsage") -> UsageStore.add`
- Android read: `MeterController.refreshUsage -> NativeUsageRepository.recent -> NativeBridge.dailyUsage -> fillDays`
- Exit: `MeterController._onNativeAction("exit") -> UsageRepository.flush -> MeterPlatform.quit`

## 4. Entry Points
| Entry point (method) | Usage summary | Input parameters |
| --- | --- | --- |
| `UsageRepository.recent` | list length == days | `int days`, `DateTime today` |
| `UsageRepository.add` | empty delta ignored | `String date`, `UsageDelta delta` |
| `UsageRepository.flush` | no-op when nothing pending | – |
| `FileUsageRepository(file, flushEvery)` | default flush every 10 adds (~10 s) | `File`, `int` |

## 5. Edge Cases
- Corrupt or non-map JSON -> start empty, never throw (usage_repository.dart:56-58).
- Write is tmp file + rename so a crash never leaves half a file (usage_repository.dart:86-88).
- More than 90 days -> oldest removed on flush (usage_repository.dart:80-82).
- Up to `flushEvery-1` adds can be lost on a hard kill; exit/pause/toggle call flush.
- Android: the Dart side never buffers; Kotlin `UsageStore.add` is synchronized.
- Tests: test/core_test.dart group `FileUsageRepository`.

## 6. History
| Date | Commit | Change | Affected methods |
| --- | --- | --- | --- |
| 2026-11-21 | no-vcs | Initial spec | all |
