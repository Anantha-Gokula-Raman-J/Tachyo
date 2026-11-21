# engine spec
Source: lib/src/speedtest/engine.dart, lib/src/speedtest/transport.dart | Language: Dart | Commit: no-vcs | Generated: 2026-11-21

## 1. Overview
`SpeedTestEngine` runs latency -> download -> upload and streams `SpeedTestProgress`.
`SpeedTestTransport` hides the network so the timing math is unit-tested with a fake;
`HttpSpeedTestTransport` is the real one (dart:io only).

Method:
- **Provider**: `GET /meta` (with the page referer, else it answers `{}`) -> `asOrganization`
  (internet provider) and `colo.city` (server city). From the IP address; no location permission.
- **Latency**: `pings + 1` (20 + 1) empty GETs; the first (TCP/TLS setup) is dropped. Ping = lowest
  RTT (idle latency; Wi-Fi power saving only adds to it — the median read 27–56 ms on a link whose
  ICMP minimum was 2 ms), jitter = mean |RTT[i] − RTT[i−1]|. RTT = time to response headers minus
  the server's own time from `Server-Timing` (`serverTimeMs`).
- **Throughput**: N parallel streams for a fixed time (download 6 × 25 MB requests for 10 s,
  upload 4 × 4 MB requests for 8 s), each stream looping requests. Result = bytes moved after
  the 1.5 s warm-up ÷ time after the warm-up (TCP slow start excluded). A phase also ends at its
  data cap (400 MB down / 150 MB up).
- Live value: bytes in a sliding ~1 s window, sampled every 200 ms.

## 2. APIs and Use Cases
| API | Entry point (file:line) | Use case |
| --- | --- | --- |
| `SpeedTestEngine.run` | lib/src/speedtest/engine.dart:62 | full test as a progress stream |
| `SpeedTestEngine.cancel` | lib/src/speedtest/engine.dart:57 | stop and abort requests |
| `SpeedTestEngine._transfer` | lib/src/speedtest/engine.dart:147 | parallel timed transfer + warm-up math |
| `SpeedTestEngine.latencyStats` | lib/src/speedtest/engine.dart:217 | lowest RTT + jitter |
| `SpeedTestEngine.describeError` | lib/src/speedtest/engine.dart:227 | user-facing error text (incl. 429) |
| `HttpSpeedTestTransport.lookup` | lib/src/speedtest/transport.dart:63 | provider + server city from `/meta` |
| `HttpSpeedTestTransport.serverTimeMs` | lib/src/speedtest/transport.dart:104 | server time from `Server-Timing` |
| `HttpSpeedTestTransport.ping` | lib/src/speedtest/transport.dart:82 | RTT minus server time |
| `HttpSpeedTestTransport.download` | lib/src/speedtest/transport.dart:113 | `GET /__down?bytes=N`, counts chunks |
| `HttpSpeedTestTransport.upload` | lib/src/speedtest/transport.dart:132 | `POST /__up`, lazy 64 KB chunks via addStream |
| `HttpSpeedTestTransport.abortAll` | lib/src/speedtest/transport.dart:162 | abort in-flight requests, fresh HttpClient |

## 3. Data Flows
- Test: `SpeedTestController.start -> SpeedTestEngine.run -> HttpSpeedTestTransport.lookup -> HttpSpeedTestTransport.ping (×21) -> SpeedTestEngine.latencyStats -> SpeedTestEngine._transfer(download) -> SpeedTestEngine._transfer(upload) -> SpeedTestProgress(done)`
- Transfer: `SpeedTestEngine._transfer -> worker × N -> transport.download|upload(onBytes) -> moved += n`; ticker -> `onTick(live, fraction, moved)` -> `transport.abortAll` at the deadline/cap
- Server label: `HttpSpeedTestTransport._noteServer` reads `cf-ray` "…-BOM" + `lookup` city -> `server` "Mumbai (BOM)"; `network` = provider
- Cancel: `SpeedTestController.cancel -> SpeedTestEngine.cancel -> transport.abortAll` -> stream closes without a result

## 4. Entry Points
| Entry point (method) | Usage summary | Input parameters |
| --- | --- | --- |
| `SpeedTestEngine(transport, config)` | one test run | `SpeedTestTransport`, `SpeedTestConfig` |
| `SpeedTestEngine.run` | start | – |
| `HttpSpeedTestTransport({host})` | real network | host (default speed.cloudflare.com) |

## 5. Edge Cases
- `Server-Timing` and `cf-ray` can repeat -> read with `headers[name]`, never `headers.value` (throws on duplicates; found by the live test).
- Aborts at the end of a phase are expected and swallowed; a real failure with 0 bytes moved is rethrown -> `error` phase ("Could not reach the test server…") instead of "0 Mbps".
- Phase shorter than warm-up + 0.5 s -> plain bytes/elapsed.
- Late ticks after cancel are ignored by the controller.
- `Server-Timing` changed in 2026 from `cfRequestDuration;dur=` to `cfSpeedEdge;dur=1, cfSpeedWorker;dur=15`; both are summed, `cfL4` ignored. Missing it added ~16 ms to every ping.
- `lookup` failure (offline, odd JSON) -> empty provider/city, test continues.
- HTTP 429 after many runs in a short time -> "limiting tests … try again in a few minutes".
- Checked against a reference test on this PC (Wi-Fi, 2026-11-21): download 234 vs 220 Mbps; adapter counters confirmed bytes moved. The reference's server sits inside the ISP, so its ping (3 ms) stays below ours (~7 ms to the nearest Cloudflare data center).
- Data use: ~50–500 MB per run depending on speed (live run on this PC: 203–405 MB at ~200 Mbps).
- Tests: test/speedtest_test.dart (fake transport: order of phases, plausible rates, error path, latency math); tool/speedtest_live_test.dart (real server, manual).

## 6. History
| Date | Commit | Change | Affected methods |
| --- | --- | --- | --- |
| 2026-11-21 | no-vcs | Initial spec | all |
| 2026-11-21 | no-vcs | Lowest-RTT ping (20 samples), new Server-Timing form, provider lookup, 429 message | latencyStats, ping, serverTimeMs, lookup, describeError, run |
