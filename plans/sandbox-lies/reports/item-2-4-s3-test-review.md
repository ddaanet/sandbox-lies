# Review: Item 2.4 / slice 3 — test review

**Scope**: the three slice-3 tests in `tests/probes.bats` (`present unheld
lock is orphan`; `unexpected flag reads as sandboxed`; `quote and space in the
lock path`) and the RED report `item-2-4-s3-red.md`. `lib/probes.sh` was in
scope for stub completion only. It was mutated once for the proof below and
restored; it is byte-identical to HEAD.
**Date**: 2026-09-25
**Mode**: review + fix (test review, TDD slice)

## Summary

The RED run is sound. Both `orphan` tests FAILED on their line-1 `orphan`
assertion, with no ERROR, and the flag test passes as designed with a mutation
proof behind it, which I reproduced with a different mutation. The hunt found
two ways the tests passed a wrong probe: a constant `age=0`, and a constant
`bytes=7` (every planned slice uses 7 bytes). It also found a missing `path=`
assertion and a comment that overclaimed. I fixed all four in the tests. Both
`orphan` tests are still red on their line-1 assertion.

**Overall Assessment**: Ready

## Mechanical check

`scripts/run-bats.sh tests/probes.bats`, foreground, before any edit:

```text
not ok 4 present unheld lock is orphan
#   `[ "${output%%$'\n'*}" = orphan ]' failed
not ok 6 quote and space in the lock path
#   `[ "${output%%$'\n'*}" = orphan ]' failed
bats: 4 passed, 2 failed
```

- `present unheld lock is orphan`: FAILED on an assertion. `status` is 0 and
  `stderr` is empty; the stub falls through its absent-lock guard and prints
  nothing, so line 1 is empty.
- `quote and space in the lock path`: FAILED on the same assertion, for the
  same reason.
- `unexpected flag reads as sandboxed`: PASSED. The behaviour it pins landed in
  slice 2's code review, so the mutation proof stands in for a red.
- No stub completion was needed: `probe_git_lock` exists, and nothing ERRORs.
- Self-quiet: `bash lib/matchers.sh < tests/probes.bats` gave no output and
  rc=1, before and after the fixes.

## Mutation proof, reproduced with a different mutation

The RED report used `[ "$flag" = true ]` → `[ "$flag" != false ]`, which reds
on the first (`""`) run at line 128. That leaves the `TRUE` half untested,
because bats stops at the first failure. My mutation targets that half: a
case-folding compare.

- Confirmed that `if [ "$flag" = true ]; then` occurs once
  (`command grep -c` → 1), then replaced it with
  `if [ "$(printf '%s' "$flag" | tr '[:upper:]' '[:lower:]')" = true ]; then`,
  using the Edit tool (exact-string replacement).
- Ran the suite:

  ```text
  not ok 5 unexpected flag reads as sandboxed
  # (in test file tests/probes.bats, line 135)
  #   `[ "${output%%$'\n'*}" = mask ]' failed
  bats: 3 passed, 3 failed
  ```

  Line 135 is the `TRUE` run's `mask` assertion, so the test reds on its own
  assertion there. The mutation leaves `""` sandboxed, so the first half
  passed. Together, the two mutations prove both halves.
- Restored it with the inverse replacement. To prove the restore:
  `command grep -c 'tr ' lib/probes.sh` → 0, and `git diff --quiet
  lib/probes.sh` succeeds. A rerun gave `bats: 4 passed, 2 failed`, the same
  two `orphan` failures as before.

## Issues Found

### Critical Issues

None.

### Major Issues

1. **A constant `age=` passed the orphan test**
   - Location: tests/probes.bats, `present unheld lock is orphan`
   - Problem: the only age check was `^age=[0-9]+$`. The lock is created
     moments before the run, so a probe printing `age=0` passes. So does one
     taking the age from the ctime or from the clock rather than the mtime.
     Slice 9 inherits this test's shape, so the BSD `stat -f %m` path would be
     just as unpinned.
   - Fix: backdate the lock with POSIX `touch -t 200001010000` and assert
     `age` > 86400 on both flag runs. The regex stays, so negative, empty or
     non-integer values still fail.
   - Checked on a scratch copy of the tree outside the repo, with a sketched
     orphan branch (`wc -c`, `date - stat -c %Y`). The sketch passes 6/6. A
     constant `age=0` reds at line 111 (`[ "$age" -gt 86400 ]`). An age from
     the ctime (`stat -c %Z`) reds at the same line. The pre-fix test passed
     both.
   - **Status**: FIXED

2. **A constant `bytes=7` passed every planned slice**
   - Location: tests/probes.bats, `quote and space in the lock path`; slice
     list 3, 6, 9
   - Problem: every present-lock slice writes 7 bytes (3, 6, 9, and the
     quote test as written). A probe hard-coding `bytes=7` passes the whole
     list: a "parallel values all equal" shape. The quote test also asserted
     neither `bytes=` nor `age=`, although its comment claimed it pinned
     quoting through `wc` and `stat`.
   - Fix: the quote test writes 12 bytes (`0123456789ab`), and now asserts
     `bytes=12` exactly and `^age=[0-9]+$`. That makes the value distinct, and
     it is the assertion that pins `wc` and `stat` quoting. Scratch check: a
     constant `bytes=7` reds at line 165 (`grep -qxF "bytes=12"`), while the
     sketch passes.
   - **Status**: FIXED

### Minor Issues

1. **The orphan test did not assert `path=`**
   - Location: tests/probes.bats, `present unheld lock is orphan`
   - Problem: the Interfaces contract lists `path=` among the key lines, and
     every earlier test asserts it. The orphan verdict is the one that carries
     a removal instruction (design.md D-14), so it needs the path most. Only
     the quote test pinned it, and only under flag `false`.
   - Fix: added `grep -qxF "path=$lock"` after both runs. `$2` is the
     unrelated `elsewhere` directory, so the line can only come from the error
     text.
   - **Status**: FIXED

2. **The quote test's comment overclaimed `fuser` quoting**
   - Location: tests/probes.bats, comment above `quote and space in the lock
     path`
   - Problem: the comment claimed "quoting through stat/wc/fuser". An unquoted
     `fuser $path` splits the path into two nonexistent names and finds no
     holder, and its stderr is captured by design. The test still reads
     `orphan`, so it cannot detect that.
   - Fix: the comment now says it pins the size and mtime reads, and states
     outright that the holder check's quoting is not pinned. It also explains
     the 12-byte count. The orphan test's comment "on this box fuser is
     present" now reads "the holder tool (lsof or fuser) is on the ordinary
     PATH", since a tracked test should not name one box.
   - **Status**: FIXED

## Wrong-reason hunt: answers to the dispatch

- **A probe that prints `orphan` for any present path without a holder
  check.** It passes slice 3, and slice 3 alone cannot exclude it, because no
  holder exists. That is acceptable here, because the list catches it
  elsewhere:
  - Slice 4 (`held`, `pid=` equal to the job's pid) reds a probe that never
    runs a holder check.
  - Slice 6 (`unknown` with no `lsof` or `fuser` on `PATH`) reds a probe
    that runs neither tool, or ignores whether it ran.

  Both are in the current runbook list.
- **Does the orphan test assert `path=`?** It did not; it does now, for both
  flags (Minor 1).
- **Could `bytes=7` come from something other than the lock?** Not from the
  text: the error line and the path are both far longer than 7 bytes. A
  constant 7 did pass the whole list; it no longer does (Major 2).
- **Is `age=` checked as a whole line, and would a negative or empty age
  fail?** Yes. `grep -qE '^age=[0-9]+$'` anchors each line: `age=-3`, `age=`
  and `age=1.5` fail. It also now fails a constant or ctime-based age in the
  orphan test (Major 1).
- **Does the quote-and-space fixture really put a quote and a space in the
  path the probe sees?** Yes. Inside double quotes the `'` is literal. A
  `mkdir` of the same form shows the directory as `it's\ here` under `ls -b`.
  The error text is built from `$lock` itself and reaches the probe
  unchanged on stdin through the here-string. The extractor's greedy capture
  to the last `.lock': ` keeps the embedded quote. The exact-line
  `path=$lock` match compares the full path.
- **Race, or dependence on a real `.git/index.lock`?** None:
  - Every fixture lives under the per-test `$BATS_TEST_TMPDIR`.
  - The error texts carry absolute paths, and `$2` is an unrelated
    `elsewhere` directory.
  - Nothing reads the repo's or the bats CWD's `.git`.
  - The lock file is closed before the probe runs, so no bats-side fd holds
    it.
- **Self-quiet:** no output, rc=1.
- **Line cap:** `wc -l tests/probes.bats` gives 167 after the fixes. Slice 3
  plus this review added 78 lines for three tests. At that rate the six
  remaining slices add about 150–210 lines, plus their review additions:
  - slice 4 needs a teardown kill;
  - slice 6 needs a curated `PATH` directory;
  - slice 8 needs a second error builder and two runs.

  That puts the file at about 320–380, close to the 400 cap. Proposed split
  point: slice 8. `probe_config_lock` is a separate function with its own
  error shape. Move `git_lock_error` and `run_probe` to
  `tests/helpers/probe-run.bash` (loaded by both files), and put slice 8 in
  `tests/config-lock-probe.bats`. Do it when slice 8's RED is written, or
  earlier if the file passes about 330 lines.

## Fixes Applied

- tests/probes.bats `present unheld lock is orphan`: added the `touch -t
  200001010000` backdate; `age` > 86400 after both runs (Major 1); `path=`
  after both runs (Minor 1); comment rewritten (Minor 2).
- tests/probes.bats `quote and space in the lock path`: the lock now holds 12
  bytes; added `bytes=12` and `^age=[0-9]+$` assertions (Major 2); comment
  corrected (Minor 2).
- lib/probes.sh: unchanged (mutation applied and reverted; `git diff --quiet`
  holds).

Post-fix run: `bats: 4 passed, 2 failed`. The failures are `present unheld
lock is orphan` (line 107) and `quote and space in the lock path` (line 163),
each on `[ "${output%%$'\n'*}" = orphan ]`, so both are still red on their own
assertion. `unexpected flag reads as sandboxed` and the slice 1–2 tests are
green.

## Requirements Validation

| Requirement | Status | Evidence |
|-------------|--------|----------|
| Slice 3: 7-byte unheld lock, flag `false` and `true` → `orphan`, `bytes=7`, `age=` integer ≥ 0 | Satisfied | `present unheld lock is orphan`, both runs |
| Slice 3: flag `""` and `TRUE` on an absent lock → `mask` and `path=` | Satisfied | `unexpected flag reads as sandboxed`; two mutations prove the two halves |
| Slice 3: `$BATS_TEST_TMPDIR/it's here/r` → `orphan`, full `path=` | Satisfied | `quote and space in the lock path` |
| FR-4 / A-3 key lines on `orphan` (`bytes=`, `age=`, `path=`) | Satisfied (tests) | now asserted in both orphan tests |

## Positive Observations

- Line 1 is read as `${output%%$'\n'*}`, never `${lines[0]}`, so a blank
  leading line cannot pass for the token.
- `--separate-stderr` with `[ -z "$stderr" ]` on every run pins the
  no-suppression rule. An unquoted `wc` or `stat` on the spaced path would
  already fail it.
- Running both flags inside the orphan test closes slice 2's "`gone` for every
  flag-`true` call" gap.
- The error text is still built from two fragments, and the self-quiet check
  holds.

## Recommendations

- Slice 4 (or a follow-on): holder-check quoting is unpinned. Only a held lock
  under a quoted, spaced path would detect an unquoted `lsof`/`fuser`.
- Slice 9 on Linux exercises the BSD `stat` stub only. BSD `wc -c` pads its
  count with leading spaces, and `bsd-stubs.bash` has no `wc` stub, so a probe
  that does not strip the padding passes here and prints `bytes=       7` on
  a Mac. Worth a `wc` stub in slice 9, or a note there.
