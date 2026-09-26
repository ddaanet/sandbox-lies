# Test review: Item 6.1 slice 4 — `silent unsandboxed`

**Scope**: the uncommitted `readonly-path flag policy` case in
`tests/hook-candidates.bats` and the RED report `item-6-1-s4-red.md`.
`hooks/annotate.sh`, `lib/*`, docs and memory are out of scope. The hook was
mutated in place for the proofs below and then restored.
**Date**: 2026-09-26
**Mode**: review + fix (TDD test review)

## Summary

The case pins both halves of the runbook's slice 4 line with the flag `true`:
empty stdout, and no probe call. Its positive twin runs with the flag absent,
following the same order and shape as the sibling `seccomp-init` and
`resume-lost` cases. It reds on the right assertion. One minor gap was fixed:
the positive half checked only for non-empty output, where the siblings pin the
detector's own human line.

**Overall Assessment**: Ready

## Mechanical check

`direnv exec . scripts/run-bats.sh tests/hook-candidates.bats` (foreground), run
after the fix:

```
not ok 4 readonly-path flag policy
# (in test file tests/hook-candidates.bats, line 111)
#   `[ -z "$output" ]' failed
bats: 7 passed, 1 failed
```

Line 111 is the flag-`true` run's `[ -z "$output" ]`. The case fails on an
assertion, not an error. Every assertion before it passed, including the
positive half's new systemMessage check. The other 7 cases still pass. The RED
report's line 109 is the same assertion; it moved down 2 lines after the fix.

## Wrong-reason hunting

- **Both halves pinned, each able to fail on its own.** Proved by mutating
  `hooks/annotate.sh` in place. Each mutation was an exact-string replace with a
  grep count of 1 confirming it applied, then restored by the inverse replace.
  `git diff -- hooks/ lib/` was empty afterwards:
  | mutation | result |
  |---|---|
  | A: probe runs, then output dropped when `readonly-path:true` (gates the verdict, not the probe) | red at line 112, `[ ! -f "$PROBE_CALLED" ]` |
  | B: the intended GREEN, `readonly-path:true` added to the flag-policy `case` arm | 8 passed, 0 failed |
  | C: `readonly-path:*` in the arm (silent whatever the flag) | red at line 102, positive half "no verdict emitted, flag absent" |

  The reverse split (emit a verdict without probing) is caught by
  `[ -z "$output" ]` in the unmutated RED run. So a GREEN that gates only one of
  the two passes neither assertion.
- **Gate placement.** The stub replaces `probe_readonly_path`. A GREEN that
  moved the gate into the real probe (which receives the flag as `$1`) would
  still have the stub called and would fail line 112. That matches
  `docs/references/hook.md`: a name its flag policy silences is skipped before
  any probe runs.
- **`$PROBE_CALLED` reset.** `stub_probe` runs in the test shell, not under
  `run`, so `PROBE_CALLED` is set in the test's scope. The flag-absent half
  asserts the file exists, then `rm -f` clears it before the flag-`true` run. If
  the file exists after that run, it came from that run. `rm -f` failing on a
  file under `$BATS_TEST_TMPDIR` would itself fail the test under bats' errexit.
- **Other sources of the observable.** `detect` on
  `fire-readonly-path-cp-tmp.txt` names only `readonly-path`, so no other
  detector can supply output to either half. The flag-`true` payload builder is
  the same one `tmpdir-unset flag policy` uses to get a verdict. The empty
  output is therefore not a broken payload, and mutation B shows the case goes
  green once the arm exists.
- **Literal `false`.** Not added. The flag is normalized to `true`/`false` in
  the hook's single jq expression, before any per-name code runs. The
  flag-policy `case` keys on that normalized `$flag`, so no implementation of
  this slice can treat a literal `false` differently from an absent flag. That
  normalization is detector-independent and already pinned by `tests/hook.bats`
  ("flag false differs from absent", which runs absent, `false` and `true` over
  every `fire-masks-*` fixture). It is also pinned by `tests/hook-locks.bats`
  (flag `false` compared with `true`). The sibling `seccomp-init` and
  `resume-lost` cases likewise use the absent flag alone. A third run here would
  not tell apart any GREEN this slice could produce.

## Issues Found

### Critical Issues

None.

### Major Issues

None.

### Minor Issues

1. **Positive half does not pin readonly-path's own verdict**
   - Location: `tests/hook-candidates.bats`, `readonly-path flag policy`,
     flag-absent half
   - Note: The positive half asserted only `-n "$output"` and the probe
     sentinel. The sibling flag-policy cases each also pin the detector's human
     line, which ties the "fires-with" half to that detector's verdict rather
     than to any output. Today the fixture fires only `readonly-path`, so the
     gap is latent. It would open if the fixture ever started firing a second
     detector. Added a `systemMessage` equality check against the `writable`
     human line (`read-only — sandbox allowlist, writable outside`, the stub's
     outcome).
   - **Status**: FIXED

## Fixes Applied

- `tests/hook-candidates.bats` `readonly-path flag policy`: added `sys` to the
  `local` line. Added the flag-absent half's
  `sys=$(… jq -r '.systemMessage')` and an exact match on the writable human
  line, after `[ -f "$PROBE_CALLED" ]`.

## Checks

- Foreground run: the new case reds on line 111 `[ -z "$output" ]`; 7 others
  pass.
- Mutations A/B/C as tabled; `hooks/annotate.sh` restored (empty `git diff`).
- Self-quiet: `bash lib/matchers.sh < tests/hook-candidates.bats` exits 1 with
  empty output.
- Size: 181 lines (was 179 at RED), under 400.
- `shellcheck tests/hook-candidates.bats`: clean.
- `git status --porcelain -- hooks lib tests`: only
  `tests/hook-candidates.bats` modified. Nothing committed.

## Requirements Validation

| Requirement | Status | Evidence |
|---|---|---|
| Runbook slice 4: flag `true` gives empty stdout | Satisfied | line 111; mutation C/unmutated run |
| Runbook slice 4: stub probe records no call | Satisfied | line 112; mutation A |
| FR-5 / detectors.md `readonly-path` flag policy (silent when true) | Satisfied | positive twin with flag absent (lines 97-104) vs flag `true` |
| FR-5 absent means false | Covered elsewhere | `tests/hook.bats` flag false vs absent sweep; normalization precedes the per-name gate |

## Positive Observations

- The sentinel is reset between halves, and the reason is spelled out in the
  RED report.
- `stub_probe` is reused rather than `stub_probe_kv`: the policy needs no
  particular `path=` line.
- The case sits with the other `<detector> flag policy` cases and matches their
  order (fires-with half first, then the silent half).
