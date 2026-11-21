---
name: tachyo-specs
description: Rules for creating and updating Tachyo's module specs (specs/INDEX.md, specs/<module>/common/README.md, submodule specs) - six-section template, file:line tracing with grep and ranged reads, History rows, 600-line limit. Use after any code change in the Net Speed Meter project or when asked to regenerate/refresh specs.
---

# Tachyo spec rules

Specs let agents learn the data flow without reading source. They only work if they stay true.

## Update procedure
1. Read `specs/INDEX.md` and the History of each affected spec.
2. Find changed methods with grep (`grep -n "methodName" path`), read only their line ranges.
3. Update sections 2–5 of each affected spec; refresh moved file:line references.
4. Append one History row: `| date | commit or no-vcs | change | affected methods |`.
5. New module/submodule → add it to `specs/INDEX.md` (module table, task lookup, feature IDs) and `harness/context.ps1`.

## Template (all six sections, in order; write "None found" if empty)
1. Overview 2. APIs and Use Cases 3. Data Flows (`A -> B -> C`, exact names) 4. Entry Points 5. Edge Cases (`condition -> behavior (file:line)`) 6. History (append-only)

## Checks before finishing
- Every Data Flows name appears in Entry Points or as a traced callee with file:line.
- `harness/verify.ps1` passes (includes the ≤ 600-line check).
- Unresolved calls are marked `external`/`unresolved`, never invented.
- `RESUME.md` checkpoint updated.
