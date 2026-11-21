#ifndef RUNNER_NATIVE_BRIDGE_H_
#define RUNNER_NATIVE_BRIDGE_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <windows.h>
#include <shellapi.h>

#include <cstdint>
#include <map>
#include <memory>
#include <optional>
#include <string>

#include "floating_meter.h"

// Windows side of the "app.tachyo/native" channel.
// Shared contract with lib/src/platform/native_bridge.dart
// (specs/platform/channel.md).
//
// - getCounters: hot-plug-safe cumulative byte counters over hardware
//   interfaces (GetIfTable2), split into Wi-Fi / mobile / other.
// - setTray / updateTray: a notification-area icon that draws the live
//   download (blue) and upload (green) values. The tray icon is always
//   present; closing the window hides it there, only tray Exit quits.
// - setFloating / updateFloating: the glass desktop meter (floating_meter.h).
// - setAutoStart / showWindow: start at Windows sign-in in the tray
//   (HKCU Run entry with --background) and reveal the window on demand.
// - quit: destroy the window after Dart flushed its data.

// Shared with main.cpp: single-instance mutex, the message a second launch
// posts to the running copy, and the sign-in (background) argument.
inline constexpr wchar_t kSingleInstanceMutex[] = L"Local\\Tachyo.SingleInstance";
inline constexpr wchar_t kShowMessageName[] = L"Tachyo.ShowWindow";
inline constexpr char kBackgroundArg[] = "--background";

class NativeBridge {
 public:
  NativeBridge(flutter::BinaryMessenger* messenger, HWND hwnd);
  ~NativeBridge();

  NativeBridge(const NativeBridge&) = delete;
  NativeBridge& operator=(const NativeBridge&) = delete;

  // Top-level window messages; returns a value when the message is consumed.
  std::optional<LRESULT> HandleMessage(HWND hwnd, UINT message, WPARAM wparam,
                                       LPARAM lparam);

 private:
  struct IfCounters {
    uint64_t in = 0;
    uint64_t out = 0;
  };

  void HandleCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  flutter::EncodableMap ReadCounters();
  void SetTray(bool enabled);
  void UpdateTray(const std::wstring& down, const std::wstring& up,
                  const std::wstring& tooltip);
  HICON RenderTrayIcon(const std::wstring& down, const std::wstring& up);
  void ShowMainWindow();
  void ShowTrayMenu();
  void RequestExit();
  void Notify(const std::string& action);
  bool SetAutoStart(bool enabled);
  bool AutoStartEnabled();

  HWND hwnd_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;

  // Hot-plug-safe accumulation: per-interface last counters by LUID.
  std::map<uint64_t, IfCounters> last_;
  uint64_t rx_ = 0, tx_ = 0, wifi_rx_ = 0, wifi_tx_ = 0, mobile_rx_ = 0,
           mobile_tx_ = 0;

  NOTIFYICONDATAW nid_{};
  bool tray_ = false;
  HICON tray_icon_ = nullptr;
  UINT taskbar_created_ = 0;
  UINT show_message_ = 0;

  std::unique_ptr<FloatingMeter> floating_;
};

#endif  // RUNNER_NATIVE_BRIDGE_H_
