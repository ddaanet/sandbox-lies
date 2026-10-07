# Review: Item 1.1 Slice B — code review (after GREEN)

**Scope**: the implementation in the slice commit
`Item 1.1/B — found verdict, no flag policy for resume-lost`:
`hooks/annotate.sh` (the flag-policy `case` and its comment) and
`lib/verdicts.sh` (`verdict_resume_lost`). The tests are out of scope and were
not edited.

**Date**: 2026-10-07

**Mode**: review + fix (dispatch `item-1-1-sB-code-review`). Mutation testing
followed `delegate-status.md` §Mutation testing. Nothing committed.

## Summary

The gate removal is correct. `tmpdir-unset:false`, `seccomp-init:true` and
`readonly-path:true` survive intact, and each is still pinned by its own case.
The rewritten comment is accurate.

`verdict_resume_lost` was correct, but its `found` branch ended in a dead
`return 0`. Removing it is an equivalent mutant, because the `lost` guard after
it already returns for `found`. The function also had a shellcheck directive
sitting above the `if`. It is now a `case` on the outcome, the shape
`verdict_readonly_path` uses. `unknown`, `-` and the empty outcome still print
nothing, and both are proven by mutation.

All nine mutations were run. Eight went red. M0 survived because it cannot be
killed, and the refactor removed the code it mutated.

**Overall Assessment**: Ready

## Issues Found

### Critical Issues

None.

### Major Issues

None.

### Minor Issues

1. **Dead `return 0` in the `found` branch, and a branch order no test can
   distinguish**
   - Location: `lib/verdicts.sh`, `verdict_resume_lost`.
   - Problem: on `found` the branch printed both lines and returned. Without the
     `return 0`, control reached `[ "${1-}" = lost ] || return 0`, which also
     returns 0 with nothing printed. Mutation M0 deleted it, and every test
     stayed green. No test can kill that mutant, so the line was dead code. The
     `# shellcheck disable=SC2016` above the `if` covered the whole compound, so
     it read as if it applied to the condition.
   - Fix: one `case "${1-}" in lost) … ;; found) … ;; esac`. Each shellcheck
     directive now sits on its own `printf`. An outcome with no arm prints
     nothing, which is the same contract `verdict_readonly_path` states. The
     texts are byte-for-byte unchanged, and the `lost` arm comes first as it did
     before Slice B.
   - **Status**: FIXED. No behaviour changes, so no new test was needed. Both
     files stayed green (`verdicts.bats` 10/10, `hook-resume.bats` 10/10), and
     M1 and M2 below re-prove the "prints nothing" contract on the new shape.

2. **The candidates' block comment said every candidate takes no outcome**
   - Location: `lib/verdicts.sh`, the comment above `verdict_tmpdir_unset`.
   - Problem: "Each takes no outcome, as the phantom verdicts do" has been false
     for `resume_lost` since Slice A. Slice B makes it a two-outcome verdict.
   - Fix: the comment names the exception. The probe's `lost` or `found` picks
     the text, and any other outcome prints nothing.
   - **Status**: FIXED.

## Checks requested

- **Gate removal.** The `case` reads
  `tmpdir-unset:false | seccomp-init:true | readonly-path:true) continue ;;`.
  The other three policies are unchanged, and M4–M6 show each still pinned.
- **Comment accuracy (`hooks/annotate.sh`).** "tmpdir-unset fires only when the
  flag is true; seccomp-init and readonly-path are silent when it is.
  resume-lost has no policy: both its verdicts apply either way." This matches
  the code and outline Q1. "Both its verdicts" is exact: `unknown` has no
  verdict and is silent under either flag.
- **Branch order.** `lost` and `found` are disjoint literals, so order cannot
  change output. The exact-text tests pin each text to its outcome (RED test 1,
  hook "exists" cases, and the existing `lost` transcription).
- **Shellcheck placement.** Each `SC2016` directive now sits directly above the
  `printf` whose single-quoted backticks trigger it.
  `shellcheck lib/verdicts.sh` is clean.
- **`unknown` prints nothing.** It does. M2 (`unknown` given the `lost` text)
  reds the hook's "no config root to search, silent" case.
- **`found` text against `resume-probe-evidence.md`** (not reworded):
  - "the sandbox did not lose it": E2 and E3s. A sandboxed `--resume` of an
    existing transcript succeeds.
  - "an unsandboxed retry will not help": E5. An unsandboxed call reading
    another config dir refuses the same way.
  - "`--resume` finds a session from any working directory": E3 and E3s,
    verified for `-p --resume <id>` on CC 2.1.292. The interactive picker and
    `--continue` are untested (evidence §What this settles, 2). The matcher
    fires only on the id-naming refusal that `--resume <id>` prints, so the
    claim holds for every result the verdict is shown on.
  - "(`CLAUDE_CONFIG_DIR`, else `~/.claude`)": E5. It also matches the probe's
    root, `CLAUDE_CONFIG_DIR` if set, else `$HOME/.claude`.
  - Directive shape: one diagnosis clause, then one act ("check that this call
    reads the config directory…"). The human line is lowercase, uses the em-dash
    separator and is factual.

## Mutation testing

Each mutation was an exact replacement of a string occurring once
(`/tmp/claude/sB-cr/mut.py` refuses any other count). Each carried a
`# MUT-<id>` tag. `command grep -cF` found the tag once after the mutation and
zero times after the restore. Each restore was the swapped replacement, and the
file's sha256 after the restore equals the one before the mutation. Only the
named files ran, one `bats` process at a time, in the foreground.

| behaviour | mutation | red or survived (and fixed) |
| --- | --- | --- |
| `found` stops before the `lost` guard (old shape) | M0: `return 0` deleted from the `found` branch | survived, as an equivalent mutant: the `lost` guard returns for `found` anyway. Fixed by removing the dead line (the `case` refactor, Minor 1). |
| any outcome but `lost`/`found` prints nothing | M1: `found)` → `*)` (every non-`lost` outcome gets the found text) | red: `verdicts.bats` "prints nothing for an outcome it has no text for" (`[ -z "$output" ]`); `hook-resume.bats` "no config root to search, silent" |
| `unknown` prints nothing | M2: `lost)` → `lost \| unknown)` | red: `hook-resume.bats` "no config root to search, silent" (`[ -z "$output" ]`) |
| resume-lost has no flag gate (fixtures changed since RED) | M3: `resume-lost:true` put back into the `case` | red: all four `hook-resume.bats` "flag true:" cases, "no verdict emitted, flag 'true'" |
| `tmpdir-unset:false` gate survives | M4: `tmpdir-unset:false \| ` dropped | red: `hook-candidates.bats` "tmpdir-unset flag policy", "every tmpdir-unset fixture is silent unflagged and fires flagged", "dangerouslyDisableSandbox as the string true reads as false" |
| `seccomp-init:true` gate survives | M5: `seccomp-init:true \| ` dropped | red: `hook-candidates.bats` "seccomp-init flag policy" |
| `readonly-path:true` gate survives | M6: ` \| readonly-path:true` dropped | red: `hook-candidates.bats` "readonly-path flag policy", "every readonly-path fixture fires unflagged …" |
| mixed ids, second only → `lost` (fixture split by the test review) | M7 (`lib/probes.sh`): `[ -n "$hit" ] \|\| verdict=lost` → `… && verdict=found \|\| verdict=lost` (the last id decides) | red: "only the second id has a transcript" under flag absent and flag true; both first-only cases stay green |
| mixed ids, first only → `lost` (fixture split by the test review) | M8 (`lib/probes.sh`): the `done < <(printf '%s\n' "$ids")` feed piped through `head -n 1` | red: "only the first id has a transcript" under flag absent and flag true; both second-only cases stay green |

Skipped, because RED shows them red on assertion against unchanged code with an
unchanged fixture: the exact `found` text (RED test 1, plus the test review's
N1/N2 near-miss mutations) and the flag-absent "exists" hook case.

M0–M2 ran against `lib/verdicts.sh`: M0 on the commit's shape, and M1 and M2
after the refactor. M3–M8 ran on the final code.

## Fixes Applied

- `lib/verdicts.sh`, `verdict_resume_lost`: `if`/`return`/guard → one `case`
  over `lost` and `found`. The texts are unchanged, and each `SC2016` directive
  sits on its own `printf`.
- `lib/verdicts.sh`, the comment above `verdict_tmpdir_unset`: names
  `resume_lost` as the candidate that takes an outcome.

## Files changed

- `lib/verdicts.sh`
- `plans/sandbox-lies-review-fixes-2/reports/item-1-1-sB-code-review.md` (this
  report)

`git diff` shows only those two `lib/verdicts.sh` hunks beyond the untouched
pre-existing dirt (`delegate-status.md` unstaged, and the pre-staged handoff
files). `hooks/annotate.sh` and `lib/probes.sh` are unmodified.

## Gate

`just precommit` (unsandboxed, foreground) exited 0, with all 336 tests passing.
Its recap: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits,
links, tests.

## Requirements Validation

| Requirement | Status | Evidence |
| --- | --- | --- |
| Q1: no flag policy for resume-lost | Satisfied | `hooks/annotate.sh` `case`; M3 reds all four flag-true cases |
| Q2 / D-b: `found` verdict, finalized text | Satisfied | `verdict_resume_lost` `found` arm; exact-text tests; text accurate against E2, E3, E3s and E5 |
| D-b: other outcomes print nothing | Satisfied | M1 and M2 |
| Hook verdict contract (no text → nothing) | Satisfied | empty `out` → `continue`; "no config root" case |

## Deferred Items

- **`docs/references/detectors.md` §resume-lost still states "Fires only when
  the flag is false" and has only the `lost` verdict.** The `hooks/annotate.sh`
  comment cites detectors.md for its policies. Reason: Item 5.2 (flag policy as
  Q1 settles it, both verdicts verbatim).

## Positive Observations

- The gate edit is minimal and keeps the three remaining policies on one line.
- The `found` text keeps the verdict contract: one paragraph and one human line,
  with the human line in the curt user-facing register.
