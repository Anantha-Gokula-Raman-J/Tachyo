# ui module spine
Source: lib/src/ui | Language: Dart (Flutter) | Commit: no-vcs | Generated: 2026-11-21

## Responsibility
Material 3 widgets themed with Astryx design tokens. Three tabs (Live, Usage,
Settings) and the Windows floating meter. Widgets read colors from `AstryxTokens.of`
and never hard-code hex values (exception: `LogoPainter` brand colors).

## Shared types
| Type | File:line |
| --- | --- |
| `TachyoApp` | lib/src/ui/app.dart:12 |
| `HomeShell` | lib/src/ui/app.dart:32 |
| `AstryxTokens`, `buildTheme` | lib/src/ui/theme/astryx_tokens.dart:9,140 |
| `Panel`, `SectionLabel`, `SpeedTile`, `SpeedChart`, `UsageRow` | lib/src/ui/widgets/widgets.dart:12,21,36,102,205 |
| `AppLogo`, `LogoPainter` | lib/src/ui/widgets/app_logo.dart:11,21 |

## Submodules
- `design-system.md` – Astryx token port and theme.
- `pages.md` – Live, Usage, Test, Settings, HomeShell.
- `branding.md` – name, logo, icon pipeline, licenses page.

## Cross-module flows
- `TachyoApp.build -> ListenableBuilder(MeterController) -> HomeShell -> Live | Usage | SpeedTestPage | Settings`.

## Calls into other modules
state (MeterController), core (format).
