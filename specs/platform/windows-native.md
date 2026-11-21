# windows-native spec
Source: windows/runner (native_bridge.h/.cpp, floating_meter.h/.cpp, flutter_window.cpp, main.cpp, Runner.rc) | Language: C++ | Commit: no-vcs | Generated: 2026-11-21

## 1. Overview
Win32 side with no third-party code (iphlpapi, shell32, dwmapi, gdiplus — all part of Windows).
- `NativeBridge` owns the channel, reads interface counters, draws the tray speed icon, runs
  the tray menu, the sign-in entry and the close/exit rules.
- `FloatingMeter` is the desktop glass meter: its own layered tool window, independent of the
  Flutter window, so the app window can be hidden while the meter stays on screen.
- Tachyo on Windows lives in the tray: the tray icon is always present, closing the window
  only hides it, and only tray **Exit** quits.
Window: "Tachyo", 440×780 logical (main.cpp). Version resource: Anantha Gokula Raman J, MIT License.

## 2. APIs and Use Cases
| API | Entry point (file:line) | Use case |
| --- | --- | --- |
| `NativeBridge::HandleCall` | windows/runner/native_bridge.cpp:90 | channel dispatch |
| `NativeBridge::ReadCounters` | windows/runner/native_bridge.cpp:124 | hot-plug-safe accumulated counters |
| `NativeBridge::SetTray` / `UpdateTray` | windows/runner/native_bridge.cpp:177,200 | tray icon add/remove, new icon + tooltip each second |
| `NativeBridge::RenderTrayIcon` | windows/runner/native_bridge.cpp:212 | GDI: blue down value over green up value |
| `NativeBridge::ShowTrayMenu` | windows/runner/native_bridge.cpp:279 | Open Tachyo / Floating meter ✓ / Start with Windows ✓ / Exit |
| `NativeBridge::SetAutoStart` / `AutoStartEnabled` | windows/runner/native_bridge.cpp:314,341 | HKCU Run entry `"tachyo.exe" --background` |
| `NativeBridge::HandleMessage` | windows/runner/native_bridge.cpp:351 | tray clicks, TaskbarCreated, second launch, end session, WM_CLOSE, quit timer |
| `FloatingMeter::SetEnabled` / `SetTopmost` | windows/runner/floating_meter.cpp:80,98 | show/hide, on-top, foreground hook |
| `FloatingMeter::Update` | windows/runner/floating_meter.cpp:107 | new labels -> sample backdrop -> render -> refresh |
| `FloatingMeter::Refresh` | windows/runner/floating_meter.cpp:116 | full-screen hide, visibility, re-assert HWND_TOPMOST |
| `FloatingMeter::PlaceInitially` / `SavePosition` | windows/runner/floating_meter.cpp:157,183 | remembered spot (HKCU\Software\Tachyo FloatX/FloatY) or bottom-right above the tray |
| `FloatingMeter::SampleBackdrop` | windows/runner/floating_meter.cpp:196 | brightness of a 6 px ring outside the meter |
| `FloatingMeter::Render` | windows/runner/floating_meter.cpp:252 | GDI+ into a premultiplied DIB -> UpdateLayeredWindow |
| `FloatingMeter::Handle` | windows/runner/floating_meter.cpp:370 | drag, double-click, right-click, DPI change |

## 3. Data Flows
- Counters: `NativeBridge.read (Dart) -> NativeBridge::HandleCall -> NativeBridge::ReadCounters -> GetIfTable2`
- Tray: `WindowsMeterPlatform.onSample -> NativeBridge::UpdateTray -> NativeBridge::RenderTrayIcon -> Shell_NotifyIconW(NIM_MODIFY)`
- Floating labels: `WindowsMeterPlatform.onSample -> HandleCall("updateFloating") -> FloatingMeter::Update -> FloatingMeter::SampleBackdrop -> FloatingMeter::Render -> FloatingMeter::Refresh`
- Floating settings: `WindowsMeterPlatform.applySettings -> HandleCall("setFloating") -> FloatingMeter::SetTopmost + FloatingMeter::SetEnabled -> SetWinEventHook(EVENT_SYSTEM_FOREGROUND)`
- Stay in front: `any app activated -> FloatingMeter::OnWinEvent -> FloatingMeter::Refresh -> SetWindowPos(HWND_TOPMOST)`
- Close: `WM_CLOSE -> NativeBridge::HandleMessage -> ShowWindow(SW_HIDE)` (always; tray + floating meter keep running)
- Exit: `NativeBridge::ShowTrayMenu -> NativeBridge::RequestExit -> NativeBridge::Notify("exit") -> (Dart flush) -> HandleCall("quit") -> DestroyWindow`
- Floating meter mouse: `double-click -> FloatingMeter::Handle -> on_open (ShowMainWindow + Notify("open"))`; `right-click -> on_menu (NativeBridge::ShowTrayMenu)`; `drag end -> FloatingMeter::SavePosition`
- Sign-in: `NativeBridge::SetAutoStart -> RegSetValueExW(HKCU\...\Run, "Tachyo", "\"exe\" --background")`; disabled -> RegDeleteValueW; `wWinMain --background -> FlutterWindow(start_hidden)`
- Second launch: `wWinMain -> CreateMutexW(Local\Tachyo.SingleInstance) exists -> PostMessage("Tachyo.ShowWindow") -> exit`; running copy: `HandleMessage -> ShowMainWindow + Notify("open")`
- Wiring: `FlutterWindow::OnCreate -> NativeBridge ctor -> FloatingMeter ctor (GdiplusStartup)`; `FlutterWindow::MessageHandler -> NativeBridge::HandleMessage`; `FlutterWindow::OnDestroy -> ~NativeBridge -> ~FloatingMeter, SetTray(false)`

## 4. Entry Points
| Entry point (method) | Usage summary | Input parameters |
| --- | --- | --- |
| `NativeBridge::HandleCall` | method channel | MethodCall, MethodResult |
| `NativeBridge::HandleMessage` | top-level window messages | hwnd, message, wparam, lparam |
| `FloatingMeter::Handle` | floating meter window messages | message, wparam, lparam |
| `wWinMain` | single instance, `--background` | command line |

## 5. Edge Cases
- Only hardware, non-filter, non-loopback interfaces counted -> VPN/virtual adapters and NDIS filter rows do not double count.
- New or reset interface (LUID unseen or counters decreased) contributes 0 that round -> plugging an adapter never spikes.
- Explorer restart (`TaskbarCreated`) -> tray icon re-added.
- Windows 11 hides new tray icons in the overflow until the user pins them (OS behavior).
- Floating meter: WS_EX_LAYERED | WS_EX_TOOLWINDOW | WS_EX_TOPMOST | WS_EX_NOACTIVATE -> no taskbar button, never takes focus.
- Glass: tint alpha 64 (dark backdrop) / 96 (light); text white or #111 with an opposite 1 px halo; switches at luminance > 0.58 / < 0.42 (hysteresis, no flicker).
- The backdrop ring is outside the meter, so the meter never samples itself (layered windows may or may not be in a screen BitBlt).
- Full-screen app / presentation (SHQueryUserNotificationState BUSY, D3D full screen, presentation) -> meter hides, returns afterwards.
- Width fits "999.9 Mbps" and grows for longer fixed-unit labels; 2 lines of 15 px at 12 px Segoe UI Semibold (about 100×36 logical).
- Saved position off every monitor (display removed) -> default spot; WM_DISPLAYCHANGE re-checks.
- Arrow glyphs are code points (`kArrowDown/kArrowUp`) — keep C++ sources ASCII, MSVC reads UTF-8 without BOM as the ANSI code page.
- GDI+ needs `min/max`; the runner defines NOMINMAX, so floating_meter.cpp maps `std::min/max` into `Gdiplus` before including gdiplus.h.
- Exit fallback timer 1.5 s if Dart does not call `quit`.
- WM_QUERYENDSESSION asks Dart to flush; usage written at most one flush interval late otherwise.

## 6. History
| Date | Commit | Change | Affected methods |
| --- | --- | --- | --- |
| 2026-11-21 | no-vcs | Initial spec | all |
| 2026-11-21 | no-vcs | Tachyo contributors (MIT) version resource; tool-window floating meter; Run-key sign-in start; single instance; end-session flush | SetCompact, SetAutoStart, HandleMessage, wWinMain, FlutterWindow::OnCreate |
| 2026-11-21 | no-vcs | Native glass FloatingMeter replaces the shrink-the-window compact mode; tray always on, close always hides; tray menu toggles floating meter and sign-in | FloatingMeter::*, ShowTrayMenu, HandleCall, HandleMessage |
| 2026-11-21 | no-vcs | Copyright holder set to the author (as in FocusTrack) for the public repo | Runner.rc |
