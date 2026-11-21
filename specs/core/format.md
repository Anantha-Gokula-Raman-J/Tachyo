# format spec
Source: lib/src/core/format.dart | Language: Dart | Commit: no-vcs | Generated: 2026-11-21

## 1. Overview
Human text for speeds and sizes. Bytes use a 1024 base (B/s, KB/s, MB/s, GB/s);
bits use a 1000 base (bps, Kbps, Mbps, Gbps). `SpeedScale` picks Auto (default: unit by size) or one fixed
unit (B/s, KB/s, MB/s or bps, Kbps, Mbps) — the user's "Speed format" setting. Mirrored for the Android status-bar
service in `android/.../SpeedFormat.kt` – the two must change together.

## 2. APIs and Use Cases
| API | Entry point (file:line) | Use case |
| --- | --- | --- |
| `formatSpeed` | lib/src/core/format.dart:30 | Live tiles, floating meter, tooltips, notification, speed test (mega) |
| `scaleLabel` | lib/src/core/format.dart:11 | "Auto" or the fixed unit label for the Settings picker |
| `compactSpeed` | lib/src/core/format.dart:59 | ≤3-char value + short unit for tray/status icons |
| `formatBytes` | lib/src/core/format.dart:50 | usage totals |
| `_decimals` | lib/src/core/format.dart | bytes/sizes: 2 decimals <10, 1 decimal <100, else integer |
| `_bitDecimals` | lib/src/core/format.dart | bits: always 1 decimal ("144.4 Mbps", "103.3 Kbps"); bps and 1000+ integer |

## 3. Data Flows
- Live tile: `SpeedTile.build -> formatSpeed -> _decimals`
- Tray icon: `WindowsMeterPlatform.onSample -> compactSpeed(scale) -> formatSpeed`
- Floating meter: `WindowsMeterPlatform.onSample -> formatSpeed(unit, scale) -> NativeBridge.updateFloating`
- Usage rows: `UsageRow.build -> formatBytes -> _decimals`

## 4. Entry Points
| Entry point (method) | Usage summary | Input parameters |
| --- | --- | --- |
| `formatSpeed` | scale + unit pick | `double bytesPerSecond`, `SpeedUnit unit`, `[SpeedScale scale = auto]` |
| `compactSpeed` | short form for icons | same |
| `formatBytes` | 1024-base size text | `int bytes` |

## 5. Edge Cases
- NaN, infinity, negative -> treated as 0 (format.dart:22).
- 1000–1023 of a unit promotes to the next unit so 4 integer digits never show (format.dart:30-34).
- Base unit (B/s, bps, B) is always an integer (format.dart:61).
- Fixed scale never promotes: 2 MB/s at KB/s reads "2048 KB/s"; tiny values read "0.00 MB/s".
- Bits in Auto: 999.95+ of a unit promotes too, so "1000.0 Kbps" never shows ("1.0 Mbps").
- Bits are the app default (Kbps/Mbps, like ISP plans, other meters and speed tests); 222 KB/s (1024-based) = 1.8 Mbps.
- compact with a fixed scale falls back to auto once the value needs 4+ digits, so icons stay readable.
- compact: "0.0" shown as "0"; unit drops "/s" and "ps" ("KB", "Mb") (format.dart:44-46).
- Tests: test/core_test.dart group `formatSpeed`.

## 6. History
| Date | Commit | Change | Affected methods |
| --- | --- | --- | --- |
| 2026-11-21 | no-vcs | Initial spec | all |
| 2026-11-21 | no-vcs | SpeedScale (Auto or fixed unit), scaleLabel; compact fallback | formatSpeed, compactSpeed, scaleLabel |
| 2026-11-21 | no-vcs | Bits use one decimal (also SpeedFormat.kt) | formatSpeed, _bitDecimals |
