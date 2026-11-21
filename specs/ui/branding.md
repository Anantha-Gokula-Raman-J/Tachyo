# branding spec
Source: lib/src/app_info.dart, lib/src/ui/widgets/app_logo.dart, tool/render_icon_test.dart, tool/make_icons.ps1 | Language: Dart, PowerShell | Commit: no-vcs | Generated: 2026-11-21

## 1. Overview
- **Name:** Tachyo (from *tachometer*): "Tachyo – Net Speed Meter".
- **Publisher:** none - standalone open-source app by Anantha Gokula Raman J, MIT License (no company or organization). Package/app id `app.tachyo`.
- **Mark:** a 270° tachometer arc fading from download blue (#6D9CFE) to upload green (#64AF4C) with a white tip, around a blue ↓ and green ↑ arrow, on a near-black Astryx tile.
- **Single source:** `LogoPainter` draws the in-app logo and is rendered to PNG for every platform icon.

## 2. APIs and Use Cases
| API | Entry point (file:line) | Use case |
| --- | --- | --- |
| `AppInfo` | lib/src/app_info.dart:1 | name, tagline, publisher, version |
| `astryxLicense` | lib/src/app_info.dart:11 | MIT notice registered in main |
| `LogoPainter.paint` | lib/src/ui/widgets/app_logo.dart:34 | the mark |
| `tool/render_icon_test.dart` | tool/render_icon_test.dart | renders assets/icon/tachyo_icon.png (1024) + tachyo_foreground.png (432) |
| `tool/make_icons.ps1` | tool/make_icons.ps1 | Android mipmaps + adaptive/monochrome icon + Windows .ico (16–256) |

## 3. Data Flows
- Icon pipeline: `flutter test tool/render_icon_test.dart -> LogoPainter.paint -> PNG masters -> make_icons.ps1 -> mipmap-*/ic_launcher*.png, mipmap-anydpi-v26/ic_launcher.xml, windows/runner/resources/app_icon.ico`
- Licenses: `main -> LicenseRegistry.addLicense(astryxLicense) -> SettingsPage Licenses -> showLicensePage`

## 4. Entry Points
| Entry point (method) | Usage summary | Input parameters |
| --- | --- | --- |
| `AppLogo(size, withTile)` | in-app logo | double, bool |
| `LogoPainter(withTile, contentScale)` | `contentScale` 0.62 keeps the adaptive-icon safe zone | bool, double |

## 5. Edge Cases
- Arc gradient wraps blue at both ends so the start cap never shows green.
- Adaptive icon background color `#1B1B1B` (values/ic_launcher_background.xml).
- Status-bar / tray icons are drawn at runtime (speed), not from these assets.

## 6. History
| Date | Commit | Change | Affected methods |
| --- | --- | --- | --- |
| 2026-11-21 | no-vcs | Initial brand + icon pipeline | all |
| 2026-11-21 | no-vcs | Rebranded: standalone MIT app, id app.tachyo, no publisher | AppInfo |
| 2026-11-21 | no-vcs | Copyright holder: the author, MIT | branding |
