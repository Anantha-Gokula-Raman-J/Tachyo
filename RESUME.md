# RESUME – progress checkpoint

Last update: 2026-11-21

## State
- v1.0.0 feature-complete for Android and Windows; 27 Flutter tests pass.
- Standalone open-source app under MIT (LICENSE), app id `app.tachyo`, no publisher/organization. Windows data in `%APPDATA%\Tachyo`.
- Features: live meter, daily usage, internet speed test (Test tab), Speed format (Auto default or fixed B/s · KB/s · MB/s).
- Windows: tray icon always on; closing the window hides it; only tray Exit quits. Native glass floating meter (`windows/runner/floating_meter.cpp`): layered tool window, adaptive light/dark text, re-asserts topmost on every foreground change, hides in full-screen apps, drag to move (position in HKCU\Software\Tachyo), double-click opens, right-click = tray menu. Start with Windows (Run entry `--background`), single instance.
- Speed test: Cloudflare public endpoints via dart:io. Ping = lowest of 20 RTTs minus server time (Server-Timing now `cfSpeedEdge`/`cfSpeedWorker`; the old `cfRequestDuration` parse missed ~16 ms). Shows provider + server city from `/meta` (no location permission) and "= N Mbps" in bytes mode. Compared on this PC against a reference browser test: down 234 vs 220 Mbps, ping ~7 vs 3 ms (reference server is inside the ISP). Repeated runs within minutes get HTTP 429 -> friendly message. No other speed-test brand is named in the app or project.
- Windows app run 2026-11-21 (screenshot docs/screenshots/windows_speed_test.png): 230 Mbps down, ~196 Mbps up, 5.9 ms ping, provider name shown. Reference right after: 193 / 106 Mbps, 2 ms. Adapter per-second counters during a Tachyo run: down ~147 vs reported 144 Mbps, up 231–243 vs reported 218 Mbps -> Tachyo's upload is real; the reference reads upload lower.
- Floating meter during a download (docs/screenshots/windows_floating_meter.png): 19.9 MB/s down / 188 KB/s up vs Windows adapter 20.0 MB/s / 183 KB/s for the same second. Readings taken during ramp-up differ more only because the meter and the check sample different seconds.
- Units: Kbps/Mbps (bits) is the default everywhere, one decimal like other meters ("156.9 Mbps", "594.3 Kbps"); bytes stay available in Settings. This PC switched to bits. Side by side with the reference meter during a download: 156.9 vs 158.2 Mbps down, 594 vs 570 Kbps up (the reference shows upload on top). Screenshots refreshed: windows-live.png, windows_floating_meter.png, windows_speed_test.png (237.2 / 193.3 Mbps, 6.0 ms).
- Android re-checked on the emulator 2026-11-21 (fresh install; the emulator had been wiped by another session): defaults to Kbps/Mbps; notification "↓ 13.1 Mbps ↑ 52.0 Kbps"; speed test 22.6 / 27.8 Mbps, 8.4 ms, provider shown (emulator network limits speed). Screenshots: android-live.png, android-notification.png, android_speed_test.png.
- OPEN: Android emulator speed test reads low. Same emulator 2026-11-21: Cloudflare web test in Chrome 67.6 / 44.5 Mbps (90th percentile), reference web test 63.8; Tachyo 26–30 down / 27–44 up. Not CPU (main thread ~39%, 3 of 4 cores idle), not stream count (2/4/6 streams all ~27–30, probe `tool/speedtest_probe_main.dart`). Suspect the emulator's TCP path (Chrome likely uses QUIC/UDP); raw `nc` TCP check blocked by server rate limit. Next: rerun the nc check later, and test the APK on a real phone (decides it).
- Tachyo holds no location permission (Android: INTERNET, POST_NOTIFICATIONS, foreground service, boot; ACCESS_LOCAL_NETWORK added by the platform). Provider name comes from the IP address via `/meta`; one ISP can own address blocks registered under different company names, so the shown name can change with the IP address.
- Meter accuracy: Windows Wi-Fi bytes counted by Tachyo during a test equal `Get-NetAdapterStatistics` (tx 92.3 = 92.3 MB). Remaining differences vs other meters = sampling instant and 1024 vs 1000 units.
- Emulator speed tests are limited by the emulator's virtual network; compare on a real phone.
- Android verified on emulator Medium_Phone (API 37): speed test, Speed format in notification, restart after reboot (ANDROID SMOKE OK earlier today).
- Windows verified on this PC: floating meter shown after closing the window, toggle on/off, fixed unit, light/dark switch, speed test in the app. Test Run entry removed from this PC afterwards.
- Specs: 6 modules (spines) / 15 submodule specs in `specs/`, all six sections, all < 600 lines.
- Quality gate `harness/verify.ps1 -Build` -> VERIFY OK (analyze clean, 27 tests, Windows + APK builds).
- Harness: `.claude/agents` (4), `.claude/skills` (4), `harness/*.ps1`.

## Not done / next
- Release signing: Android keystore + Windows code signing/installer (MSIX) – APK is debug-signed.
- Tray icon pixels not visually inspected (Windows 11 places new icons in the overflow); registration confirmed.
- Localization (English only).
- Tray-menu clicks and dragging the floating meter were not driven by automation (code paths are simple; the Dart side of the toggles is unit-tested).
- Git: public repo https://github.com/Anantha-Gokula-Raman-J/Tachyo (main, MIT, modeled on FocusTrack; commits use the GitHub no-reply address via local git config). Specs written before the first commit say `no-vcs`; new History rows use commit hashes. Release v1.0.0 published (https://github.com/Anantha-Gokula-Raman-J/Tachyo/releases/tag/v1.0.0): Windows x64 ZIP (exe, Flutter engine, VC++ runtime DLLs, LICENSE, notices), Android APK (development-signed), SHA256 file. Package locally into dist/ (gitignored).

## Where things are
- Windows build: `build\windows\x64\runner\Release\tachyo.exe`
- Android APK: `build\app\outputs\flutter-apk\app-release.apk`
- Icon masters: `assets/icon/` (regenerate: `flutter test tool/render_icon_test.dart; tool/make_icons.ps1`)
- Research: `docs/research/craft-anything-study.md`
