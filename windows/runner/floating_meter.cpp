#include "floating_meter.h"

// GDI+ needs min/max, which NOMINMAX removes from windows.h.
#include <algorithm>
namespace Gdiplus {
using std::max;
using std::min;
}  // namespace Gdiplus
#include <objidl.h>
#include <gdiplus.h>
#include <shellapi.h>

#include <cmath>
#include <cstdint>
#include <vector>

namespace {

constexpr wchar_t kClassName[] = L"TachyoFloatingMeter";
constexpr wchar_t kRegKey[] = L"Software\\Tachyo";

// Layout in logical pixels (scaled by the window's DPI).
constexpr float kFontPx = 12.0f;
constexpr float kPadX = 8.0f;
constexpr float kPadY = 3.0f;
constexpr float kLine = 15.0f;
constexpr float kGap = 4.0f;
constexpr float kRadius = 6.0f;
constexpr int kMargin = 8;
constexpr int kSampleBand = 6;

// Widest label the strip reserves room for, so it does not jitter.
constexpr wchar_t kTemplate[] = L"999.9 Mbps";

// Arrows as code points: the source stays ASCII, so the compiler cannot
// misread its encoding.
constexpr wchar_t kArrowDown[] = {0x2193, 0};
constexpr wchar_t kArrowUp[] = {0x2191, 0};

FloatingMeter* g_meter = nullptr;

float ScaleOf(HWND hwnd) {
  return static_cast<float>(::GetDpiForWindow(hwnd)) / 96.0f;
}

void AddRoundRect(Gdiplus::GraphicsPath& path, float x, float y, float w,
                  float h, float r) {
  const float d = r * 2;
  path.AddArc(x, y, d, d, 180, 90);
  path.AddArc(x + w - d, y, d, d, 270, 90);
  path.AddArc(x + w - d, y + h - d, d, d, 0, 90);
  path.AddArc(x, y + h - d, d, d, 90, 90);
  path.CloseFigure();
}

bool FullScreenAppRunning() {
  QUERY_USER_NOTIFICATION_STATE state;
  if (FAILED(::SHQueryUserNotificationState(&state))) return false;
  return state == QUNS_BUSY || state == QUNS_RUNNING_D3D_FULL_SCREEN ||
         state == QUNS_PRESENTATION_MODE;
}

}  // namespace

FloatingMeter::FloatingMeter(std::function<void()> on_open,
                             std::function<void()> on_menu)
    : on_open_(std::move(on_open)), on_menu_(std::move(on_menu)) {
  Gdiplus::GdiplusStartupInput input;
  Gdiplus::GdiplusStartup(&gdiplus_token_, &input, nullptr);
  g_meter = this;
}

FloatingMeter::~FloatingMeter() {
  if (hook_) ::UnhookWinEvent(hook_);
  if (hwnd_) ::DestroyWindow(hwnd_);
  g_meter = nullptr;
  Gdiplus::GdiplusShutdown(gdiplus_token_);
}

void FloatingMeter::SetEnabled(bool enabled) {
  enabled_ = enabled;
  if (enabled) {
    EnsureWindow();
    if (!hook_) {
      // Any app coming to the front (opened, closed, switched) -> come back
      // on top of it.
      hook_ = ::SetWinEventHook(EVENT_SYSTEM_FOREGROUND,
                                EVENT_SYSTEM_FOREGROUND, nullptr, OnWinEvent, 0,
                                0, WINEVENT_OUTOFCONTEXT);
    }
  } else if (hook_) {
    ::UnhookWinEvent(hook_);
    hook_ = nullptr;
  }
  Refresh();
}

void FloatingMeter::SetTopmost(bool topmost) {
  topmost_ = topmost;
  if (hwnd_ && !topmost) {
    ::SetWindowPos(hwnd_, HWND_NOTOPMOST, 0, 0, 0, 0,
                   SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
  }
  Refresh();
}

void FloatingMeter::Update(const std::wstring& down, const std::wstring& up) {
  down_ = down;
  up_ = up;
  if (!hwnd_ || !enabled_) return;
  SampleBackdrop();
  Render();
  Refresh();
}

void FloatingMeter::Refresh() {
  if (!hwnd_) return;
  fullscreen_ = FullScreenAppRunning();
  const bool want = enabled_ && !fullscreen_;
  if (want != (::IsWindowVisible(hwnd_) != FALSE)) {
    ::ShowWindow(hwnd_, want ? SW_SHOWNOACTIVATE : SW_HIDE);
  }
  if (want && topmost_) {
    ::SetWindowPos(hwnd_, HWND_TOPMOST, 0, 0, 0, 0,
                   SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE |
                       SWP_NOOWNERZORDER);
  }
}

void CALLBACK FloatingMeter::OnWinEvent(HWINEVENTHOOK, DWORD, HWND hwnd, LONG,
                                        LONG, DWORD, DWORD) {
  if (g_meter && hwnd != g_meter->hwnd_) g_meter->Refresh();
}

void FloatingMeter::EnsureWindow() {
  if (hwnd_) return;
  HINSTANCE instance = ::GetModuleHandleW(nullptr);
  WNDCLASSEXW wc = {sizeof(wc)};
  wc.style = CS_DBLCLKS;
  wc.lpfnWndProc = WndProc;
  wc.hInstance = instance;
  wc.hCursor = ::LoadCursorW(nullptr, IDC_ARROW);
  wc.lpszClassName = kClassName;
  ::RegisterClassExW(&wc);  // fails harmlessly if already registered

  hwnd_ = ::CreateWindowExW(
      WS_EX_LAYERED | WS_EX_TOOLWINDOW | WS_EX_TOPMOST | WS_EX_NOACTIVATE,
      kClassName, L"Tachyo floating meter", WS_POPUP, 0, 0, 1, 1, nullptr,
      nullptr, instance, nullptr);
  if (!hwnd_) return;
  Render();  // computes the size
  PlaceInitially();
  SampleBackdrop();
  Render();
}

void FloatingMeter::PlaceInitially() {
  DWORD x = 0, y = 0, size = sizeof(DWORD);
  bool saved =
      ::RegGetValueW(HKEY_CURRENT_USER, kRegKey, L"FloatX", RRF_RT_REG_DWORD,
                     nullptr, &x, &size) == ERROR_SUCCESS;
  size = sizeof(DWORD);
  saved = saved &&
          ::RegGetValueW(HKEY_CURRENT_USER, kRegKey, L"FloatY",
                         RRF_RT_REG_DWORD, nullptr, &y, &size) == ERROR_SUCCESS;
  POINT pos = {static_cast<LONG>(static_cast<int32_t>(x)),
               static_cast<LONG>(static_cast<int32_t>(y))};
  POINT probe = {pos.x + width_ / 2, pos.y + height_ / 2};
  if (!saved || !::MonitorFromPoint(probe, MONITOR_DEFAULTTONULL)) {
    // Default: bottom-right of the primary work area, just above the
    // taskbar's notification area.
    MONITORINFO mi = {sizeof(mi)};
    ::GetMonitorInfoW(::MonitorFromPoint({0, 0}, MONITOR_DEFAULTTOPRIMARY),
                      &mi);
    const int margin = static_cast<int>(kMargin * ScaleOf(hwnd_));
    pos = {mi.rcWork.right - width_ - margin,
           mi.rcWork.bottom - height_ - margin};
  }
  ::SetWindowPos(hwnd_, nullptr, pos.x, pos.y, 0, 0,
                 SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);
}

void FloatingMeter::SavePosition() {
  RECT r;
  if (!::GetWindowRect(hwnd_, &r)) return;
  const DWORD x = static_cast<DWORD>(r.left);
  const DWORD y = static_cast<DWORD>(r.top);
  ::RegSetKeyValueW(HKEY_CURRENT_USER, kRegKey, L"FloatX", REG_DWORD, &x,
                    sizeof(x));
  ::RegSetKeyValueW(HKEY_CURRENT_USER, kRegKey, L"FloatY", REG_DWORD, &y,
                    sizeof(y));
}

// Average brightness of a thin ring just outside the window (never the
// window itself), with hysteresis so the text does not flicker on mid-grey.
void FloatingMeter::SampleBackdrop() {
  RECT r;
  if (!::GetWindowRect(hwnd_, &r)) return;
  RECT ring = {r.left - kSampleBand, r.top - kSampleBand,
               r.right + kSampleBand, r.bottom + kSampleBand};
  RECT screen = {::GetSystemMetrics(SM_XVIRTUALSCREEN),
                 ::GetSystemMetrics(SM_YVIRTUALSCREEN), 0, 0};
  screen.right = screen.left + ::GetSystemMetrics(SM_CXVIRTUALSCREEN);
  screen.bottom = screen.top + ::GetSystemMetrics(SM_CYVIRTUALSCREEN);
  RECT area;
  if (!::IntersectRect(&area, &ring, &screen)) return;
  const int w = area.right - area.left;
  const int h = area.bottom - area.top;

  BITMAPINFO bi = {};
  bi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
  bi.bmiHeader.biWidth = w;
  bi.bmiHeader.biHeight = -h;
  bi.bmiHeader.biPlanes = 1;
  bi.bmiHeader.biBitCount = 32;
  bi.bmiHeader.biCompression = BI_RGB;
  HDC screen_dc = ::GetDC(nullptr);
  HDC mem = ::CreateCompatibleDC(screen_dc);
  void* bits = nullptr;
  HBITMAP dib =
      ::CreateDIBSection(screen_dc, &bi, DIB_RGB_COLORS, &bits, nullptr, 0);
  HGDIOBJ old = ::SelectObject(mem, dib);
  ::BitBlt(mem, 0, 0, w, h, screen_dc, area.left, area.top, SRCCOPY);
  ::GdiFlush();

  double sum = 0;
  int count = 0;
  const auto* px = static_cast<const uint8_t*>(bits);
  for (int yy = 0; yy < h; yy += 2) {
    for (int xx = 0; xx < w; xx += 2) {
      const LONG sx = area.left + xx;
      const LONG sy = area.top + yy;
      if (sx >= r.left && sx < r.right && sy >= r.top && sy < r.bottom) {
        continue;  // inside the meter itself
      }
      const uint8_t* p = px + (static_cast<size_t>(yy) * w + xx) * 4;
      sum += 0.0722 * p[0] + 0.7152 * p[1] + 0.2126 * p[2];
      ++count;
    }
  }
  ::SelectObject(mem, old);
  ::DeleteObject(dib);
  ::DeleteDC(mem);
  ::ReleaseDC(nullptr, screen_dc);
  if (count == 0) return;

  const double luminance = sum / count / 255.0;
  if (dark_backdrop_ && luminance > 0.58) dark_backdrop_ = false;
  if (!dark_backdrop_ && luminance < 0.42) dark_backdrop_ = true;
}

void FloatingMeter::Render() {
  if (!hwnd_) return;
  const float s = ScaleOf(hwnd_);

  Gdiplus::FontFamily semibold(L"Segoe UI Semibold");
  Gdiplus::FontFamily regular(L"Segoe UI");
  Gdiplus::FontFamily* family =
      semibold.GetLastStatus() == Gdiplus::Ok ? &semibold : &regular;
  Gdiplus::Font font(family, kFontPx * s, Gdiplus::FontStyleRegular,
                     Gdiplus::UnitPixel);
  Gdiplus::StringFormat format(Gdiplus::StringFormat::GenericTypographic());
  format.SetFormatFlags(format.GetFormatFlags() |
                        Gdiplus::StringFormatFlagsMeasureTrailingSpaces);

  // Measure: arrow column + the widest of the template and current labels.
  float arrow_w = 0, text_w = 0;
  {
    Gdiplus::Bitmap probe(1, 1, PixelFormat32bppPARGB);
    Gdiplus::Graphics g(&probe);
    g.SetTextRenderingHint(Gdiplus::TextRenderingHintAntiAliasGridFit);
    Gdiplus::RectF box;
    g.MeasureString(kArrowDown, -1, &font, Gdiplus::PointF(0, 0), &format, &box);
    arrow_w = box.Width;
    for (const std::wstring& t : {std::wstring(kTemplate), down_, up_}) {
      g.MeasureString(t.c_str(), -1, &font, Gdiplus::PointF(0, 0), &format,
                      &box);
      text_w = std::max(text_w, box.Width);
    }
  }
  width_ = static_cast<int>(std::ceil(kPadX * s * 2 + arrow_w + kGap * s +
                                      text_w));
  height_ = static_cast<int>(std::ceil(kPadY * s * 2 + kLine * s * 2));

  BITMAPINFO bi = {};
  bi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
  bi.bmiHeader.biWidth = width_;
  bi.bmiHeader.biHeight = -height_;
  bi.bmiHeader.biPlanes = 1;
  bi.bmiHeader.biBitCount = 32;
  bi.bmiHeader.biCompression = BI_RGB;
  HDC screen_dc = ::GetDC(nullptr);
  HDC mem = ::CreateCompatibleDC(screen_dc);
  void* bits = nullptr;
  HBITMAP dib =
      ::CreateDIBSection(screen_dc, &bi, DIB_RGB_COLORS, &bits, nullptr, 0);
  HGDIOBJ old = ::SelectObject(mem, dib);
  {
    Gdiplus::Bitmap canvas(width_, height_, width_ * 4, PixelFormat32bppPARGB,
                           static_cast<BYTE*>(bits));
    Gdiplus::Graphics g(&canvas);
    g.SetSmoothingMode(Gdiplus::SmoothingModeAntiAlias);
    g.SetTextRenderingHint(Gdiplus::TextRenderingHintAntiAliasGridFit);
    g.Clear(Gdiplus::Color(0, 0, 0, 0));

    // Glass: a faint tint and hairline edge in the backdrop's own tone, so
    // the strip blends in and only the text stands out.
    const bool dark = dark_backdrop_;
    Gdiplus::GraphicsPath path;
    AddRoundRect(path, 0.5f, 0.5f, width_ - 1.0f, height_ - 1.0f, kRadius * s);
    Gdiplus::SolidBrush tint(dark ? Gdiplus::Color(64, 16, 16, 16)
                                  : Gdiplus::Color(96, 255, 255, 255));
    g.FillPath(&tint, &path);
    Gdiplus::Pen edge(dark ? Gdiplus::Color(40, 255, 255, 255)
                           : Gdiplus::Color(30, 0, 0, 0),
                      1.0f);
    g.DrawPath(&edge, &path);

    const Gdiplus::Color text = dark ? Gdiplus::Color(255, 255, 255, 255)
                                     : Gdiplus::Color(255, 17, 17, 17);
    const Gdiplus::Color halo = dark ? Gdiplus::Color(150, 0, 0, 0)
                                     : Gdiplus::Color(170, 255, 255, 255);
    // Download blue / upload green, a shade darker on light backdrops.
    const Gdiplus::Color down_color = dark ? Gdiplus::Color(255, 0x8A, 0xB2, 0xFF)
                                           : Gdiplus::Color(255, 0x1F, 0x5F, 0xD6);
    const Gdiplus::Color up_color = dark ? Gdiplus::Color(255, 0x7C, 0xCB, 0x62)
                                         : Gdiplus::Color(255, 0x2E, 0x7D, 0x1F);

    const float text_top = (kLine - kFontPx) * s / 2 - 1.0f * s;
    auto row = [&](int index, const wchar_t* arrow, const Gdiplus::Color& tone,
                   const std::wstring& label) {
      const float y = kPadY * s + index * kLine * s + text_top;
      const float x_arrow = kPadX * s;
      const float x_text = x_arrow + arrow_w + kGap * s;
      Gdiplus::SolidBrush halo_brush(halo);
      g.DrawString(arrow, -1, &font, Gdiplus::PointF(x_arrow, y + s), &format,
                   &halo_brush);
      g.DrawString(label.c_str(), -1, &font, Gdiplus::PointF(x_text, y + s),
                   &format, &halo_brush);
      Gdiplus::SolidBrush arrow_brush(tone);
      Gdiplus::SolidBrush text_brush(text);
      g.DrawString(arrow, -1, &font, Gdiplus::PointF(x_arrow, y), &format,
                   &arrow_brush);
      g.DrawString(label.c_str(), -1, &font, Gdiplus::PointF(x_text, y),
                   &format, &text_brush);
    };
    row(0, kArrowDown, down_color, down_);
    row(1, kArrowUp, up_color, up_);
  }

  POINT src = {0, 0};
  SIZE size = {width_, height_};
  BLENDFUNCTION blend = {AC_SRC_OVER, 0, 255, AC_SRC_ALPHA};
  ::UpdateLayeredWindow(hwnd_, screen_dc, nullptr, &size, mem, &src, 0, &blend,
                        ULW_ALPHA);
  ::SelectObject(mem, old);
  ::DeleteObject(dib);
  ::DeleteDC(mem);
  ::ReleaseDC(nullptr, screen_dc);
}

LRESULT CALLBACK FloatingMeter::WndProc(HWND hwnd, UINT message, WPARAM wparam,
                                        LPARAM lparam) {
  if (g_meter && g_meter->hwnd_ == hwnd) {
    return g_meter->Handle(message, wparam, lparam);
  }
  return ::DefWindowProcW(hwnd, message, wparam, lparam);
}

LRESULT FloatingMeter::Handle(UINT message, WPARAM wparam, LPARAM lparam) {
  switch (message) {
    case WM_NCHITTEST:
      return HTCAPTION;  // drag anywhere
    case WM_MOUSEACTIVATE:
      return MA_NOACTIVATE;
    case WM_NCLBUTTONDBLCLK:
      if (on_open_) on_open_();
      return 0;
    case WM_NCRBUTTONDOWN:
      return 0;  // no system menu
    case WM_NCRBUTTONUP:
      if (on_menu_) on_menu_();
      return 0;
    case WM_EXITSIZEMOVE:
      SavePosition();
      SampleBackdrop();
      Render();
      return 0;
    case WM_DPICHANGED: {
      const auto* suggested = reinterpret_cast<const RECT*>(lparam);
      ::SetWindowPos(hwnd_, nullptr, suggested->left, suggested->top, 0, 0,
                     SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);
      Render();
      return 0;
    }
    case WM_DISPLAYCHANGE:
      PlaceInitially();  // keeps a saved spot if it is still on a monitor
      return 0;
  }
  return ::DefWindowProcW(hwnd_, message, wparam, lparam);
}
