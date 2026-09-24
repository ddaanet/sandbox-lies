# Review: Item 2.4 / slice 4 — test review (b)

**Scope**: `tests/probes.bats` uncommitted additions (setup reset, `teardown`,
`held lock names the holder`, `held lock under a quoted, spaced path`) and
`plans/sandbox-lies/reports/item-2-4-s4-red.md`. `lib/probes.sh` for stub
completion only; none was needed.
**Date**: 2026-09-25
**Mode**: review + fix

## Summary

Both tests were red on their `held` assertion, as the RED report says. The
review found one defect that would have blocked GREEN: teardown's `wait` on
the killed job returns 143, and a failing teardown fails the test. It also
found three wrong-reason gaps and a readiness race. All are fixed. Both tests
are still red on their line-1 assertion. Checked against a scratch copy of
the tree, a correct holder check now turns them green and each named wrong
probe keeps them red.

**Overall Assessment**: Ready

## Mechanical check

`scripts/run-bats.sh tests/probes.bats`, foreground, before the fixes and
after them:

- `held lock names the holder`: FAILED on `[ "${output%%$'\n'*}" = held ]`.
- `held lock under a quoted, spaced path`: FAILED on the same assertion.
- Slices 1–3 (6 tests): pass.

Neither test errored or passed. `status` was 0 and `stderr` empty before the
failing line, so the stub is complete.

## Issues Found

### Critical Issues

1. **Teardown fails every held test once the probe is implemented**
   - Location: `tests/probes.bats` `teardown()`
   - Problem: `wait "$pid"` on a job that was just killed returns 143. Bats
     1.11.1 marks the test failed when teardown fails. Reproduced in a
     scratch bats file: a passing test body gave `not ok … from function
     'teardown' … wait "$p" 2>/dev/null' failed with status 143`. RED could
     not see this because both tests already failed. GREEN could never pass.
   - Fix: added `|| :` to both `kill` and `wait`, with a comment explaining
     why.
   - **Status**: FIXED

### Major Issues

1. **Nothing checks that the holder is ready before the probe runs**
   - Location: both held tests, `sleep 30 4<"$lock" 3>&- &`
   - Problem: the child opens the redirect after the fork. Nothing ordered
     that open before the probe's holder query, so on a loaded box the probe
     could see no holder and print `orphan`, which is a flaky red.
   - Fix: added a new `hold_lock <lock>` helper. It runs
     `( exec 4<"$1"; : >"$ready"; exec sleep 30 ) 3>&- &` and polls for the
     ready file, at most 50 × 0.1 s. The file is written only after the open.
     If the open fails, no file appears and the test fails within 5 s instead
     of hanging. Because the subshell execs `sleep`, `$!` stays the holder's
     pid. The scratch run confirmed that `fuser` reports that pid.
   - **Status**: FIXED

2. **A probe printing `pid=$!` passed**
   - Location: both held tests
   - Problem: bash subshells inherit `$!`. The probe runs in `run`'s
     subshell, and the holder was the test's last background job, so a
     probe emitting `pid=$!` whenever a holder exists printed the right pid.
   - Fix: `hold_lock` ends with a finished decoy job (`: &; wait "$!"`), so
     `$!` no longer names the holder. Scratch mutant `pid=$!` is now red on
     the `pid=` assertion.
   - **Status**: FIXED

3. **The number of `pid=` lines was not pinned**
   - Location: both held tests
   - Problem: the exact-line `grep -qxF "pid=$pid"` passes when the holder
     is one of several `pid=` lines. A holder query wider than the lock
     (`fuser -m`, the directory) or a probe adding `$$` would pass.
   - Fix: added `[ "$(… | grep -c '^pid=')" -eq 1 ]`. With one holder this
     does not decide the several-holders question (see Recommendations).
     Scratch mutant "holder plus `$$`" is now red on the count assertion.
   - **Status**: FIXED

4. **`held` was pinned only for flag `false`**
   - Location: `held lock names the holder`
   - Problem: detectors.md's flag policy says the flag only chooses between
     `mask` and `gone` for an absent lock, so `held` does not depend on it.
     A probe that runs the holder check only when sandboxed passed. This is
     the same gap slice 3's reviews closed for `orphan`.
   - Fix: added a second `run_probe` with flag `true` and the same
     assertions. Scratch mutant "holder check only when flag is false" is
     now red on this test.
   - **Status**: FIXED

### Minor Issues

1. **A comment claimed `$!` is the sleep because bash execs the backgrounded
   command directly**
   - Location: the comment block above the first held test
   - Note: the mechanism changed to a subshell that execs `sleep`. The
     comment was rewritten as `hold_lock`'s header: readiness, fd 3, the
     exec'd pid and the decoy. The quoted-path test's comment now says what
     an unquoted holder call actually does: two nonexistent paths, no
     holder, misses reported on stderr (checked with `fuser` here).
   - **Status**: FIXED

## Questions from the dispatch

- **`held` for every present lock**: red. Slice 3's `present unheld lock is
  orphan` runs with the holder tool on `PATH`, and the held tests pin the
  holder's pid.
- **`pid=$$`**: red (`$$` is the bats test process). Scratch mutant
  confirmed.
- **Pid of any process with the directory open**: no other process holds
  the lock or has the directory as its cwd, so an exact pid match excludes
  it. A multi-pid answer is now excluded by the count assertion.
- **Unquoted `fuser`**: the second test pins quoting. `fuser $l` on the
  spaced path prints `Specified filename …/it's does not exist.` twice and
  exits 1. Scratch mutant red on `held`.
- **Teardown**: runs after an early assertion failure (bats always runs
  teardown). `hold_lock` records the pid before its readiness wait, so a
  timeout still gets the job killed. `pgrep -x sleep` was empty after every
  run.
- **Dependence on `fuser`**: none. The assertions are tool-agnostic (`held`,
  one exact `pid=` line, empty stderr), so `lsof -t` on macOS meets the same
  bar. The empty-stderr assertion pins the item's rule that `fuser`'s stderr
  path line is captured. With no tool at all, the test is red on `unknown`,
  which is loud.
- **Self-quiet**: `bash lib/matchers.sh < tests/probes.bats` gives no output,
  `rc=1`.

## Scratch verification (not shipped)

`lib/` and `tests/` were copied to a scratch directory, keeping the
`$BATS_TEST_DIRNAME/..` layout. A `fuser`-based held branch was spliced into
the copy's `probes.sh`. Results for tests 7 and 8:

| probe variant | test 7 | test 8 |
|---|---|---|
| correct (first `fuser` pid) | ok | ok |
| `pid=$!` | red, `pid=` | red, `pid=` |
| `pid=$$` | red, `pid=` | red, `pid=` |
| unquoted `fuser $path` | red | red, `held` |
| holder pid plus `$$` | red, count | red, count |
| holder check only for flag `false` | red, `held` | ok (flag `false` only) |

The scratch directory was removed afterwards, and the real `lib/probes.sh`
was never edited.

## Fixes Applied

- `tests/probes.bats` `teardown()`: `kill … || :` and `wait … || :`, plus a
  comment on the 143 status.
- `tests/probes.bats`: new `hold_lock` helper (readiness file with a bounded
  poll, a subshell that execs `sleep`, fd 3 closed, a decoy job) replacing
  the inline `sleep 30 4<"$lock" 3>&- &` in both tests.
- `tests/probes.bats` `held lock names the holder`: `pid=` count pinned to 1,
  and a flag-`true` run added.
- `tests/probes.bats` `held lock under a quoted, spaced path`: `pid=` count
  pinned to 1, and its comment corrected.
- The file is now 256 lines (cap 400).

## Final run

```
not ok 7 held lock names the holder
#   `[ "${output%%$'\n'*}" = held ]' failed
not ok 8 held lock under a quoted, spaced path
#   `[ "${output%%$'\n'*}" = held ]' failed
bats: 6 passed, 2 failed
```

Both tests are red on their line-1 assertion. `pgrep -x sleep` is empty, so
no job was left behind.

## Recommendations

- **For the list revision: behaviour with several holders is not pinned.**
  `pid=` is singular in the contract, but `fuser` or `lsof -t` can return
  several pids, for example git plus a hook child. The choices are the first
  pid, all pids on one line, or one line per pid. The count-of-1 assertion
  here holds under the first two. If the list chooses one line per pid, it
  would need a two-holder case. This is still an open decision, and no test
  presupposes an answer.
- For GREEN, the runbook's ordering constraint still applies and is not a
  test here: the holder check runs before the size and age reads, or
  presence is re-checked afterwards.
