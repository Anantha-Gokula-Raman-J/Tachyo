---
name: tachyo-dev
description: How to change Tachyo's code correctly - layer boundaries, platform channel rules, Astryx tokens, license policy, testing conventions. Use whenever editing lib/, android/ or windows/runner in the Net Speed Meter project.
---

# Tachyo development guide

## Read the spec first
1. `specs/INDEX.md` → module `common/README.md` → submodule spec (Entry Points, Data Flows).
2. Read source only for the methods named there, by line range.
3. Update the spec's affected sections + History row in the same change.

## Layers (why: keeps logic testable without devices)
- `core` – pure Dart, no Flutter imports. All math/format lives here and is unit-tested.
- `data` – persistence behind `UsageRepository` / `SettingsStore`.
- `platform` – `MeterPlatform` + `NativeBridge`; the only place that knows the OS.
- `state` – `MeterController`; UI never talks to platform directly.
- `ui` – stateless pages reading the controller.

## Channel rules
- One channel: `app.tachyo/native`. Contract table: `specs/platform/channel.md`.
- Change Dart + Kotlin + C++ + spec together.
- Counters are cumulative and only differences are used; timestamps must be monotonic.

## Usage single-writer rule
Android: `MeterService` writes while running; otherwise the app via `addUsage`. Windows: the app. Breaking this double counts usage.

## UI
- Colors only from `AstryxTokens.of(context)`; spacing `space1..8`, radii `radiusInner/Element/Container/Page`.
- Numbers use `tabular` font features. Long values sit in `FittedBox`.
- Keep test keys (`download-tile`, `upload-tile`, `meter-switch`).

## Mirrors that must stay in step
- `lib/src/core/format.dart` ⇄ `android/.../SpeedFormat.kt`
- `dayKey` (Dart) ⇄ `UsageStore.dayKey` (Kotlin)
- `AppSettings` keys ⇄ `Prefs` keys

## License policy
MIT/Apache-2.0 only, user approval required, record in `THIRD_PARTY_LICENSES.md`. Prefer native code over plugins.

## Icons
Change `LogoPainter`, then `flutter test tool/render_icon_test.dart` and `tool/make_icons.ps1`.

## Done means
`harness/verify.ps1` passes, specs updated, `RESUME.md` checkpoint updated.
