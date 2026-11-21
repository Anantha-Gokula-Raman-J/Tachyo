# Tachyo workspace (agents)

Start at ARCHITECTURE.md (layers, module catalog, channel API catalog), then RESUME.md,
then `harness/resume.ps1` and `specs/INDEX.md`. For any task: architecture → relevant
module specs (`harness/context.ps1 -Feature <ID>`) → only then source.

- Specs are the source of intent: six sections (Overview, APIs and Use Cases, Data Flows,
  Entry Points, Edge Cases, History), ≤ 600 lines, updated in the same change as code.
- Keep shared contracts identical: channel (`specs/platform/channel.md`), format mirror
  (format.dart ⇄ SpeedFormat.kt), `dayKey`, settings keys.
- All features free; no ads, accounts, telemetry or location permission. INTERNET is used only by the speed test.
- Third-party code: MIT or Apache-2.0 only, with approval; record in THIRD_PARTY_LICENSES.md.
- Targets: Android and Windows.
- Agents: `.claude/agents/` (flutter-engineer, platform-engineer, qa-tester, spec-keeper);
  skills: `.claude/skills/` (tachyo-orchestrator, tachyo-dev, tachyo-qa, tachyo-specs).
- Quality gate: `harness/verify.ps1 [-Build]`; device checks: `harness/android_test.ps1`, `tool/win_drive.ps1`.
- Update the RESUME.md checkpoint before yielding or compaction.

<!-- spec-builder:start -->
## Specs first
1. Before reading any source for a task, open `specs/INDEX.md` and the matching spec's Entry Points and Data Flows.
2. Read source only for the methods those sections name, by line range.
3. When a source change affects a spec, update that spec's affected sections and append a History row in the same change.
<!-- spec-builder:end -->
