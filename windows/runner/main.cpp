#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  // One Tachyo per user session: a second launch (Start menu, shortcut)
  // brings the running copy forward instead of adding a second tray icon.
  HANDLE single = ::CreateMutexW(nullptr, TRUE, kSingleInstanceMutex);
  if (single && ::GetLastError() == ERROR_ALREADY_EXISTS) {
    HWND existing = ::FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", L"Tachyo");
    if (existing) {
      ::PostMessageW(existing, ::RegisterWindowMessageW(kShowMessageName), 0,
                     0);
    }
    ::CloseHandle(single);
    ::CoUninitialize();
    return EXIT_SUCCESS;
  }

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  // "--background" is what the Windows sign-in entry passes: start in the
  // tray (and floating meter, if it was open) without showing the window.
  bool background = false;
  for (const auto& arg : command_line_arguments) {
    if (arg == kBackgroundArg) background = true;
  }

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project, background);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(440, 780);
  if (!window.Create(L"Tachyo", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  if (single) ::CloseHandle(single);
  return EXIT_SUCCESS;
}
