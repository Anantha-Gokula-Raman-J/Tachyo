# design-system spec
Source: lib/src/ui/theme/astryx_tokens.dart | Language: Dart | Commit: no-vcs | Generated: 2026-11-21

## 1. Overview
Astryx (github.com/meta/astryx, MIT) is a React/StyleX design system, so its code
cannot run in Flutter. We port its **Neutral theme tokens** (source:
packages/themes/neutral/src/neutralTheme.ts + neutralPalettes.generated.ts) into a
`ThemeExtension`. Role names map 1:1 to Astryx CSS variables. Download = `--color-info`,
upload = `--color-success`. No Astryx code or fonts are bundled; the MIT notice is
shown on the licenses page.

## 2. APIs and Use Cases
| API | Entry point (file:line) | Use case |
| --- | --- | --- |
| `AstryxTokens.light/dark` | lib/src/ui/theme/astryx_tokens.dart:65,86 | role colors per mode |
| `AstryxTokens.of` | lib/src/ui/theme/astryx_tokens.dart:107 | read tokens in widgets |
| radius/spacing constants | lib/src/ui/theme/astryx_tokens.dart:48-63 | `--radius-*` (6/10/12/28), 4 px spacing rhythm |
| `buildTheme` | lib/src/ui/theme/astryx_tokens.dart:140 | Material ThemeData from tokens |

## 3. Data Flows
- `TachyoApp.build -> buildTheme(light|dark) -> ThemeData.extensions[AstryxTokens]`
- `SpeedTile.build -> AstryxTokens.of`

## 4. Entry Points
| Entry point (method) | Usage summary | Input parameters |
| --- | --- | --- |
| `buildTheme` | follows system light/dark | `Brightness` |
| `AstryxTokens.of` | falls back to light | `BuildContext` |

## 5. Edge Cases
- Token mapping table (light / dark): body #F1F1F1/#1B1B1B, surface #FFFFFF/#262626, text primary #000/#FFF, secondary #474747/#9E9E9E, border #000@0x14/#FFF@0x1A, info #0074E2/#6D9CFE, success #198100/#64AF4C, error #C9303A/#FF705D.
- `downloadMuted`/`uploadMuted` light values are approximations of blue.light[85]/green.dark[85]; replace with exact palette stops if Astryx regenerates.
- Numbers use tabular figures so values do not jitter each second.

## 6. History
| Date | Commit | Change | Affected methods |
| --- | --- | --- | --- |
| 2026-11-21 | no-vcs | Initial port of Astryx Neutral tokens | all |
