# sampler spec
Source: lib/src/core/sampler.dart | Language: Dart | Commit: no-vcs | Generated: 2026-11-21

## 1. Overview
`SpeedSampler` keeps the previous `NetCounters` and turns each new reading into a
`SampleResult` (speed in bytes/s + per-category `UsageDelta`). Depends only on models.

## 2. APIs and Use Cases
| API | Entry point (file:line) | Use case |
| --- | --- | --- |
| `SpeedSampler.push` | lib/src/core/sampler.dart:19 | one sampling interval |
| `SpeedSampler.reset` | lib/src/core/sampler.dart:17 | forget the baseline |

## 3. Data Flows
- Tick: `MeterController.tick -> SpeedSampler.push -> MeterController._apply`

## 4. Entry Points
| Entry point (method) | Usage summary | Input parameters |
| --- | --- | --- |
| `SpeedSampler.push` | returns null or SampleResult | `NetCounters current` |

## 5. Edge Cases
- First reading -> null (no baseline) (sampler.dart:22).
- Clock not advancing (dt ≤ 0) -> null (sampler.dart:24).
- Total rx or tx decreased (reboot, counter wrap) -> null; next reading uses the new baseline (sampler.dart:27).
- Category deltas clamped ≥ 0; other = total − wifi − mobile clamped ≥ 0 (sampler.dart:29-41).
- Timestamps must be monotonic: Android `SystemClock.elapsedRealtime`, Windows `GetTickCount64`.
- Tests: test/core_test.dart group `SpeedSampler`.

## 6. History
| Date | Commit | Change | Affected methods |
| --- | --- | --- | --- |
| 2026-11-21 | no-vcs | Initial spec | push |
