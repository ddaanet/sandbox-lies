# Review: Item 2.4 / slice 5 — test review (b)

**Scope**: `tests/probes.bats` (helper move plus `character device is mask`),
new `tests/probes-edges.bats`, new `tests/helpers/probes.bash`, RED report
`item-2-4-s5-red.md`. `lib/probes.sh` touched only for mutation proofs, each
restored.
**Date**: 2026-09-25
**Mode**: review + fix (TDD test review)

## Summary

The helper move is clean, and the three edge cases were each reproduced red by
a different mutation. The character-device test reds on its own assertions.
Two gaps were fixed:

- The character-device test could not tell a character-device rule from a rule
  that masks any symlink.
- The non-regular-lock test left out the directory fixture that the runbook's
  slice text names.

**Overall Assessment**: Ready

## Mechanical check

`scripts/run-bats.sh tests/probes.bats tests/probes-edges.bats`, before the
fixes: `11 passed, 1 failed`. The only failure was `not ok 9 character device
is mask`, on `` `[ -z "$stderr" ]' failed ``. The eight earlier
`tests/probes.bats` cases pass, so the helper move broke nothing.

The first assertion to fail changes from run to run. Usually `fuser`'s
`/dev/null:` line reaches stderr, so the stderr assertion reds first. In two
runs out of about ten, that line was missing, and the test redded on the next
assertion, `` `[ "${output%%$'\n'*}" = mask ]' ``. Both assertions belong to
this test and both check behaviour the SUT does not have yet: it answers
`held`/`pid=` for the symlink to `/dev/null`. GREEN clears both.

### Mutation proofs, each with a different mutation from the RED's

Every mutation replaced a string that occurs exactly once (the script checks
the count), then ran both suites in the foreground. Each was restored by the
inverse replacement. The restore was proved by `grep -c` of the mutant string
returning 0 and by `git diff lib/probes.sh` being empty.

| Test | Mutation | Red on |
|---|---|---|
| `vanished lock is gone` | vanish branch `printf 'gone\n'` → `printf 'orphan\n'` | `` `[ "$output" = "$(printf 'gone\npath=%s' "$lock")" ]' `` (line 82): the `gone` token itself, not only the quiet stderr |
| `non-regular lock has no size`, FIFO half | `[ -f "$path" ]` → `[ ! -d "$path" ]` (still excludes directories, lets FIFOs through) | `` `[ "$status" -eq 0 ]' `` (line 105), the 3s bound fired. Whole run took 5.7s. `pgrep` for `index.lock`, `wc -c` or `bats-exec` afterwards: nothing |
| `non-regular lock has no size`, directory half (added below) | `[ -f "$path" ]` → `[ ! -p "$path" ]` (still excludes FIFOs, lets directories through) | `` `[ -z "$stderr" ]' `` (line 116), the directory run |
| `future mtime is age 0` | `age=$((now - mtime))` → `age=$((mtime - now))` (sign error) | `` grep -qxF "age=0"' `` (line 135) |
| `character device is mask`, symlink control (added below) | `if [ -L "$path" ]; then printf 'mask\npath=%s\n' "$path"; return 0; fi` inserted before `local pids holder_pid` | `` `[ "${output%%$'\n'*}" = orphan ]' `` (line 257), the control |

The last mutation, masking any symlink, prints exactly `mask` and `path=$lock`
with empty stderr under both flags. Before the control was added it satisfied
every assertion in the original test.

## Issues Found

### Critical Issues

None.

### Major Issues

1. **Character-device test passed by a probe that masks any symlink**
   - Location: `tests/probes.bats`, `character device is mask`
   - Problem: the only character-device fixture is a symlink. A probe keyed on
     `[ -L ]` instead of on what the path stats as (docs/references/detectors.md
     row: "it stats as a character device") prints `mask` and `path=$lock` with
     empty stderr under both flags. That passes the test and every other test
     in both files, because no other fixture holds a symlink.
   - Fix: the test now starts with a control. A symlink to a 7-byte regular
     file, flag `false`, must give `orphan`, `bytes=7` and empty stderr. The
     only difference from the `/dev/null` fixture is the symlink's target, so
     the control fixture differs only in what triggers the rule. The mutation
     above proves the control reds.
   - **Status**: FIXED

2. **Non-regular-lock test missed the runbook's directory fixture**
   - Location: `tests/probes-edges.bats`, `non-regular lock has no size`
   - Problem: slice 5's runbook text says "a FIFO (and a directory) at the
     lock path", but the test covered only the FIFO. A guard that excludes
     FIFOs and nothing else (`[ ! -p ]`) passed it. Reading a directory opens
     and then errors: `wc` writes to stderr and prints a `bytes=` line.
   - Fix: after the FIFO run, the test replaces the lock with a directory and
     reruns through `run_probe_bounded` with the same four assertions. The
     header comment says why. The mutation table shows each half reds under a
     mutation the other half does not catch.
   - **Status**: FIXED

### Minor Issues

None.

## Wrong-reason hunting (questions from the dispatch)

- **Mask for any symlink**: before the fix, yes, it passed. Fixed by major
  issue 1.
- **Mask for any present path under flag `false`**: `present unheld lock is
  orphan` (`tests/probes.bats` slice 3) catches it. Its flag `false` run on a
  present regular file expects `orphan`. `quote and space in the lock path`
  also catches it, and so does the new control inside the character-device
  test.
- **`path=` is the lock path**: it asserts `grep -qxF "path=$lock"` under both
  flags. A probe that resolves the link (for example `path=/dev/null` from
  `readlink`) has no line matching `path=$lock`, so it fails.
- **FIFO bound**:
  - Portable: it uses a background job plus `kill`, with no GNU `timeout`.
    `set -m` and `sleep 0.1` both work on bash 3.2 and on BSD/GNU `sleep`.
  - Fails rather than hangs: status 124 turns into a failed
    `[ "$status" -eq 0 ]`, and the whole run finished in 5.7s under the
    blocking mutation.
  - No stray process: `kill -- "-$pid"` takes down the whole process group,
    including the grandchild blocked in `open(2)`, and `pgrep` found no
    leftovers.
  - No FIFO writer is ever opened.
  - `set +m` is restored on both exits.
  - Race: `kill -0` polling stops once bash reaps the job. The one hazard left
    is pid reuse within 100ms, which does not matter here.
- **`stat` stub (vanished lock)**:
  - `$stubdir` holds only `stat`, so only `stat` is shadowed.
  - The stub removes its last operand and then `exec`s the real `stat`, whose
    absolute path was baked in at build time and is quoted inside the stub.
  - Pass-through is load-bearing: a stub that did not reach the real `stat`
    would exit 0 with an empty mtime, which gives `orphan`.
  - The stub is written only under `$BATS_TEST_TMPDIR/stat-stub`, and the
    `PATH=` prefix applies only for the duration of the `run_probe` function
    call.
  - The lock is recreated before the flag `true` run, so both runs go through
    the vanish window and neither one hits the absent-at-entry branch.
- **`future mtime is age 0`**: a probe that always prints `age=0` passes this
  test, but slice 3's `[ "$age" -gt 86400 ]` on a lock dated 2000 catches it.
- **`tests/probes-edges.bats` loads `helpers/bsd-stubs`**: yes, at line 11,
  following the convention. Slice 6's stubs go in this file.
- **Self-quiet**: `bash lib/matchers.sh <` each of the three files prints
  nothing and returns `rc=1`, both before and after the fixes.

## Fixes Applied

- `tests/probes.bats`, `character device is mask`:
  - new symlink-to-regular-file control (`orphan`, `bytes=7`, empty stderr)
    before the `/dev/null` runs, then `rm` and relink to `/dev/null`
  - the header comment now covers the control
- `tests/probes-edges.bats`, `non-regular lock has no size`:
  - new directory run after the FIFO run, with the same four assertions,
    through `run_probe_bounded`
  - the header comment says what the directory case adds

## Final state

- `scripts/run-bats.sh tests/probes.bats tests/probes-edges.bats`:
  `11 passed, 1 failed`. The only failure is `not ok 9 character device is
  mask`, on an assertion in the `/dev/null` half: line 266 `[ -z "$stderr" ]`
  or line 267 mask token, depending on `fuser`'s stderr. The control half
  passes against the unmodified SUT.
- `lib/probes.sh`: `git diff` is empty, byte-identical to HEAD.
- `pgrep -fa 'sleep 30'`: only pgrep's own invoking shell. No suite leftovers.
- Self-quiet: all three files produce no output, `rc=1`.
- `shellcheck`: only the SC1091 info on `source "$ROOT/lib/probes.sh"`, which
  was already present in the committed `tests/probes.bats`.
- `wc -l`: `tests/probes.bats` 276, `tests/probes-edges.bats` 136,
  `tests/helpers/probes.bash` 22. All are under the 400-line cap.

## Per-test result (the red batch GREEN must clear)

- `character device is mask`: FAILED on an assertion in the `/dev/null` half.
  The SUT gives `held`/`pid=` plus `fuser` stderr, and the test wants `mask`
  under both flags, `path=$lock` and empty stderr. The control half (a symlink
  to a regular file gives `orphan`) must stay green, so GREEN has to test what
  the path stats as (`[ -c ]`, which follows the link), not `[ -L ]`.
- The 8 earlier `tests/probes.bats` cases and the 3 `tests/probes-edges.bats`
  cases pass. Each edge case was proved non-vacuous by mutation above.

## Positive Observations

- `vanished lock is gone` compares the entire output, which pins that no
  `bytes=` or `age=` line appears.
- The RED report writes down the process-group trap behind
  `run_probe_bounded`, so a later slice reusing the pattern will not hit it
  again.
- Moving the helpers alone changed nothing: the RED ran a baseline before the
  move and again after it.
