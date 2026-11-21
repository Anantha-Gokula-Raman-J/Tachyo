# Third-party licenses

Policy: third-party code and assets must be MIT or Apache-2.0.

## Runtime dependencies
| Component | License | How it is used |
| --- | --- | --- |
| *(none)* | – | `pubspec.yaml` depends only on the Flutter SDK. No pub packages, no Gradle libraries beyond what the Flutter Android embedding itself requires, no Windows libraries beyond the OS SDK (iphlpapi, shell32, dwmapi, gdiplus). |

The Flutter/Dart SDK (BSD-3-Clause) is the platform the app is built with, not an
added dependency; the default `cupertino_icons` and `flutter_lints` packages that
`flutter create` adds were removed to honour the policy.

## Shipped in release packages (platform runtime, not source dependencies)
| Component | License | Where |
| --- | --- | --- |
| Flutter engine (`flutter_windows.dll`, `data/`; `libflutter.so` in the APK) | BSD-3-Clause | Every Flutter app ships it. |
| Microsoft Visual C++ runtime (`msvcp140.dll`, `vcruntime140.dll`, `vcruntime140_1.dll`) | Microsoft Visual C++ Redistributable terms | Windows ZIP only, so the app runs without installing the redistributable. Not used by Tachyo's source directly; required by any MSVC-built program. |

## Design and tooling (not shipped as code)
| Component | License | Use |
| --- | --- | --- |
| [Astryx](https://github.com/meta/astryx) (Meta Platforms) | MIT | Neutral theme color/radius/spacing tokens ported to `lib/src/ui/theme/astryx_tokens.dart`. Notice shown on the in-app licenses page. |
| [Craft Anything](https://github.com/storytold/craft-anything) v0.6.1 | MIT OR Apache-2.0 | Clean-room feature study (`docs/research/craft-anything-study.md`). Not shipped. |
| Material Icons (Flutter SDK font) | Apache-2.0 | UI icons, tree-shaken. |

## Network service (not code)
| Service | Use |
| --- | --- |
| Cloudflare speed test endpoints (`speed.cloudflare.com/__down`, `/__up`, `/meta` for provider name and server city) | The in-app speed test downloads and uploads test data to these public endpoints using Dart's built-in HTTP client. No Cloudflare code or library is included. The app states this on the Test page. |
