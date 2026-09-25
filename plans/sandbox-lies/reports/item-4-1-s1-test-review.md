# Review: Item 4.1 slice 1 — test review

**Scope**: `tests/hook-locks.bats` (new), `tests/verdicts.bats` (changed), the
inert stubs `verdict_git_lock` / `verdict_config_lock` in `lib/verdicts.sh`
(checked for completeness only), and the RED report `item-4-1-s1-red.md`.
**Date**: 2026-09-25
**Mode**: review + fix

## Summary

The mechanical check passes: every new or extended test fails on an assertion.
None passes and none errors. The `tests/verdicts.bats` additions are sound.
They transcribe `lock-detectors.md` exactly, checked by parsing the doc's
`mask`/`gone` bullets and comparing them to the test literals: 4 of 4 match.

The hook cases had two wrong-reason holes, and both are fixed:

- A stub that the hook never reached still passed cases 1 and 3, because the
  real probe on this fixture also answers `mask`.
- Case 2 could not detect a mask paragraph that varies with the flag.

I confirmed both holes by running the tests against a simulated GREEN in a
scratch copy of the tree.

**Overall Assessment**: Ready

## Issues Found

### Critical Issues

1. **An unseen stub, or no probe call at all, passes cases 1 and 3**
   - Location: `tests/hook-locks.bats`, cases `mask outcome through the hook`
     and `... under BSD stubs`.
   - Problem: the stub's output was never observable. `mask` interpolates
     nothing, so `path=stub` does not reach the output. The fixture names
     `/Users/david/code/micro/.git/index.lock`. That repo exists on this host,
     but the lock file does not. So the real `probe_git_lock` under flag false
     also answers `mask`.

     I built a simulated GREEN in a scratch copy of the tree, with the hook
     sourcing `lib/probes.sh` and calling the probe per the Interfaces block.
     Then I ran the original case 1 against two faults. It stayed green
     against both:

     - **M1:** the hook never sources or calls a probe, and the verdict
       defaults to `mask` when it gets no outcome.
     - **M2:** the hook sources a probes file the stub was never appended to,
       so the real probe runs and stats the host path.

     Under M2 the fixture's absolute path reaches the host filesystem. The
     runbook forbids exactly that ("no fixture's absolute path reaches the
     host filesystem"), and the stub mechanism was meant to guarantee it.
   - Fix: added a `stub_probe <name> <outcome>` helper. It appends the
     override through `stub_lib`, and the override touches a sentinel,
     `$PROBE_CALLED` under `$BATS_TEST_TMPDIR`. The sentinel path is expanded
     with `printf %q` when the stub is built, so the stub does not depend on
     the hook's environment. Every case now asserts `[ -f "$PROBE_CALLED" ]`
     right after the status check. Re-run: M1 and M2 both turn all three
     cases red on the sentinel, and the unfaulted simulated GREEN passes all
     three.
   - **Status**: FIXED

### Major Issues

1. **The flag-neutral case could not detect flag-dependent wording**
   - Location: `tests/hook-locks.bats`, case `mask paragraph is flag-neutral
     under flag true`.
   - Problem: the case only checked that the flag-true context contains
     `once no sandboxed command is running`. That clause sits inside the flag
     policy the case exists to rule out: "the `mask` wording holds under both
     flags rather than taking the flag as an argument". A hook that passes
     the flag to the verdict, with a verdict that prints a shorter flag-true
     paragraph keeping that clause, would pass.
   - Fix: the case now runs the same fixture and stub under flag `false` and
     then under flag `true`. It asserts that the flag-true context carries the
     clause, and that context and `systemMessage` are identical across the two
     runs. The clause check is also the non-emptiness guard for the equality.
     The sentinel is cleared between runs and asserted after the flag-true
     run. Re-run with a fault (M3: the hook passes `$flag` as the verdict's
     `$2`, and the verdict prints a variant for `true` that keeps the clause):
     the case goes red on `[ "$ctx_true" = "$ctx_false" ]`. The original
     assertion would have passed it.
   - **Status**: FIXED

### Minor Issues

None.

## Checks the brief named

- **Mechanical.** In the final run below, the three new cases and the two
  changed `verdicts.bats` cases fail on an assertion. None passes and none
  errors. The inert stubs are complete: `verdict_git_lock` and
  `verdict_config_lock` exist and print the two-line shape, so the row test
  reds on its line-count assertion, not on a missing function.
- **Does the stub reach the hook?** It is appended to the copied
  `lib/probes.sh`. That file has no dispatcher or trailing code, so a later
  definition wins once `annotate.sh` sources it from `$script_dir/../lib`. The
  simulated GREEN confirmed this. The sentinel now makes it an assertion, not
  an assumption.
- **Does the real probe touch the fixture's path?** Not under GREEN: the stub
  overrides it and the sentinel proves it. Before the fix, nothing proved it
  (see Critical 1).
- **Does the BSD-stub case run under the stubs?** Yes. I prefixed each stub
  with a logging line and ran the hook the way the case does, with
  `PATH="$bsd:$PATH"` on a function call. The log showed the matchers' `grep`
  calls and the phantom detector's `sed -E` going through the stubs. Under
  GREEN the probe is stubbed, so `lib/probes.sh`'s own `sed` is not exercised
  here. The probe suites cover that.
- **Are the transcriptions exact?** Yes. I compared all four literal
  paragraphs and human lines with the corresponding bullets in
  `docs/references/lock-detectors.md`, after joining the wrapped lines: all
  match.
- **Self-quiet.** `detect` from `lib/matchers.sh` exits 1 (nothing fires) on
  `tests/hook-locks.bats`, `tests/verdicts.bats` and `lib/verdicts.sh`. The
  hook cases read the fixture at run time, and no test source contains the
  lock diagnostic together with its follow-on sentence.
- **Shellcheck:** `shellcheck tests/hook-locks.bats tests/verdicts.bats
  lib/verdicts.sh` is clean. `tests/hook-locks.bats` is 96 lines.

## Fixes Applied

- `tests/hook-locks.bats` — added the `stub_probe` helper, which writes a
  sentinel. All three cases use it and assert the sentinel. Case 2 now
  compares the flag-true run with the flag-false run.
- `tests/verdicts.bats` — no change.
- `lib/verdicts.sh` — no change. The stubs are complete.

## Final red run

`cd /Users/david/code/sandbox-lies && bats tests/hook-locks.bats tests/verdicts.bats`, run in the foreground:

```
1..8
not ok 1 mask outcome through the hook
# (in test file tests/hook-locks.bats, line 47)
#   `[ -f "$PROBE_CALLED" ]' failed
not ok 2 mask paragraph is flag-neutral under flag true
# (in test file tests/hook-locks.bats, line 74)
#   `[ -f "$PROBE_CALLED" ]' failed
not ok 3 mask outcome through the hook under BSD stubs
# (in test file tests/hook-locks.bats, line 93)
#   `[ -f "$PROBE_CALLED" ]' failed
not ok 4 verdicts under 400 chars
# (in test file tests/verdicts.bats, line 74)
#   `[ "$(printf '%s\n' "$text" | awk 'END { print NR }')" -eq 2 ]' failed
ok 5 verdict text is quiet
ok 6 verdict text matches detectors.md
not ok 7 lock verdict text matches lock-detectors.md
# (in test file tests/verdicts.bats, line 131)
#   `[ "$line1" = 'The lock in this error is a sandbox artefact ... `GIT_INDEX_FILE`, not the sandbox.' ]' failed
ok 8 no removal instruction
```

Cases 5, 6 and 8 existed before this slice and stay green. Cases 1 to 3 now go
red first on the probe-invocation assertion. Their content assertions follow
it and were shown to pass for the right reason against the simulated GREEN.

The simulated GREEN, which I have since deleted, went 8 of 8 green. Against
its faults, the revised tests went red as follows:

| Fault | Cases red | Failing assertion |
|---|---|---|
| M1 | 1, 2, 3 | sentinel |
| M2 | 1, 2, 3 | sentinel |
| M3 | 2 | context equality |

## Requirements Validation

| Requirement | Status | Evidence |
|---|---|---|
| FR-4 (hook → probe → verdict) | Satisfied (test side) | The sentinel pins that the hook invokes the stubbed probe, and the `mask` output pins that line 1 becomes the outcome |
| FR-6 (paragraph < 400 chars) | Satisfied (test side) | Rows for all ten name/outcome pairs in `verdicts under 400 chars` |
| FR-10 / NFR-2 (portability) | Satisfied | The BSD-stub case is confirmed to route `grep`/`sed` through the stubs |
| Flag-neutral `mask` wording (lock-detectors.md flag policy) | Satisfied | Case 2's flag-true/flag-false equality |

## Positive Observations

- The `verdicts.bats` transcription is kept separate from `lib/verdicts.sh`
  and matches the doc exactly. Held, orphan and unknown are deferred to the
  slices that own their interpolation.
- `stub_lib`'s existing guard against a misnamed file stops the stub from
  being silently inert at the file level. The sentinel extends that to the
  call level.

## Recommendations

- **Residual.** The sentinel detects an unseen stub but does not stop it:
  under that fault the real probe still makes a read-only `stat` and holder
  check of the fixture's host path before the assertion fails. Preventing it
  would mean rewriting the fixture's path. That departs from the runbook's
  chosen mechanism (stubbing), so I left it.
- **For the orchestrator: sequencing.** `verdicts under 400 chars` now
  requires non-empty two-line text for `held`, `orphan` and `unknown` in this
  slice's GREEN. Whatever GREEN writes for them may already satisfy slices
  2–3's hook assertions, which would make those slices' tests green on first
  run. If so, slices 2–3 need one mutation each to supply their red.
- **For slices 2–9.** Reuse `stub_probe` in the later cases. Slice 4's
  argument recorder is a variant of it.
