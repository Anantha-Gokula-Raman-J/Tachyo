---
name: tachyo-orchestrator
description: Runs feature work, bug fixes and releases for Tachyo (Net Speed Meter, Flutter, Android + Windows) through the spec-first agent team - flutter-engineer, platform-engineer, qa-tester, spec-keeper. Use for any Tachyo change request, including re-runs, updates, "fix", "improve", "only redo the Android part", "test again on the emulator", or "continue from the previous result". Not for pure questions about the code (answer from specs directly).
---

# Tachyo orchestrator

**Execution mode:** subagent delegation (each step returns one report; no agent-to-agent chat needed),
run as a fixed pipeline: spec → implement → QA → spec sync. Data passes through `_workspace/` files.

## 0. Context check
- `_workspace/` missing → fresh run.
- `_workspace/` present and the user asks to fix part of it → re-run only that step/agent, passing the previous report.
- New, unrelated request → move `_workspace/` to `_workspace_<yyyymmdd-hhmm>/`, start fresh.
- Always run `harness/resume.ps1` and read `RESUME.md` first.

## 1. Scope (main agent)
1. Map the request to feature IDs in `specs/INDEX.md` (`harness/context.ps1 -Feature <ID>`).
2. Write `_workspace/00_orchestrator_plan.md`: goal, feature IDs, specs to change, acceptance checks (taken from spec Edge Cases).
3. If a channel method changes, the plan names it explicitly.

## 2. Implement
- Dart-only work → `Agent(subagent_type: "flutter-engineer")`.
- Native/channel work → `Agent(subagent_type: "platform-engineer")`.
- Both → run platform-engineer first when the channel contract changes, then flutter-engineer; otherwise both in parallel in one message.
- Each writes `_workspace/02_<agent>_report.md`.

## 3. QA
`Agent(subagent_type: "qa-tester")` with the acceptance checks. It runs `harness/verify.ps1 -Build`, `harness/android_test.ps1` (`-Wipe` when asked or when state is suspect, `-Reboot` for boot features) and `tool/win_drive.ps1` for Windows UI. On `QA FAIL`, send the report back to the implementing agent once; a second failure is reported to the user with evidence.

## 4. Spec sync
`Agent(subagent_type: "spec-keeper")`: update affected specs + History, `ARCHITECTURE.md` if structure changed, and the `RESUME.md` checkpoint.

## Error handling
- Retry a failed agent once with its error; then continue without it and list the gap in the final report.
- Do not retry permission denials or usage-limit failures; report them with the reset time if known.
- Never fill an agent's missing judgment with guesses; only record facts you verified.

## Rules that always apply
- Third-party code: MIT or Apache-2.0 only, and only with user approval.
- All features free; no ads, accounts or network permission.
- Specs ≤ 600 lines, six sections, updated in the same change as code.

## Test scenarios
- **Normal:** "Show upload and download separately in the Android status-bar icon" → NSM-ANDROID; platform-engineer edits `MeterService.speedIcon` + spec; qa-tester runs android_test.ps1 and inspects statusbar.png; spec-keeper appends History.
- **Error:** emulator fails to boot during QA → qa-tester retries with `-Wipe`; if it still fails, orchestrator reports "Android not verified (emulator)" while Windows results stand.
