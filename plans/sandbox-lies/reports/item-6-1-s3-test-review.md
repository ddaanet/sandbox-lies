# Review: Item 6.1 slice 3 — test review, readonly and nopath

**Scope**: the uncommitted changes to `tests/hook-candidates.bats` and
`tests/verdicts.bats`, and the RED report `item-6-1-s3-red.md`. The SUT stub
(`verdict_readonly_path` in `lib/verdicts.sh`) was in scope for stub
completion only; it needed none.
**Date**: 2026-09-26
**Mode**: review + fix (TDD test review)

No UNFIXABLE items.

## Summary

The hook cases pin the runbook's strings and the human lines exactly. The
nopath stub prints no `path=` line, as the probe contract requires. The
missing-path readonly form is already pinned (`The path` subject), so no case
had to be added for it. Three issues were found and fixed:

- The transcription case bundled readonly and nopath, so nopath's assertions
  were never seen to fail in RED.
- The writable tail was pasted twice instead of shared.
- The readonly hook case fed `path=/r/y` but did not check that the path
  reached the context.

After the fixes, every new assertion fails on an assertion and none errors. A
temporary correct implementation turned all 18 cases green. Six mutations each
turned the expected cases red. The temporary code was then removed, and
`lib/` matches HEAD.

**Overall Assessment**: Ready

## Issues Found

### Critical Issues

None.

### Major Issues

1. **nopath's transcription was never seen to fail**
   - Location: `tests/verdicts.bats`, `readonly-path readonly and nopath
     verdict text matches detectors.md`
   - Problem: the case pinned both outcomes in sequence. In RED it stopped at
     the first readonly assertion (line 188), so nopath's line 1 and line 2
     assertions never ran against the stub. Each outcome has its own text and
     its own human line, which is the same reasoning the RED report gives for
     splitting the hook cases.
   - Fix: split into `readonly-path readonly verdict text matches
     detectors.md` and `readonly-path nopath verdict text matches
     detectors.md`. In RED each one now fails on its own line 1 equality.
   - **Status**: FIXED

### Minor Issues

1. **The writable tail was pasted twice instead of shared**
   - Location: `tests/verdicts.bats`, the writable case's `rest` and the new
     case's `re_run_on`
   - Note: detectors.md defines nopath as "its opening sentence, then the
     `writable` paragraph from `Re-run` on". The case did compose it that
     way, but from a second verbatim copy of the tail. That copy was
     independent of the one in the writable case. If detectors.md later
     changed the writable text, updating only the writable case would leave
     the nopath case still asserting the old tail.

     The approach otherwise matches the file's convention. The text is
     transcribed from detectors.md, not derived from it at run time and not
     copied from `lib/verdicts.sh`. `phantom_untracked` is composed the same
     way, as `chardev_para` plus an addition.
   - Fix: added one file-level helper, `readonly_path_rerun_tail`, after
     `all_verdict_text` (where the file keeps its helpers). The writable case
     now builds `rest` as its own opening sentence plus the helper, and the
     nopath case builds its expected line as nopath's opening sentence plus
     the helper. The writable case pins the same bytes as before and still
     passes.
   - **Status**: FIXED

2. **The readonly hook case's path line was decorative**
   - Location: `tests/hook-candidates.bats`, `readonly outcome through the
     hook`
   - Note: the stub fed `path=/r/y`, but nothing checked that the path
     reached the context. The writable twin checks `/r/x`. The fixture's own
     path is `/tmp/checkpoint.py.orig`, so `/r/y` can only come from the
     probe's line.
   - Fix: added `grep -qF '/r/y'` ahead of the `not a sandbox effect` check.
     Mutation M1 below shows it catches a readonly verdict that ignores the
     path.
   - **Status**: FIXED

## Checks

- **Runbook strings.** The readonly case asserts `not a sandbox effect`. The
  nopath case asserts `write allowlist` and `compare modified files against
  the target`. The `systemMessage` equalities are `read-only — real` and
  `read-only — sandbox allowlist`. Each equality also pins that
  readonly-path is the only verdict contributing. No payload sets the flag,
  so slice 4's policy cannot interfere.
- **Wrong-reason hunt on nopath.** `write allowlist` does not occur in the
  writable text, which says "whose allowlist refused". So a GREEN that
  routed nopath to the writable branch fails the first context check
  (mutation M5). `compare modified files…` is shared with writable. On its
  own it would not tell the two apart, but it is paired with the distinct
  `write allowlist` check and the exact human line.
- **nopath stub.** `stub_probe_kv readonly_path nopath` with no extra line
  prints only `nopath`, which matches the probe contract.
- **Missing path for readonly.** `readonly-path readonly verdict text
  matches detectors.md` asserts that empty stdin gives `The path is not
  writable outside the sandbox either; this is not a sandbox effect.`. That
  is the settlement slice 2's code review reached for writable. Mutation M2
  (no fallback, so the sentence has no subject) reds it. `verdicts under 400
  chars` does not catch that mutant, so the transcription case is the only
  guard, and it holds. The case comment now states this reasoning.
- **Row table.** The rows `readonly_path readonly` and `readonly_path nopath`
  are present. `verdicts under 400 chars` reds on the exactly-two-lines
  assertion for the readonly row.
- **Self-quiet.** `bash lib/matchers.sh < tests/verdicts.bats` and
  `bash lib/matchers.sh < tests/hook-candidates.bats` each exit 1 with empty
  output.
- **Line counts.** `tests/verdicts.bats` has 315 lines and
  `tests/hook-candidates.bats` has 158. Both are under 400.
- **Lint.** `shellcheck` on both files reports nothing (exit 0).

## Per-test result (after fixes, unchanged stub, foreground)

`direnv exec . scripts/run-bats.sh tests/verdicts.bats
tests/hook-candidates.bats` gives 13 passed and 5 failed. Every failure is an
assertion:

- `verdicts under 400 chars` fails at line 90, on the exactly-two-lines
  assertion for the `readonly_path readonly` row.
- `readonly-path readonly verdict text matches detectors.md` fails at line
  194, on the backticked-path line 1 equality.
- `readonly-path nopath verdict text matches detectors.md` fails at line 209,
  on the line 1 equality.
- `readonly outcome through the hook` fails at line 120, on
  `grep -qF '/r/y'`. The probe is reached (`[ -f "$PROBE_CALLED" ]` passes),
  the verdict prints nothing, and the context is empty.
- `nopath outcome through the hook` fails at line 137, on
  `grep -qF 'write allowlist'`, by the same mechanism.

No case errors. `verdict text is quiet` and `no removal instruction` pass,
and passing is correct for them in RED: a row with no text cannot trip
either check. `verdicts under 400 chars` requires every row to produce two
non-empty lines, so their pass cannot be vacuous.

## Feasibility and mutation

Temporary `readonly` and `nopath` arms were added to `verdict_readonly_path`,
each line tagged `TEMP-REVIEW`, with text transcribed from detectors.md. With
them, the two files gave 18 passed and 0 failed. That includes `verdict text
is quiet` and `no removal instruction`, so the nopath text is quiet and has
no removal word.

Each mutation was applied by exact-string replace, run, and reverted by the
inverse replace. After each revert, `grep -c MUT` returned 0.

| mutant | cases that turned red |
|---|---|
| M1 readonly ignores `path=` | readonly transcription (line 1); readonly hook (`/r/y`) |
| M2 readonly with no `The path` fallback | readonly transcription (empty-stdin line) |
| M3 nopath drops the `update-config` sentence | nopath transcription |
| M4 nopath human line set to writable's | nopath transcription (line 2); nopath hook (`sys`) |
| M5 nopath opens with the writable sentence | nopath transcription; nopath hook (`write allowlist`) |
| M6 readonly human line set to nopath's | readonly transcription (line 2); readonly hook (`sys`) |

M3 stays green in the hook case by design, because that case checks
substrings. The transcription case is the guard for it.

Afterwards the nine `TEMP-REVIEW` lines were deleted. `grep -c TEMP-REVIEW
lib/verdicts.sh` returns 0, and `git diff --stat -- lib/` is empty.

## Fixes Applied

- `tests/verdicts.bats`: added the `readonly_path_rerun_tail` helper after
  `all_verdict_text`.
- `tests/verdicts.bats`: the writable case's `rest` is now composed from the
  helper; the bytes it pins are unchanged.
- `tests/verdicts.bats`: split the combined case into a readonly case and a
  nopath case. The nopath expected line is composed from the helper.
- `tests/hook-candidates.bats`: `readonly outcome through the hook` now also
  asserts `/r/y` in the context.

Nothing was committed.

## Requirements Validation

| Requirement | Status | Evidence |
|---|---|---|
| FR-4 (probe outcome and key=value lines reach the verdict) | Satisfied (test) | readonly hook case asserts the probe ran and `/r/y` reached the context; nopath hook case takes the no-path outcome through the hook |
| FR-5 (flag policy) | Out of slice | slice 4 |
| FR-6 (text from detectors.md, under 400 characters, quiet) | Satisfied (test) | the two transcription cases, the row table's length case, the quiet and no-removal cases (green under the temporary implementation) |

## Positive Observations

- The nopath stub passes no extra line, which honours the probe contract
  instead of reusing `stub_probe`'s `path=stub`.
- The readonly transcription reuses the tricky path `/r/a b&c\1/x` and also
  pins the empty-stdin form, the same as the writable case.
- The RED report checked the hook's empty-output mechanism by hand before
  classifying the failures as assertions.

## Recommendations

None in scope.
