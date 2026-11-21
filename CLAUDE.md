# Tachyo – Net Speed Meter

Start at ARCHITECTURE.md, then RESUME.md, then `harness/resume.ps1` and `specs/INDEX.md`.
Targets: Android and Windows. All features free. Third-party code: MIT or Apache-2.0 only (currently none).
Update the RESUME.md checkpoint before yielding or compaction.

## Harness: Tachyo app development

**Goal:** ship and evolve Tachyo spec-first, verified on the Android emulator and Windows.

**Invocation:** for any Tachyo feature, fix, test or release request use the `tachyo-orchestrator` skill. Simple questions may be answered directly from the specs.

**Change history:**
| Date | Change | Target | Reason |
| --- | --- | --- | --- |
| 2026-11-21 | Initial Harness v2 setup (4 agents, 4 skills) | all | new project |

<!-- spec-builder:start -->
## Specs first
1. Before reading any source for a task, open `specs/INDEX.md` and the matching spec's Entry Points and Data Flows (`harness/context.ps1 -Feature <ID>`).
2. Read source only for the methods those sections name, by line range.
3. When a source change affects a spec, update that spec's affected sections and append a History row in the same change.
<!-- spec-builder:end -->
