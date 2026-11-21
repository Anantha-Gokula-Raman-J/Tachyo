# core module spine
Source: lib/src/core | Language: Dart | Commit: no-vcs | Generated: 2026-11-21

## Responsibility
Pure-Dart value types and math: OS counters -> speeds and usage deltas, and the
text formatting of speeds and sizes. No Flutter or platform imports, so every
piece is unit-tested in `test/core_test.dart`.

## Shared types
| Type | File:line | Role |
| --- | --- | --- |
| `NetCounters` | lib/src/core/models.dart:10 | cumulative rx/tx + wifi/mobile subsets + timestamp (ms) |
| `SpeedSample` | lib/src/core/models.dart:47 | down/up bytes per second at a time |
| `UsageDelta` | lib/src/core/models.dart:59 | bytes in one interval per category (wifi/mobile/other) |
| `DailyUsage` | lib/src/core/models.dart:90 | per-day mutable totals, keyed by `dayKey` |
| `dayKey` | lib/src/core/models.dart:161 | local `yyyy-MM-dd`, shared with Kotlin `UsageStore.dayKey` |
| `SpeedUnit`, `FormattedValue` | lib/src/core/format.dart:4,6 | bytes vs bits; value + unit text |
| `SpeedSampler`, `SampleResult` | lib/src/core/sampler.dart:14,3 | counters -> speed + delta |

## Submodules
- `models.md` – value types and map (de)serialisation used on the channel.
- `format.md` – formatSpeed / compactSpeed / formatBytes (mirrored in Kotlin).
- `sampler.md` – interval math with reset/hot-plug safety.

## Cross-module flows
- Sampling: `MeterController.tick -> NetSource.read -> SpeedSampler.push -> DailyUsage.add` (state).
- Display: `SpeedTile.build -> formatSpeed(scale)` (ui); `WindowsMeterPlatform.onSample -> formatSpeed / compactSpeed (scale)` (platform).

## Calls into other modules
None (leaf module).
