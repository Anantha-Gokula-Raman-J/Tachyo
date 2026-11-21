# data module spine
Source: lib/src/data | Language: Dart | Commit: no-vcs | Generated: 2026-11-21

## Responsibility
Persistence behind two interfaces so the controller is platform-neutral:
`UsageRepository` (per-day usage) and `SettingsStore` (app settings).
Windows stores JSON files in `%APPDATA%\Tachyo`; Android delegates to
native SharedPreferences so the background service can read/write without Flutter.

## Shared types
| Type | File:line |
| --- | --- |
| `UsageRepository` | lib/src/data/usage_repository.dart:8 |
| `historyDays` (90) | lib/src/data/usage_repository.dart:19 |
| `AppSettings` | lib/src/data/settings_store.dart:7 |
| `SettingsStore` | lib/src/data/settings_store.dart:49 |

## Submodules
- `usage.md` – File/Native/Memory usage repositories and gap filling.
- `settings.md` – AppSettings and File/Native/Memory settings stores.

## Cross-module flows
- `MeterController.start -> SettingsStore.load`, `MeterController.refreshUsage -> UsageRepository.recent`.
- Android: `NativeUsageRepository -> NativeBridge.dailyUsage/addUsage -> MainActivity.handle -> UsageStore`.

## Calls into other modules
core (models), platform (`NativeBridge` for the Android implementations).
