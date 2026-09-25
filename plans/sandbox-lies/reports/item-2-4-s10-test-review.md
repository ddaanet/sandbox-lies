# Review: Item 2.4 slice 10 — test review (b)

**Scope**: `tests/probes-tools.bats` (new, four `@test` cases) and the RED
report `plans/sandbox-lies/reports/item-2-4-s10-red.md`; `lib/probes.sh` read
and mutated in place only for the mutation proofs, and restored each time.
**Date**: 2026-09-25
**Mode**: review + fix

## Summary

The RED holds: `errored holder check is unknown` fails on its own assertion
and the other 23 tests pass. The three stat cases each red under a mutation
different from the RED report's. One real wrong-reason gap: nothing in the
suite stopped a GREEN from reading *any* holder-tool stderr with no pid as
`unknown`. Every existing stub that writes stderr also prints a pid, the
`<path>:ce` variant included, so each of them resolves to `held` before the
errored check runs. Fixed by adding a positive to the start of the test. Two
assertions were also tightened.

**Overall Assessment**: Ready

## Mechanical check

`scripts/run-bats.sh tests/probes.bats tests/probes-edges.bats
tests/probes-tools.bats`, run in the foreground:

- Before the fixes: `not ok 21 errored holder check is unknown`, line 43,
  `[ "${output%%$'\n'*}" = unknown ]` failed; `23 passed, 1 failed`.
- After the fixes: the same test fails at line 63, the first negative
  sub-case's `= unknown` assertion. The new positive before it passes.
  `23 passed, 1 failed`.

## Issues Found

### Critical Issues

None.

### Major Issues

1. **No positive pinned a quiet holder check with no pid as orphan**
   - Location: `tests/probes-tools.bats`, `errored holder check is unknown`
   - Problem: the runbook names `unexpected holder-tool stderr is passed
     through` and `present unheld lock is orphan` as the positives. The first
     is not a positive for this guard. Both of its stubs (the foreign line
     and the `<path>:ce` variant) print pid 77, so both read `held` whatever
     the errored check does. `present unheld lock is orphan` runs the real
     psmisc `fuser`, which prints nothing when it finds no holder. That rules
     out keying on the exit status, but it never feeds the check any stderr.
     So a GREEN reading any holder-tool stderr without a pid as `unknown`
     passes every test. On a POSIX `fuser`, which prints `<path>:` on every
     call (the `_probe_holder_pids` comment says so), every unheld lock would
     then read `unknown` and the `orphan` verdict would never be given.
   - Fix: the test now opens with a positive on the same fixture, differing
     from the first negative only in the stub's stderr line: a stub printing
     `<path>:` only, no pid, exit 1 → `orphan`, `bytes=7`, empty stderr. The
     header comment now explains why it is there.
   - Proof: mutant `return 0` → `return 3` in the expected-shape branch of
     `_probe_holder_pids`, plus `holder_status -eq 2` → `-ne 0`. This reads
     the expected `<path>:` shape without a pid as `unknown`. The full run
     then reds **only** the new positive (line 50, `= orphan` failed) and
     `23 passed, 1 failed`. Every pre-existing test stays green, which
     confirms the gap. Restored by inverse replacement; `grep -cF` for both
     mutant strings → 0; `git diff lib/probes.sh` empty.
   - Also tried: a cruder mutant that returns 3 on any non-empty stderr
     without passing it on. It also reds `unexpected holder-tool stderr is
     passed through` (on its stderr assertion) and `dangling symlink lock is a
     quiet orphan`. Those tests do constrain crude variants, but not the
     precise one above.
   - **Status**: FIXED

### Minor Issues

1. **Missing-interpreter sub-case asserted only non-empty stderr**
   - Location: `tests/probes-tools.bats`, the second negative sub-case
   - Note: `[ -n "$stderr" ]` is satisfied by stderr from any source. On this
     box, bash 5.2.37 prints `…/fuser: cannot execute: required file not
     found` with exit 127, checked by hand. Bash 3.2 on macOS prints `…/fuser:
     /nonexistent/interpreter: bad interpreter: No such file or directory`
     with exit 126. Both name the stub's full path, and both are real exec
     failures. The assertion is now `printf '%s\n' "$stderr" | grep -qF
     "$toolsdir/fuser"`, which holds on both platforms. I used `grep`, not
     `[[ ]]`, to match the file's style and to avoid `[[`'s errexit quirk on
     old bash. The exit codes are recorded in the header comment. I also
     confirmed by hand that this sub-case currently reads `orphan` with that
     stderr, so it reds once reached. In RED it is never reached because the
     first negative aborts the test.
   - **Status**: FIXED

2. **`%m` test did not prove its fixture reaches the branch**
   - Location: `tests/probes-tools.bats`, `a file named %m in the cwd`
   - Note: the test assumes GNU `stat -f %m <lock>` exits 0 in the scratch
     directory. If it did not, the digit check would never run and the test
     would pass vacuously. I added `stat -f %m "$lock" >/dev/null` after the
     `cd`. It exits 0 on GNU only because of the `%m` file (without it, rc=1,
     checked by hand), and on BSD because it is a real mtime read, so it is
     portable. The directory is `$BATS_TEST_TMPDIR/mdir`, never the repo root,
     and the probe runs with that cwd because `run` inherits the test's `cd`.
   - **Status**: FIXED

3. **Stale helper header**
   - Location: `tests/helpers/probes.bash:1-2`
   - Note: it named only `probes.bats` and `probes-edges.bats` as consumers.
     `probes-tools.bats` now loads it too, and the header lists all three.
   - **Status**: FIXED

## Mutation proofs (mine, each different from the RED report's)

All are exact-string replacements, and each old string occurs once in
`lib/probes.sh` (checked by a count before replacing). Each is restored by
inverse replacement, followed by a `grep -cF` for the mutant string → 0.
After the last restore, `git diff --stat lib/probes.sh` is empty and a full
rerun gives `23 passed, 1 failed`, the one failure being the expected red.

| Test | Mutation | Result |
|---|---|---|
| `a file named %m in the cwd` | BSD branch `&& _probe_is_seconds "$mtime"; then` → `&& [ -n "$mtime" ]; then` (non-empty in place of digits) | reds at line 97, `[ "$status" -eq 0 ]` |
| `non-seconds stat output is dropped` | GNU branch `\|\| ! _probe_is_seconds "$mtime"; then` → `\|\| [ -z "$mtime" ]; then` | reds at line 126, `[ "$status" -eq 0 ]` |
| `vanished lock is gone under BSD stat` | the 8-space `if [ ! -e "$path" ] && [ ! -L "$path" ]; then` → a check keyed on GNU's `No such file` text | reds at line 159, `[ -z "$stderr" ]`; **`vanished lock is gone` (GNU) stays green**, so this test is the only guard of "keys on the filesystem, not the error text" |

The status-0 failures in the first two rows come from the probe dying in the
arithmetic on the non-digit value. That is the failure mode the digit checks
exist to prevent. In each run the only other failure is `errored holder check
is unknown`, which is red at baseline anyway.

## Other checks

- Portability: the file loads `helpers/bsd-stubs` and `helpers/probes`, and
  `vanished lock is gone under BSD stat` runs `make_bsd_stubs stat`.
- Self-quiet: `bash lib/matchers.sh < tests/probes-tools.bats` → no output,
  rc=1. The same holds for `tests/helpers/probes.bash`.
- `shellcheck -x tests/probes-tools.bats tests/helpers/probes.bash` → exit 0.
- Line counts: `tests/probes-tools.bats` 168, `tests/helpers/probes.bash` 71.
- `non-seconds stat output is dropped`: the exact stderr assertion `12
  junk\nwarn` pins that a rejected value goes to stderr, as the probe's
  comment specifies. The stub's two lines are written in sequence, so their
  order is deterministic.
- Nothing committed. Tree: `?? tests/probes-tools.bats`, `M
  tests/helpers/probes.bash`, and `lib/probes.sh` identical to HEAD.

## Fixes Applied

- `tests/probes-tools.bats` `errored holder check is unknown`: a positive
  sub-case first (`<path>:`-only stub, no pid, exit 1 → `orphan`, `bytes=7`,
  empty stderr); the header comment rewritten to say why, including the exec
  failure's wording and exit code on bash 5 and 3.2.
- `tests/probes-tools.bats` missing-interpreter sub-case: `[ -n "$stderr" ]`
  replaced by a `grep -qF` for the stub's path.
- `tests/probes-tools.bats` `a file named %m in the cwd`: added a
  precondition that `stat -f %m "$lock"` exits 0 in the scratch cwd.
- `tests/helpers/probes.bash`: the header names all three consumers.

## Requirements Validation

| Requirement | Status | Evidence |
|---|---|---|
| Slice 10: errored check → `unknown`, `bytes=7`, no `pid=`, line on stderr; exec failure → `unknown`, stderr | Satisfied (red, as RED requires) | `tests/probes-tools.bats` errored test |
| Positives stay constraining | Satisfied after fix | new positive; mutation above |
| `%m`, non-seconds, BSD-vanish cases, mutation-proven | Satisfied | table above |
| NFR-2 (bsd-stubs loaded, BSD case) | Satisfied | file header, BSD vanish test |
| FR-11 self-quiet | Satisfied | matchers check rc=1 |

## Positive Observations

- The permission-error stub pins stderr exactly, which rules out extra noise
  and a dropped line alike.
- The BSD-vanish case turns out to be the only discriminator against a gone
  check keyed on error text, so its inclusion is justified beyond the
  hand-check it replaces.
