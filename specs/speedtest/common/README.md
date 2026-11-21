# speedtest module (spine)
Source: lib/src/speedtest/ | Language: Dart | Commit: no-vcs | Generated: 2026-11-21

## Responsibility
Internet speed test started by the user: latency + jitter, download and upload throughput,
saved history. Pure Dart over `dart:io` HttpClient — no packages, no native code. The only
network traffic Tachyo ever makes; the Android INTERNET permission exists for it alone.

Test server: Cloudflare's public speed test endpoints (`speed.cloudflare.com`): `GET /__down?bytes=N`,
`POST /__up`, `GET /meta` (provider name and server city, derived from the IP address — no
location permission, unlike tests that pick a server by GPS). The app says so on the Test page (the server sees the user's IP address). No
other speed test product or brand is named anywhere in the app or the project.

## Shared types
| Type | Where | Notes |
| --- | --- | --- |
| `SpeedTestPhase` | lib/src/speedtest/models.dart:4 | idle, latency, download, upload, done, error |
| `SpeedTestProgress` | lib/src/speedtest/models.dart:58 | live update: phase, currentBps, phaseFraction, ping/jitter/down/up, server, bytesUsed, error |
| `SpeedTestResult` | lib/src/speedtest/models.dart:7 | saved run; toMap/fromMap (bad rows -> null) |
| `SpeedTestConfig` | lib/src/speedtest/engine.dart:9 | durations, streams, request sizes, data caps |

## Submodules
- `engine.md` – SpeedTestEngine + SpeedTestTransport/HttpSpeedTestTransport: how numbers are measured.
- `controller.md` – SpeedTestController, SpeedTestHistory, and the Test page flows.

## Cross-module flows
- `HomeShell -> SpeedTestPage(controller, meter) -> SpeedTestController.start -> SpeedTestEngine.run -> HttpSpeedTestTransport`
- History file: Windows `%APPDATA%\Tachyo\speedtests.json`; Android `<filesDir>/speedtests.json` via channel `getDataDir`.
- Units: the page reads `MeterController.settings.unit` and always shows Mbps or MB/s (`SpeedScale.mega`) so runs compare.
- The live meter counts the test's traffic like any other traffic.

## Depends on
core (format), platform (history location), ui (tokens, widgets).
