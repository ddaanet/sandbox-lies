# Review: Item 1.1 Slice A — test review (after RED)

**Scope**: the uncommitted Slice A test changes. They are
`tests/probes-resume.bats` (new), `tests/hook-candidates.bats`,
`tests/verdicts.bats` and `tests/helpers/verdicts.bash`, plus the RED report
`reports/item-1-1-sA-red.md`. The inert stub `probe_resume_lost` in
`lib/probes.sh` was in scope for stub completion only. Implementation was out of
scope.

**Date**: 2026-10-07

**Mode**: review + fix (dispatch `item-1-1-sA-test-review`). Nothing committed.

## Summary

The RED batch holds up: every new test fails on an assertion, none errors, and
the two mutation-proven hook cases reproduce under different mutations. The
probe fixtures had gaps. Five plausible but forbidden probes passed the whole
probe suite:

- a probe testing only the last refusal's id;
- one taking every UUID in the text;
- one also searching `HOME/.claude` when `CLAUDE_CONFIG_DIR` is set;
- one searching a single project directory;
- one counting `.jsonl` files (caught only by the directory case, which is named
  for something else).

The hook-level BSD case was also blind to a BSD-only GNU-ism whose stderr is
silenced and whose default is `lost`. The Slice A additions also put
`tests/hook-candidates.bats` past the 400-line gate.

All of these are fixed in the tests. Each new or rebuilt case reds on its
assertion against the stub. A temporary reference probe showed that each
forbidden variant is caught by the test named for it.

**Overall Assessment**: Ready

## Mechanical check (against the inert stub)

Each suite was run once, in the foreground, one at a time, after the fixes.

- `tests/probes-resume.bats`: 0 passed, 10 failed. Every case fails on
  `[ "$output" = found|lost ]`, and none errors.
- `tests/hook-resume.bats` (new, moved from `hook-candidates`): 2 passed, 1
  failed. The failure is "transcripts for both ids, no verdict", on
  `assert_lacks "$output" 'never written'`. The two passes are the cases the RED
  report proves by mutation.
- `tests/hook-candidates.bats`: 13 passed, 0 failed. Three cases moved out.
- `tests/verdicts.bats`: 8 passed, 1 failed. The failure is the new `-` case, on
  `[ -z "$output" ]` (line 107).

Before the fixes, the counts matched the RED report: probes-resume 0/6,
hook-candidates 15/1, verdicts 8/1.

## Mutation proof

Each mutation was an exact replacement of a string occurring once, with its
landing confirmed by `command grep -c`. Each was restored by the swapped
replacement, with `command grep -c` returning 0 afterwards. Afterwards,
`lib/probes.sh` hashes to `47292e1`, its RED-state blob, and
`git diff HEAD -- lib/verdicts.sh hooks/` is empty.

- **A. "no transcript, today's verdict"** (`lib/verdicts.sh`).
  - Mutation: `'--resume — transcript not persisted in sandbox'` became
    `'--resume — transcript MUTANT-A in sandbox'`. It differs from the RED
    report's, which changed the paragraph.
  - Result: red on
    `[ "$sys" = '--resume — transcript not persisted in sandbox' ]`. The RED
    mutation died on the `ctx` line above it, so this `systemMessage` assertion
    had never been red.
  - Restored: 0 hits, green. Run in `hook-candidates.bats` and again after the
    move to `hook-resume.bats` (line 65).
- **B. "no-transcript verdict survives BSD grep, sed, mktemp, stat and wc"**
  (`lib/probes.sh`).
  - Mutation: the stub became
    `probe_resume_lost() { cat >/dev/null; printf 'a\\n' | grep -qE '\\bMUTANTB|a'; }`.
    The BSD grep stub rejects the `\b` in that pattern, while the real grep
    matches. That is a different tool and stub rule from the RED report's
    `sed --version`.
  - Result: the plain run passed, then red on `[ "$output" = "$plain" ]` (line
    84 after the move).
  - Restored: 0 hits, green. Run in both files.
- **C. "both ids have a transcript, found", `[ -z "$stderr" ]`.**
  - Mutation: the stub became
    `probe_resume_lost() { cat >/dev/null; echo found; echo MUTANT-C >&2; }`.
  - Result: red on `[ -z "$stderr" ]` (line 46). That assertion sits below the
    first red, so it had never been red.
  - Restored: 0 hits, back to red on `[ "$output" = found ]`.
- **D. "one id without a transcript is lost", `[ -z "$stderr" ]`.**
  - Mutation: the stub became
    `probe_resume_lost() { cat >/dev/null; echo lost; echo MUTANT-D >&2; }`.
  - Result: red on `[ -z "$stderr" ]` (line 56).
  - Restored: 0 hits, back to red on `[ "$output" = lost ]`.

## Forbidden-implementation run

The stub was temporarily replaced by a reference probe that took a `REVIEW_RV`
variant switch. It was restored by inverse replacement and the hash checked as
above. The probe suite ran once per variant:

| Variant | Wrong behaviour | Red (after fixes) |
| --- | --- | --- |
| `ref` | none: D-a as specified | none, 10/10 green |
| `last` | tests only the last refusal's id | "the first id without a transcript is lost" only |
| `all` | takes every UUID in the text | "an id outside a refusal line is not taken" only |
| `union` | also searches `HOME/.claude` | "CLAUDE_CONFIG_DIR set, HOME/.claude is not read" only |
| `onedir` | searches the first project dir only | "both ids have a transcript, found" only |
| `sameproj` | requires every id in one project dir | "both ids have a transcript, found" only |
| `exists` | `-e` for `-f` | "a directory named <id>.jsonl" only |
| `recursive` | also searches `projects/*/*/` | "a transcript under archived/" only |
| `count` | found when the `.jsonl` count reaches the id count | "unrelated id" (named), and "directory" |
| `bsdgrep`/`bsdquiet` | `grep -oE '\b…'` id extraction, `lost` when no ids | probe-level BSD case red; hook-level BSD case red only when grep's stderr is not silenced |

Before the fixes, the fixtures let `last`, `all`, `union`, `onedir`, `sameproj`
and `bsdquiet` pass every test. `count` was red only in the directory case,
which is named for something else.

Under `ref`, `hook-candidates` was 15/1 before the move. The one red was case 1,
because `lib/verdicts.sh` does not yet read its outcome. That is expected: the
outcome-aware verdict is the GREEN step.

## Issues Found

### Critical Issues

None.

### Major Issues

1. **The partial-`lost` case pinned only one orientation**
   - Location: `tests/probes-resume.bats`, "one id without a transcript is
     lost".
   - Problem: `$ID_1` was present and `$ID_2` missing in that case and in the
     directory and archived cases. A probe testing only the last refusal's id,
     which a `while read` loop overwriting `id` produces, passed every test.
   - Fix: added "the first id without a transcript is lost", with only `$ID_2`
     present.
   - **Status**: FIXED
2. **Nothing pinned "ids from a refusal line"**
   - Location: `tests/probes-resume.bats`.
   - Problem: the fixture's `sid=`/`sid2=` lines carry the same ids as its
     refusal lines. A probe taking every UUID in the text was therefore
     indistinguishable from the D-a contract.
   - Fix: added "an id outside a refusal line is not taken". It uses the cut
     fixture with `$ID_2`'s refusal line filtered out at run time
     (`grep -vF -- "ID: $ID_2"`), so `sid2=$ID_2` stays as the decoy. Two guards
     assert that the decoy is present and the refusal absent. Only `$ID_1` has a
     transcript, and the case expects `found`.
   - **Status**: FIXED
3. **The root isolation fixture had nothing to leak**
   - Location: `tests/probes-resume.bats`.
   - Problem: the fallback case proves `HOME/.claude` is read when
     `CLAUDE_CONFIG_DIR` is unset. Yet every case with `CLAUDE_CONFIG_DIR` set
     had an empty `HOME/.claude`, so a probe searching both roots passed. E5
     makes that probe wrong: CC refuses when `CLAUDE_CONFIG_DIR` points away
     from the transcript.
   - Fix: added "CLAUDE_CONFIG_DIR set, HOME/.claude is not read". `$ID_1` is in
     the config dir, `$ID_2` only under `$HOME/.claude/projects/-p/`, and the
     case expects `lost`.
   - **Status**: FIXED
4. **The `projects/*` glob was exercised over one directory only**
   - Location: `tests/probes-resume.bats`, "both ids have a transcript, found".
   - Problem: every transcript sat in `projects/-p`. A probe searching one
     project directory, or requiring both ids in the same one, passed. E3 says
     `--resume` finds a session in any project.
   - Fix: the found case now puts `$ID_2` in `projects/-q`.
   - **Status**: FIXED
5. **The hook-level BSD case could not see a silenced GNU-ism**
   - Location: the BSD case, now `tests/hook-resume.bats`.
   - Problem: the case runs with an empty config dir, where the right answer is
     `lost`. A probe whose id extraction breaks under BSD and falls back to
     `lost` gives the same stdout. The case caught such a probe only through the
     stub's error text merged into `$output`, and was green once that stderr was
     silenced (`bsdquiet`). The name ("verdict survives") is honest, but the
     case does not show that the probe survives.
   - Fix: added "found survives BSD grep, sed, mktemp, stat and wc" in
     `tests/probes-resume.bats`. Both transcripts are present, the stubs are on
     `PATH`, and the case expects `found`. It catches `bsdquiet`, and it gives
     the new file its own BSD case.
   - **Status**: FIXED
6. **`tests/hook-candidates.bats` went past the 400-line gate**
   - Location: `tests/hook-candidates.bats`, 375 lines at HEAD and 445 after
     RED. `scripts/check-line-limits.sh` exits 1, so the GREEN commit's
     `just precommit` would fail, and Slice B adds more hook cases.
   - Fix: the three new resume-lost hook cases moved verbatim, with `resume_cfg`
     and the two id constants, into a new `tests/hook-resume.bats`. The new file
     loads `helpers/bsd-stubs` and `helpers/hook`, has the same
     `setup`/`run_hook` as its siblings and carries the BSD case.
     `hook-candidates.bats` is now 378 lines and keeps the existing "resume-lost
     flag policy" case.
     - The file-level `shellcheck disable=SC2030,SC2031` is no longer needed and
       was dropped. Shellcheck is clean on all three files.
     - This departs from the outline's "hook cases in
       `tests/hook-candidates.bats`". The new file falls within Item 5.1's
       `tests/hook-*.bats` family glob.
   - **Status**: FIXED

### Minor Issues

1. **The `[ -z "$stderr" ]` assertions had never been red**
   - Location: `tests/probes-resume.bats`, the found and partial cases.
   - Note: both sit below the first red, so neither had been shown to
     discriminate.
   - **Status**: FIXED (mutations C and D above)
2. **`systemMessage` assertion never red**
   - Location: hook "no transcript, today's verdict".
   - Note: the RED mutation stopped at the `ctx` line.
   - **Status**: FIXED (mutation A above)
3. **Zero-byte transcripts are unreachable from the write path**
   - Location: the `transcript` helper and `resume_cfg`.
   - Note: CC never writes an empty `.jsonl`. With zero-byte fixtures, a probe
     testing `-s` rather than `-f` would red for a state that cannot occur.
   - Fix: both helpers now write one JSON line. `transcript` takes an optional
     root and project, which replaces the hand-rolled paths in the archived and
     fallback cases.
   - **Status**: FIXED
4. **The unrelated-id case was satisfied by a count**
   - Location: "a transcript for an unrelated id does not count".
   - Note: with only `$ID_OTHER` present (one file for two ids), a probe
     comparing the `.jsonl` count with the id count printed `lost`.
   - Fix: the fixture is now `$ID_1` plus `$ID_OTHER`, so the count matches and
     only an id-exact test prints `lost`.
   - **Status**: FIXED

## Wrong-reason hunt, per test

For each test: what fails it, then what else could produce its observable.

- **Probe "both ids … found"**
  - Fails it: either id missing, or a probe confined to one project directory or
    one root.
  - Else: a constant `found`, killed by the `lost` cases.
- **"one id without a transcript"** and **"the first id without a transcript"**
  - Fails them: a probe that checks only the first id, or only the last.
  - Else: a constant `lost`, killed by the found case.
- **"unrelated id"**
  - Fails it: any-file or count logic.
  - Else: none left, since `$ID_1` is present and the counts match.
- **"id outside a refusal line"**
  - Fails it: a probe that takes ids outside the refusal shape.
  - Else: a probe that drops the second refusal. That is the last-versus-first
    pair's job.
- **"directory" and "archived"**
  - Fail them: `-e`, and a recursive search, respectively.
  - Else: both have `$ID_1` as a real transcript, so `lost` comes only from
    `$ID_2`'s named defect.
- **"fallback"**
  - Fails it: a probe that ignores `HOME/.claude`.
  - Else: a probe printing `found` whenever `CLAUDE_CONFIG_DIR` is unset. That
    residual is not pinned; the variant is not plausible enough to cost a case.
- **"CLAUDE_CONFIG_DIR set, HOME/.claude is not read"**
  - Fails it: the union probe.
- **Probe BSD**
  - Fails it: a GNU-ism in id extraction, with any default.
- **Hook "both ids, no verdict"**
  - This is a bare negative, paired with "no transcript, today's verdict". The
    pair runs the same payload through `hooks/annotate.sh`, with the real probe
    from `hook_copy_tree` and an isolated `CLAUDE_CONFIG_DIR`. The two differ
    only in the transcripts.
  - Fails it: a verdict that ignores its outcome, or a probe that reads the host
    root (the fixture's ids have no transcript there).
  - Else: a probe erroring only when transcripts exist would also read silent.
    The probe-level found case covers that.
- **Verdict `-` case**
  - A bare negative, paired with `verdicts.bats:90-94` (`lost` prints the text).

## Host isolation

- `tests/probes-resume.bats` exports `CLAUDE_CONFIG_DIR` and `HOME` under
  `$BATS_TEST_TMPDIR` in `setup`.
- `tests/hook-resume.bats` cases export `CLAUDE_CONFIG_DIR` through
  `resume_cfg`.
- The existing "resume-lost flag policy" case exports it at `cfg-empty`.
- Search: across `tests/*.bats`, `tests/helpers/`, `tests/*.py`, `justfile` and
  `scripts/`, no other suite feeds a refusal to the hook.
  - `hook.bats` loops over `quiet-*` and `fire-masks-*` only.
  - `hook-locks.bats` loops over `fire-lock-*` and `fire-configlock-*`.
  - `matchers*.bats` and `corpus-eval.py` call matchers, never probes.
- No case reads the host `~/.claude`.

## Live-diagnostic check

`lib/matchers.sh` was run over every changed or new file, including this report.
None fires. The refusal text in the new case is filtered at run time, by a
pattern starting at its `ID:` fragment.

## Fixes Applied

- `tests/probes-resume.bats`:
  - `transcript` takes `[root] [project]` and writes one JSON line;
  - the found case spans `-p` and `-q`;
  - the unrelated-id case is `$ID_1` plus `$ID_OTHER`;
  - the archived and fallback cases use `transcript`;
  - new cases: first id missing, id outside a refusal line, HOME not read when
    the config dir is set, and the BSD found case.
- `tests/hook-resume.bats` (new): holds the three resume-lost hook cases,
  `resume_cfg` (now writing one JSON line) and the id constants, moved from
  `tests/hook-candidates.bats`.
- `tests/hook-candidates.bats`: the moved block is removed and the SC2030/SC2031
  file-level disable is dropped. 378 lines.
- `lib/probes.sh`: unchanged from RED (blob `47292e1`).

## Requirements Validation

| Requirement | Status | Evidence |
| --- | --- | --- |
| D-a probe contract | Pinned | ten probe cases; each forbidden variant red in its named case |
| D-b `lost` text, nothing otherwise | Pinned (Slice A part) | `verdicts.bats` `-` case and rows; hook no-transcript case |
| Isolation (no host `~/.claude`) | Satisfied | see Host isolation |
| Outline slices 1, 2, 3, 4, 6 | Covered | `hook-resume.bats`, `probes-resume.bats` |
| FR-4 BSD re-run | Covered | hook-level and probe-level BSD cases |

## Positive Observations

- Every hook case drives `hooks/annotate.sh` through the copied tree with the
  real probe, not `stub_probe`.
- The RED report names a forbidden variant for each probe case.
- The `-` verdict case explains why it passes a literal `-` instead of using
  `verdict_text`'s mapping.

## Recommendations

- GREEN: the reference run shows a probe built from a `sed -nE` extraction plus
  a `[ -f ]` glob loop turns all ten probe cases green. Hook case 1 also needs
  `verdict_resume_lost` to print nothing for any outcome but `lost`.
- Slice B: put the `found` hook case in `tests/hook-resume.bats`.
  `hook-candidates.bats` has 22 lines of headroom.
