// winsock2 must precede windows.h for iphlpapi.
#include <winsock2.h>
#include <ws2ipdef.h>
#include <iphlpapi.h>
#include <netioapi.h>

#include "native_bridge.h"

#include <dwmapi.h>
#include <flutter/standard_method_codec.h>

#include <vector>

namespace {

constexpr char kChannel[] = "app.tachyo/native";
constexpr UINT kTrayMessage = WM_APP + 1;
constexpr UINT kTrayId = 1;
constexpr UINT_PTR kQuitTimer = 4201;
constexpr UINT kMenuOpen = 1001;
constexpr UINT kMenuFloating = 1002;
constexpr UINT kMenuAutoStart = 1003;
constexpr UINT kMenuExit = 1004;
constexpr wchar_t kRunKey[] =
    L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";
constexpr wchar_t kRunValue[] = L"Tachyo";

// Astryx dark tokens used in the tray icon.
constexpr COLORREF kTrayBackground = RGB(0x1B, 0x1B, 0x1B);
constexpr COLORREF kDownload = RGB(0x6D, 0x9C, 0xFE);
constexpr COLORREF kUpload = RGB(0x64, 0xAF, 0x4C);

std::wstring Widen(const std::string& utf8) {
  if (utf8.empty()) return std::wstring();
  int len = ::MultiByteToWideChar(CP_UTF8, 0, utf8.data(),
                                  static_cast<int>(utf8.size()), nullptr, 0);
  std::wstring out(len, L'\0');
  ::MultiByteToWideChar(CP_UTF8, 0, utf8.data(), static_cast<int>(utf8.size()),
                        out.data(), len);
  return out;
}

const flutter::EncodableValue* Arg(const flutter::MethodCall<>& call,
                                   const char* key) {
  const auto* map = std::get_if<flutter::EncodableMap>(call.arguments());
  if (!map) return nullptr;
  auto it = map->find(flutter::EncodableValue(key));
  return it == map->end() ? nullptr : &it->second;
}

bool BoolArg(const flutter::MethodCall<>& call, const char* key, bool fallback) {
  const auto* v = Arg(call, key);
  if (v && std::holds_alternative<bool>(*v)) return std::get<bool>(*v);
  return fallback;
}

std::wstring StringArg(const flutter::MethodCall<>& call, const char* key) {
  const auto* v = Arg(call, key);
  if (v && std::holds_alternative<std::string>(*v)) {
    return Widen(std::get<std::string>(*v));
  }
  return std::wstring();
}

}  // namespace

NativeBridge::NativeBridge(flutter::BinaryMessenger* messenger, HWND hwnd)
    : hwnd_(hwnd) {
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, kChannel, &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    HandleCall(call, std::move(result));
  });
  taskbar_created_ = ::RegisterWindowMessageW(L"TaskbarCreated");
  show_message_ = ::RegisterWindowMessageW(kShowMessageName);
  floating_ = std::make_unique<FloatingMeter>(
      [this]() {
        ShowMainWindow();
        Notify("open");
      },
      [this]() { ShowTrayMenu(); });
}

NativeBridge::~NativeBridge() {
  floating_.reset();
  SetTray(false);
  channel_->SetMethodCallHandler(nullptr);
}

void NativeBridge::HandleCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string& m = call.method_name();
  if (m == "getCounters") {
    result->Success(flutter::EncodableValue(ReadCounters()));
  } else if (m == "setTray") {
    SetTray(BoolArg(call, "enabled", false));
    result->Success();
  } else if (m == "updateTray") {
    UpdateTray(StringArg(call, "down"), StringArg(call, "up"),
               StringArg(call, "tooltip"));
    result->Success();
  } else if (m == "setFloating") {
    floating_->SetTopmost(BoolArg(call, "onTop", true));
    floating_->SetEnabled(BoolArg(call, "enabled", false));
    result->Success();
  } else if (m == "updateFloating") {
    floating_->Update(StringArg(call, "down"), StringArg(call, "up"));
    result->Success();
  } else if (m == "setAutoStart") {
    result->Success(
        flutter::EncodableValue(SetAutoStart(BoolArg(call, "enabled", false))));
  } else if (m == "showWindow") {
    ShowMainWindow();
    result->Success();
  } else if (m == "quit") {
    result->Success();
    ::DestroyWindow(hwnd_);
  } else {
    result->NotImplemented();
  }
}

flutter::EncodableMap NativeBridge::ReadCounters() {
  PMIB_IF_TABLE2 table = nullptr;
  if (::GetIfTable2(&table) == NO_ERROR && table) {
    std::map<uint64_t, IfCounters> seen;
    for (ULONG i = 0; i < table->NumEntries; ++i) {
      const MIB_IF_ROW2& row = table->Table[i];
      // Physical adapters only: skips loopback, VPN/virtual adapters (their
      // traffic also crosses a physical adapter) and NDIS filter entries that
      // would double count.
      if (row.Type == IF_TYPE_SOFTWARE_LOOPBACK) continue;
      if (!row.InterfaceAndOperStatusFlags.HardwareInterface) continue;
      if (row.InterfaceAndOperStatusFlags.FilterInterface) continue;

      const uint64_t luid = row.InterfaceLuid.Value;
      IfCounters now{row.InOctets, row.OutOctets};
      seen[luid] = now;
      auto prev = last_.find(luid);
      // A new or reset interface contributes nothing this round: plugging in
      // an adapter must not look like a burst of traffic.
      if (prev == last_.end() || now.in < prev->second.in ||
          now.out < prev->second.out) {
        continue;
      }
      const uint64_t d_in = now.in - prev->second.in;
      const uint64_t d_out = now.out - prev->second.out;
      rx_ += d_in;
      tx_ += d_out;
      if (row.Type == IF_TYPE_IEEE80211) {
        wifi_rx_ += d_in;
        wifi_tx_ += d_out;
      } else if (row.Type == IF_TYPE_WWANPP || row.Type == IF_TYPE_WWANPP2) {
        mobile_rx_ += d_in;
        mobile_tx_ += d_out;
      }
    }
    last_.swap(seen);
    ::FreeMibTable(table);
  }

  auto v = [](uint64_t x) {
    return flutter::EncodableValue(static_cast<int64_t>(x));
  };
  return flutter::EncodableMap{
      {flutter::EncodableValue("rx"), v(rx_)},
      {flutter::EncodableValue("tx"), v(tx_)},
      {flutter::EncodableValue("wifiRx"), v(wifi_rx_)},
      {flutter::EncodableValue("wifiTx"), v(wifi_tx_)},
      {flutter::EncodableValue("mobileRx"), v(mobile_rx_)},
      {flutter::EncodableValue("mobileTx"), v(mobile_tx_)},
      {flutter::EncodableValue("t"), v(::GetTickCount64())},
  };
}

void NativeBridge::SetTray(bool enabled) {
  if (enabled == tray_) return;
  if (enabled) {
    nid_ = {};
    nid_.cbSize = sizeof(nid_);
    nid_.hWnd = hwnd_;
    nid_.uID = kTrayId;
    nid_.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP;
    nid_.uCallbackMessage = kTrayMessage;
    if (!tray_icon_) tray_icon_ = RenderTrayIcon(L"0", L"0");
    nid_.hIcon = tray_icon_;
    wcscpy_s(nid_.szTip, L"Tachyo - Net Speed Meter");
    tray_ = ::Shell_NotifyIconW(NIM_ADD, &nid_) != FALSE;
  } else {
    ::Shell_NotifyIconW(NIM_DELETE, &nid_);
    tray_ = false;
    if (tray_icon_) {
      ::DestroyIcon(tray_icon_);
      tray_icon_ = nullptr;
    }
  }
}

void NativeBridge::UpdateTray(const std::wstring& down, const std::wstring& up,
                              const std::wstring& tooltip) {
  if (!tray_) return;
  HICON next = RenderTrayIcon(down, up);
  nid_.hIcon = next;
  nid_.uFlags = NIF_ICON | NIF_TIP;
  wcsncpy_s(nid_.szTip, tooltip.c_str(), _TRUNCATE);
  ::Shell_NotifyIconW(NIM_MODIFY, &nid_);
  if (tray_icon_) ::DestroyIcon(tray_icon_);
  tray_icon_ = next;
}

HICON NativeBridge::RenderTrayIcon(const std::wstring& down,
                                   const std::wstring& up) {
  const UINT dpi = ::GetDpiForWindow(hwnd_);
  const int size = ::GetSystemMetricsForDpi(SM_CXSMICON, dpi);

  BITMAPINFO bmi = {};
  bmi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
  bmi.bmiHeader.biWidth = size;
  bmi.bmiHeader.biHeight = -size;  // top-down
  bmi.bmiHeader.biPlanes = 1;
  bmi.bmiHeader.biBitCount = 32;
  bmi.bmiHeader.biCompression = BI_RGB;

  HDC screen = ::GetDC(nullptr);
  HDC mem = ::CreateCompatibleDC(screen);
  void* bits = nullptr;
  HBITMAP color =
      ::CreateDIBSection(screen, &bmi, DIB_RGB_COLORS, &bits, nullptr, 0);
  HGDIOBJ old_bitmap = ::SelectObject(mem, color);

  RECT all = {0, 0, size, size};
  HBRUSH bg = ::CreateSolidBrush(kTrayBackground);
  ::FillRect(mem, &all, bg);
  ::DeleteObject(bg);

  HFONT font = ::CreateFontW(-(size / 2 + 1), 0, 0, 0, FW_BOLD, FALSE, FALSE,
                             FALSE, DEFAULT_CHARSET, OUT_DEFAULT_PRECIS,
                             CLIP_DEFAULT_PRECIS, ANTIALIASED_QUALITY,
                             DEFAULT_PITCH, L"Segoe UI");
  HGDIOBJ old_font = ::SelectObject(mem, font);
  ::SetBkMode(mem, TRANSPARENT);
  RECT top = {0, -1, size, size / 2};
  RECT bottom = {0, size / 2 - 1, size, size};
  ::SetTextColor(mem, kDownload);
  ::DrawTextW(mem, down.c_str(), -1, &top,
              DT_CENTER | DT_VCENTER | DT_SINGLELINE | DT_NOCLIP);
  ::SetTextColor(mem, kUpload);
  ::DrawTextW(mem, up.c_str(), -1, &bottom,
              DT_CENTER | DT_VCENTER | DT_SINGLELINE | DT_NOCLIP);
  ::GdiFlush();

  // GDI leaves alpha at 0; the tile is fully opaque.
  auto* px = static_cast<uint32_t*>(bits);
  for (int i = 0; i < size * size; ++i) px[i] |= 0xFF000000;

  ::SelectObject(mem, old_font);
  ::DeleteObject(font);
  ::SelectObject(mem, old_bitmap);

  std::vector<uint8_t> mask_bits(((size + 15) / 16) * 2 * size, 0);
  HBITMAP mask = ::CreateBitmap(size, size, 1, 1, mask_bits.data());
  ICONINFO info = {TRUE, 0, 0, mask, color};
  HICON icon = ::CreateIconIndirect(&info);

  ::DeleteObject(mask);
  ::DeleteObject(color);
  ::DeleteDC(mem);
  ::ReleaseDC(nullptr, screen);
  return icon;
}

void NativeBridge::ShowMainWindow() {
  if (::IsIconic(hwnd_)) ::ShowWindow(hwnd_, SW_RESTORE);
  ::ShowWindow(hwnd_, SW_SHOW);
  ::SetForegroundWindow(hwnd_);
}

void NativeBridge::ShowTrayMenu() {
  HMENU menu = ::CreatePopupMenu();
  ::AppendMenuW(menu, MF_STRING, kMenuOpen, L"Open Tachyo");
  ::AppendMenuW(menu, MF_STRING | (floating_->enabled() ? MF_CHECKED : 0),
                kMenuFloating, L"Floating meter");
  ::AppendMenuW(menu, MF_STRING | (AutoStartEnabled() ? MF_CHECKED : 0),
                kMenuAutoStart, L"Start with Windows");
  ::AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
  ::AppendMenuW(menu, MF_STRING, kMenuExit, L"Exit");
  POINT pt;
  ::GetCursorPos(&pt);
  ::SetForegroundWindow(hwnd_);  // so the menu closes on outside click
  const UINT cmd = ::TrackPopupMenu(
      menu, TPM_RETURNCMD | TPM_NONOTIFY | TPM_RIGHTBUTTON, pt.x, pt.y, 0,
      hwnd_, nullptr);
  ::DestroyMenu(menu);
  if (cmd == kMenuOpen) {
    ShowMainWindow();
    Notify("open");
  } else if (cmd == kMenuFloating) {
    Notify("toggleFloating");  // Dart saves the setting and calls setFloating
  } else if (cmd == kMenuAutoStart) {
    Notify("toggleAutoStart");
  } else if (cmd == kMenuExit) {
    RequestExit();
  }
}

void NativeBridge::RequestExit() {
  // Dart flushes usage, then calls "quit". Fallback if it never answers.
  Notify("exit");
  ::SetTimer(hwnd_, kQuitTimer, 1500, nullptr);
}

// HKCU Run entry: no admin rights needed, per-user, removed when disabled.
bool NativeBridge::SetAutoStart(bool enabled) {
  HKEY key = nullptr;
  if (::RegOpenKeyExW(HKEY_CURRENT_USER, kRunKey, 0, KEY_SET_VALUE, &key) !=
      ERROR_SUCCESS) {
    return false;
  }
  LSTATUS status;
  if (enabled) {
    wchar_t path[MAX_PATH];
    const DWORD len = ::GetModuleFileNameW(nullptr, path, MAX_PATH);
    if (len == 0 || len >= MAX_PATH) {
      ::RegCloseKey(key);
      return false;
    }
    const std::wstring command =
        L"\"" + std::wstring(path, len) + L"\" " + Widen(kBackgroundArg);
    status = ::RegSetValueExW(
        key, kRunValue, 0, REG_SZ, reinterpret_cast<const BYTE*>(command.c_str()),
        static_cast<DWORD>((command.size() + 1) * sizeof(wchar_t)));
  } else {
    status = ::RegDeleteValueW(key, kRunValue);
    if (status == ERROR_FILE_NOT_FOUND) status = ERROR_SUCCESS;
  }
  ::RegCloseKey(key);
  return status == ERROR_SUCCESS;
}

bool NativeBridge::AutoStartEnabled() {
  return ::RegGetValueW(HKEY_CURRENT_USER, kRunKey, kRunValue, RRF_RT_REG_SZ,
                        nullptr, nullptr, nullptr) == ERROR_SUCCESS;
}

void NativeBridge::Notify(const std::string& action) {
  channel_->InvokeMethod(
      "trayAction", std::make_unique<flutter::EncodableValue>(action));
}

std::optional<LRESULT> NativeBridge::HandleMessage(HWND hwnd, UINT message,
                                                   WPARAM wparam,
                                                   LPARAM lparam) {
  if (message == kTrayMessage) {
    const UINT event = LOWORD(lparam);
    if (event == WM_LBUTTONUP || event == WM_LBUTTONDBLCLK) {
      ShowMainWindow();
      Notify("open");
    } else if (event == WM_RBUTTONUP || event == WM_CONTEXTMENU) {
      ShowTrayMenu();
    }
    return 0;
  }
  if (taskbar_created_ != 0 && message == taskbar_created_ && tray_) {
    // Explorer restarted: the icon is gone, add it again.
    tray_ = false;
    SetTray(true);
    return 0;
  }
  if (show_message_ != 0 && message == show_message_) {
    // A second launch asked the running copy to come forward.
    ShowMainWindow();
    Notify("open");
    return 0;
  }
  switch (message) {
    case WM_QUERYENDSESSION:
      // Sign-out / shutdown: save usage now; the process may not get to
      // run the tray Exit handshake.
      Notify("flush");
      return TRUE;
    case WM_CLOSE:
      // Closing the window only hides it: metering continues in the tray and
      // the floating meter. Exit from the tray menu is the only way to quit.
      ::ShowWindow(hwnd, SW_HIDE);
      return 0;
    case WM_TIMER:
      if (wparam == kQuitTimer) {
        ::KillTimer(hwnd, kQuitTimer);
        ::DestroyWindow(hwnd);
        return 0;
      }
      break;
  }
  return std::nullopt;
}
