---
name: tachyo-qa
description: Test procedure for Tachyo on Windows and the Android emulator - quality gate, wiping and booting the emulator, installing the APK, status-bar and reboot checks, driving and screenshotting the Windows build, tray and exit checks. Use when asked to test, verify, QA, smoke test, or wipe/restart the emulator for this project.
---

# Tachyo QA procedure

Evidence beats assertions: every PASS cites a command result or a screenshot path.

## 1. Gate (always)
`powershell -ExecutionPolicy Bypass -File harness/verify.ps1 -Build` → must end with `VERIFY OK`.

## 2. Android (emulator Medium_Phone, API 37)
- Fresh device: `harness/android_test.ps1 -Wipe -Reboot` (wipes emulator data – only when asked or when state is suspect).
- Normal: `harness/android_test.ps1 [-Reboot]`.
- Checks it performs: install, launch, enable meter (grants POST_NOTIFICATIONS), foreground service running, status-bar screenshot, restart after reboot.
- Look at `statusbar.png`: the speed icon must be readable next to the clock. Silent (LOW) channels hide it – a regression to watch.
- Usage with meter off: generate traffic while the app is open (`adb shell ping -c 30 -i 0.2 -s 1400 8.8.8.8`), force-stop, relaunch, Today must not drop.
- Read UI text with `uiautomator dump`; Flutter merges a row into one node, so tap node centers only on full-row targets.

## 3. Windows
- Launch `build\windows\x64\runner\Release\tachyo.exe`.
- `tool/win_drive.ps1 -Shot live` (screenshot); `-ClickX/-ClickY` click relative to the window (physical px; 125% scaling → logical × 1.25). Never click outside the Tachyo window.
- If `Add-Type` compilation is blocked (win_drive.ps1 fails with "Access ... denied"), use `tool/win_check.ps1`, which needs no compiled helper.
- `tool/win_check.ps1 [-CloseMain] [-Shot file.png]` reports the main window and the floating meter (class `TachyoFloatingMeter`) and saves a 2x crop around the meter.
- Floating meter: shown on launch (about 112×45 px at 125 %), bottom-right above the tray, no taskbar button. Settings → Floating meter off hides it; on shows it again.
- Close: `win_check.ps1 -CloseMain` → main window hidden, process alive, floating meter still shown. The tray icon is always on (registration in `HKCU:\Control Panel\NotifyIconSettings`).
- In front: open any app → meter still visible; a full-screen window → meter hides until it ends.
- Light/dark: a white window under the meter → dark text on a light tint; dark desktop → white text. PowerShell 5.1 is DPI-unaware: place test windows in logical px (physical ÷ scale), while screen captures use physical px.
- Before any click: take a `-Shot` and confirm it shows Tachyo. When another window is full-screen (e.g. the Claude app), `SetForegroundWindow` fails, the shot shows that window, and a click lands in it; the floating meter is correctly hidden then. Stop and ask the user to exit full screen.
- Traffic for meter checks: repeat `__down?bytes=50000000`; requests of ~150 MB and more get 403, and many full speed tests in a row get 429 for a while.
- Never leave test apps open. The Windows 11 Notepad restores the user's previous tabs, so use a blank WinForms window and close it with the test.
- Speed format: Settings → KB/s → meter and tray read "x.xx KB/s"; set back to Auto.
- Speed test: Test tab → Start test → status reaches "Server … · used … MB" with non-zero Download/Upload. Real-server check without the UI: `flutter test tool/speedtest_live_test.dart` (uses 100–400 MB).
- Exit: post WM_APP+1 (0x8001) with lParam WM_RBUTTONUP (0x205), then Up + Enter (Exit is the last menu item) → process exits and `%APPDATA%\Tachyo\usage.json` LastWriteTime updates.
- Single instance: a second `Start-Process tachyo.exe` leaves one process and shows the window.
- Sign-in start: with Start with Windows on, `HKCU:\Software\Microsoft\Windows\CurrentVersion\Run` has `Tachyo = "...tachyo.exe" --background`. Launching with `--background` shows no main window, only the tray and floating meter. Remove the Run value after testing on a developer PC.

## 4. Report
`_workspace/03_qa-tester_report.md` with each step, evidence path, and `QA PASS` / `QA FAIL`.
