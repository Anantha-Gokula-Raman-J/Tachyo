#ifndef RUNNER_FLOATING_METER_H_
#define RUNNER_FLOATING_METER_H_

#include <windows.h>

#include <functional>
#include <string>

// The desktop floating meter: a small two-line "glass" strip that shows the
// live download and upload speed on top of every window.
//
// - Its own per-pixel-alpha layered window (WS_EX_LAYERED), independent of
//   the Flutter window, so the app window can be hidden to the tray while
//   the meter stays on screen.
// - WS_EX_TOOLWINDOW + WS_EX_NOACTIVATE: no taskbar button, never steals
//   focus.
// - Glass: a faint translucent tint; the text color follows the brightness
//   of what is behind it (light text on dark backgrounds, dark text on
//   light ones), sampled from a thin ring just outside the window.
// - Stays in front: re-asserts HWND_TOPMOST on every foreground change and
//   every update; hides itself while a full-screen app or presentation runs.
// - Drag to move (position remembered in HKCU\Software\Tachyo), double-click
//   to open the app, right-click for the tray menu.
class FloatingMeter {
 public:
  FloatingMeter(std::function<void()> on_open, std::function<void()> on_menu);
  ~FloatingMeter();

  FloatingMeter(const FloatingMeter&) = delete;
  FloatingMeter& operator=(const FloatingMeter&) = delete;

  // User setting "Floating meter".
  void SetEnabled(bool enabled);
  bool enabled() const { return enabled_; }

  // User setting "Keep on top".
  void SetTopmost(bool topmost);

  // New speed labels, e.g. L"94.1 Kbps" / L"361 Kbps".
  void Update(const std::wstring& down, const std::wstring& up);

  // Re-checks full-screen state, visibility and z-order.
  void Refresh();

 private:
  static LRESULT CALLBACK WndProc(HWND hwnd, UINT message, WPARAM wparam,
                                  LPARAM lparam);
  static void CALLBACK OnWinEvent(HWINEVENTHOOK hook, DWORD event, HWND hwnd,
                                  LONG id_object, LONG id_child, DWORD thread,
                                  DWORD time);
  LRESULT Handle(UINT message, WPARAM wparam, LPARAM lparam);

  void EnsureWindow();
  void PlaceInitially();
  void Render();
  void SampleBackdrop();
  void SavePosition();

  std::function<void()> on_open_;
  std::function<void()> on_menu_;

  HWND hwnd_ = nullptr;
  HWINEVENTHOOK hook_ = nullptr;
  ULONG_PTR gdiplus_token_ = 0;

  std::wstring down_ = L"0 B/s";
  std::wstring up_ = L"0 B/s";
  bool enabled_ = false;
  bool topmost_ = true;
  bool fullscreen_ = false;
  bool dark_backdrop_ = true;
  int width_ = 0;
  int height_ = 0;
};

#endif  // RUNNER_FLOATING_METER_H_
