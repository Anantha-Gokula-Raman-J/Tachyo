# state module spine
Source: lib/src/state | Language: Dart | Commit: no-vcs | Generated: 2026-11-21

## Responsibility
`MeterController` (a `ChangeNotifier`) is the only app state: sampling loop,
60-sample history, peaks, session totals, today/30-day usage, settings and the meter
flag. The speed test has its own `SpeedTestController` (specs/speedtest). UI listens via `ListenableBuilder`.

## Shared types
| Type | File:line |
| --- | --- |
| `MeterController` | lib/src/state/meter_controller.dart:12 |

## Submodules
- `meter-controller.md`

## Cross-module flows
- `main -> MeterController.start` (lib/main.dart:12).
- Lifecycle: `_HomeShellState.didChangeAppLifecycleState -> MeterController.pause/refreshUsage` (lib/src/ui/app.dart:56).

## Calls into other modules
core (sampler, models), data (stores), platform (MeterPlatform).
