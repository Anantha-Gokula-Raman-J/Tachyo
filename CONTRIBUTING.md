# Contributing to Tachyo
Thanks for helping make a simple, honest net speed meter.

## Before you start
Read AGENTS.md, ARCHITECTURE.md, specs/INDEX.md and the relevant module spec. Use harness/context.ps1 -Feature <ID> for context. Update the spec first if behavior changes.

## Development
Install Flutter, the Visual Studio C++ toolchain and the Android SDK described in README.md. Run flutter pub get, then harness/verify.ps1 -Build. For platform changes also exercise the real behavior: on Windows the tray, floating meter, close-to-tray, Start with Windows and Exit; on Android the status-bar meter, notification and restart after reboot.
Keep shared contracts identical: the method channel (specs/platform/channel.md), format.dart and SpeedFormat.kt, settings keys.
Third-party code must be MIT or Apache-2.0 and recorded in THIRD_PARTY_LICENSES.md.

## Pull requests
Explain the problem, intended behavior, edge cases, tests run and remaining manual checks. Include screenshots for UI changes with personal details (IP address, provider, location) removed.
Do not commit build artifacts, logs, keystores, credentials, usage or settings files, or IDE settings.

## Issues
Include app version, Windows or Android version, device or emulator, reproduction steps and expected/actual behavior. For speed differences, say which other meter or test you compared with and when.

By contributing, you agree that your contribution may be distributed under this project's MIT license.
