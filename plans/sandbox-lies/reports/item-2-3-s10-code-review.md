# Review: Item 2.3 slice 10 — non-test edits of 0792e22

**Scope**: `docs/design.md` status flips, the `docs/references/detectors.md`
translation-map row, the `docs/changelog.md` timing entry, and the memory
retirement (`memory/ddaanet/sandbox-effects.md`, `memory/ddaanet/MEMORY.md`,
`memory/MEMORY.md`). Tests and implementation files are out of scope.
**Date**: 2026-09-24
**Mode**: review + fix

## Summary

The retirement removed exactly the paragraphs and section the item names. The
three index texts agree. The translation-map row and the changelog entry match
the item and the GREEN report's measurements.

Two status flips named pins that do not exist where the doc says they are:

- FR-3's malformed-payload case is in `tests/hook-malformed.bats`.
- FR-6's 2 KB cap is pinned in `tests/hook-cap.bats` with stubbed paragraphs,
  not by an all-verdicts fixture in `tests/hook.bats`.

The rest are minor accuracy and readability issues. All of them are fixed.
`docs/design.md` stays at 399 lines.

**Overall Assessment**: Ready

## Issues Found

### Critical Issues

None.

### Major Issues

1. **FR-3 pin names the wrong file for the malformed case**
   - Location: `docs/design.md` FR-3 (lines 65-66)
   - Problem: The `Partial` flip sat beside a pin reading "`tests/hook.bats`
     over recorded payloads of both events, plus a malformed-payload case". No
     malformed case is in `tests/hook.bats`. Both of them
     (`non-json, scalar, array and textless object` and
     `non-string tool_response.stdout and error fields stay quiet`) are in
     `tests/hook-malformed.bats`. The state layer requires that a pin be
     verified before it is written.
   - Suggestion: Name `tests/hook-malformed.bats`.
   - **Status**: FIXED

2. **FR-6 pin names the wrong file and a fixture that does not exist**
   - Location: `docs/design.md` FR-6 (lines 97-98)
   - Problem: The doc said "`tests/hook.bats` asserts the 2 KB cap on an
     all-verdicts fixture". The cap cases are in `tests/hook-cap.bats`, which
     was split from `hook.bats` in slice 7. They drive the cap with stubbed
     paragraphs of chosen byte sizes. No all-verdicts fixture exists, and none
     can exist while only the three phantom verdicts ship.
   - Suggestion: `tests/hook-cap.bats` asserts the 2 KB cap with stub
     paragraphs.
   - **Status**: FIXED

### Minor Issues

1. **NFR-4 `Done` rests on a pin that covers only its write clause**
   - Location: `docs/design.md` NFR-4 (line 173)
   - Note: The two cited tests run with `TMPDIR` naming a missing directory and
     use a `mktemp` spy. That pins "writes nothing" against the buffer
     regression. The second clause, "reads only the repository the call ran
     in", has no test. It holds trivially today, because the hook reads only
     stdin and its own `lib/`. It becomes substantive once probes stat paths
     taken from the error text (Items 2.4/4.1/4.3). The fix follows the
     pattern this same commit set on NFR-3: `Done (read scope: review, not
     gated)`. No line was added.
   - **Status**: FIXED

2. **FR-10 remainder overstated and incomplete**
   - Location: `docs/design.md` FR-10 (line 134)
   - Note: "phantom sections retired" was wrong in two ways:
     - The Phantom dotfiles section survives. Its zero-byte, porcelain-gate and
       `## Context` paragraphs remain.
     - The `/tmp reads full` section was retired too, and the text omitted it.

     The new text is "Partial (phantom and `/tmp` retired; rest: Items 4.1,
     4.2, 6.1, 7.1, 8.2)". The remainder list is unchanged.
   - **Status**: FIXED

3. **Header `Status:` line was stale**
   - Location: `docs/design.md` lines 3-5
   - Note: The line said "Planned. Nothing in this document is live; the five
     measured matchers exist as pilot code". That was false: the matchers were
     promoted in Item 1.1, and this item ships the hook with the three verdicts.
     The requirement lines beneath it now read Done/Partial. The new text is
     "Partial. The hook and the three `phantom-*` verdicts are built and tested,
     not yet dogfooded; probes and candidates are not built." It stays at three
     lines. The `Verified against:` stamp (`52e6dd8…`, 2026-09-22) is left
     alone. It already predated the Item 1.x flips, and re-stamping means
     re-verifying the whole doc, which is outside this review. The orchestrator
     may want to re-stamp at a phase boundary.
   - **Status**: FIXED

4. **The description/index clause read as an alternation inside the list**
   - Location: `memory/ddaanet/sandbox-effects.md` frontmatter `description`,
     `memory/ddaanet/MEMORY.md`, `memory/MEMORY.md`
   - Note: The clause was "phantom dotfiles as zero-byte files, or a porcelain
     cleanliness gate reading their `??` as DIRTY, sibling worktree …". The
     ", or" sits inside a comma-separated symptom list, and it narrowed the
     porcelain clause to zero-byte files. That clause applies to either mask
     shape. The text is now "phantom dotfiles (the zero-byte mask shape; a
     porcelain cleanliness gate reads their `??` as DIRTY)". This keeps the
     parenthetical form of the pre-retirement text. The routed symptoms are the
     same, and the index is net +7 bytes. After the edit, all three texts are
     still byte-identical (checked by script).
   - **Status**: FIXED

5. **The symptom-table row kept a retired symptom**
   - Location: `memory/ddaanet/sandbox-effects.md` symptom table, first
     Phantom row
   - Note: The row read "`.bashrc`/`.zshrc`/`.claude/skills` untracked or
     zero-byte; a porcelain gate reports DIRTY". A masked name listed as
     untracked is the `phantom-untracked` symptom, which this commit retired.
     The porcelain case is routed by the row's second clause. The row now reads
     "… as zero-byte read-only files; a porcelain gate reports DIRTY". That
     matches the surviving paragraphs and the description.
   - **Status**: FIXED

## Deferred Items

- **The `shared-claude.md` phantom bullet still says "`sandbox-effects` has the
  mechanism"**. The mask set, its scope and who sees the masks have now left
  that file, so every ddaanet repo's always-loaded bullet points at a file that
  no longer holds the mechanism. Reason: Item 8.2 repoints that reference to
  the skill (runbook Item 8.2; design FR-10). Until Items 7.1/8.2 land, the
  mechanism lives only in `docs/references/detectors.md` and the verdicts.

## Checks that came back clean

- **Every requirement Item 2.3 pins was flipped.**
  - FR-1, FR-3, FR-5, FR-6 and FR-10 went to Partial, each with a remainder the
    requirements mapping assigns (FR-1 → 8.1; FR-3 → 4.1; FR-5/FR-6 → 4.1, 4.2,
    6.1; FR-10 → 4.1, 4.2, 6.1, 7.1, 8.2).
  - NFR-3 and NFR-4 went to Done. The mapping gives both to Item 2.3 alone.
  - NFR-2 was already Done. `grep -L bsd-stubs tests/*.bats` is empty, so
    "every bats file loads it" holds.
- **FR-1 pin.** `gitadd failure payload yields one verdict` asserts the exact
  top-level and `hookSpecificOutput` key sets. **FR-5 pin.** `phantom verdicts
  ignore the flag` (absent/false/true) and `every quiet fixture is silent`
  (absent/true) are both in `tests/hook.bats`.
- **NFR-3 pin.** `hooks.json names both events` asserts timeout 10, and `every
  quiet fixture is silent` asserts empty stdout. The 100 ms figure is labelled
  as measured, not gated, which matches the runbook's "(not gated)".
- **NFR-4 pin wording.** `hook needs no temp dir` (`tests/hook.bats`) and
  `detect needs no temp dir` (`tests/matchers.bats`) both run with `TMPDIR`
  naming a nonexistent directory, as stated.
- **Translation-map row.** The text is exactly the item's text, with
  `; zero-byte shape → skill` appended to the masks row. The phantom entries'
  `Replaces` lines are consistent with it.
- **Changelog.**
  - The figures match the GREEN report's pass 2 (52 / 64 / 54 ms) and pass 1
    (61 / 61 / 52 ms, one 169 ms run).
  - It names both fixtures the item requires and the method (mean of 30,
    payloads built as `hook.bash` does).
  - It discloses that the runs were made inside the sandbox, although the hook
    itself runs outside it.
  - "Holds for the mean, not for every run" follows from the 169 ms outlier.
  - "Nothing gates these figures" matches the item.
  - No diagnostic is quoted.
- **Memory retirement.**
  - Removed: the masks paragraph (except its zero-byte sentence), who sees
    them, the `git add -A` paragraph, the visible-unsandboxed paragraph, and
    the whole `/tmp reads full` section, including its table row.
  - Kept byte-identical: the porcelain-gate and `## Context` paragraphs.
  - The zero-byte sentence was rewritten from "A second masking shape…" to
    "Besides the `/dev/null` character-device masks, …". "Second" pointed at
    removed text, so the rewrite was needed. The porcelain paragraph's "They"
    and "the set" still read correctly after it.
  - No surviving section refers to removed text. The one "(previous section)"
    in the excludedCommands section predates this change and points at Leaving
    the sandbox.
  - The frontmatter and both index lines dropped "char devices", "break
    `git add -A`", "one clean reading proves nothing" and the `/tmp`/du≪df
    clause, and kept every other symptom.

## Fixes Applied

- `docs/design.md` header `Status:` — Planned/pilot wording replaced with a
  Partial status for what is built, still 3 lines.
- `docs/design.md` FR-3 — pin now names `tests/hook.bats` for both events'
  recorded payloads and `tests/hook-malformed.bats` for malformed ones.
- `docs/design.md` FR-6 — pin now names `tests/hook-cap.bats` and stub
  paragraphs.
- `docs/design.md` FR-10 — remainder parenthetical reads "phantom and `/tmp`
  retired; rest: Items 4.1, 4.2, 6.1, 7.1, 8.2".
- `docs/design.md` NFR-4 — `Done (read scope: review, not gated)`.
- `docs/design.md` line count after `rumdl fmt`: 399 (unchanged). No
  UNFIXABLE-CAP item.
- `memory/ddaanet/sandbox-effects.md` — `description` phantom clause
  rewritten as a parenthetical, and the first Phantom symptom-table row drops
  the retired "untracked".
- `memory/ddaanet/MEMORY.md`, `memory/MEMORY.md` — the same phantom clause as
  the `description`. All three texts are verified identical.

Nothing is committed or staged. The orchestrator commits, and the memory edits
travel through the parent commit's gitlore gate.

## Requirements Validation

| Requirement | Status | Evidence |
|-------------|--------|----------|
| FR-1 | Partial (dogfood 8.1) | `hooks/hooks.json`; `tests/hook.bats` key-set case |
| FR-3 | Partial (probe call 4.1) | `tests/hook.bats`, `tests/hook-malformed.bats` |
| FR-5 | Partial (4.1, 4.2, 6.1) | `phantom verdicts ignore the flag` |
| FR-6 | Partial (4.1, 4.2, 6.1) | `tests/verdicts.bats`, `tests/hook-cap.bats` |
| FR-10 | Partial | memory diff; table, description, both index lines |
| NFR-2 | Done | every bats file loads `helpers/bsd-stubs`; `hook under BSD stubs` |
| NFR-3 | Done (bound not gated) | timeout and quiet cases; changelog timing |
| NFR-4 | Done (read scope by review) | the two `needs no temp dir` cases |

**Gaps:** none within Item 2.3's scope.

## Positive Observations

- The GREEN report records every status decision with its reason. That made
  each flip checkable against the mapping table.
- The retirement kept the zero-byte sentence's evidence date and shape. It
  rewrote only the one phrase that pointed at removed text.
- The changelog reports the outlier run and scopes the bound claim to the mean
  instead of rounding it away.

## Precommit

`just precommit` (foreground, sandboxed), final line:
`precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests`
(bats: 95 passed, 0 failed).
