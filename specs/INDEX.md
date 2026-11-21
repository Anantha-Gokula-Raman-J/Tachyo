# Tachyo specs index
Read this first. Then open the module's `common/README.md`, then the submodule spec.
Read source only for the methods a spec's Entry Points / Data Flows name, by line range.
When code changes a spec's behavior, update that spec and append a History row in the same change.

Project: Tachyo – Net Speed Meter | Flutter (Dart) + Kotlin + C++
Targets: Android, Windows | Commit: no-vcs | Generated: 2026-11-21

## Modules
| Module | Spine | Submodules | Keywords |
| --- | --- | --- | --- |
| core | `core/common/README.md` | `core/models.md`, `core/format.md`, `core/sampler.md` | counters, speed, units, bytes/bits, dayKey, deltas, counter reset |
| data | `data/common/README.md` | `data/usage.md`, `data/settings.md` | usage history, daily totals, json file, 90 days, settings, units |
| platform | `platform/common/README.md` | `platform/channel.md`, `platform/android-native.md`, `platform/windows-native.md`, `platform/meter-platform.md` | method channel, TrafficStats, foreground service, status bar icon, boot, GetIfTable2, tray, glass floating meter, sign-in start |
| state | `state/common/README.md` | `state/meter-controller.md` | timer, tick, history, peaks, session, recording rules |
| ui | `ui/common/README.md` | `ui/design-system.md`, `ui/pages.md`, `ui/branding.md` | Astryx tokens, theme, live/usage/test/settings pages, speed format, logo, icons |
| speedtest | `speedtest/common/README.md` | `speedtest/engine.md`, `speedtest/controller.md` | internet speed test, ping, jitter, download, upload, history, dial |

## Task -> spec lookup
| Task | Spec |
| --- | --- |
| speed/units text wrong, add a unit | `core/format.md` (+ Android mirror in `platform/android-native.md`) |
| speed format (Auto vs fixed unit) | `core/format.md`, `data/settings.md`, `platform/android-native.md` |
| speed test numbers, server, history | `speedtest/engine.md`, `speedtest/controller.md` |
| spikes, negative speeds, wrong per-category split | `core/sampler.md`, `platform/windows-native.md` (hot-plug), `platform/android-native.md` |
| daily usage missing / double counted | `state/meter-controller.md` (recording rules), `data/usage.md` |
| status bar icon / notification / boot start | `platform/android-native.md` |
| tray icon, close-to-tray, exit, floating meter, start with Windows | `platform/windows-native.md`, `platform/meter-platform.md` |
| add a channel method | `platform/channel.md` (contract), then both native specs |
| colors, radii, spacing, dark mode | `ui/design-system.md` |
| app name, icon, publisher, licenses page | `ui/branding.md` |
| new setting | `data/settings.md`, `ui/pages.md`, `platform/android-native.md` (Prefs) |

## Feature IDs (harness/context.ps1 -Feature <ID>)
| ID | Feature | Specs |
| --- | --- | --- |
| NSM-CORE | speed math + formatting | core/* |
| NSM-USAGE | daily usage history | data/usage.md, state/meter-controller.md |
| NSM-SETTINGS | settings | data/settings.md |
| NSM-ANDROID | status-bar meter, boot, channel (Android) | platform/android-native.md, platform/channel.md |
| NSM-WINDOWS | tray meter, floating meter, channel (Windows) | platform/windows-native.md, platform/channel.md |
| NSM-UI | pages + theme | ui/* |
| NSM-BRAND | name, icon, licenses | ui/branding.md |
| NSM-SPEEDTEST | internet speed test | speedtest/*, ui/pages.md |
