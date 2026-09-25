# Review: Item 2.4 / slice 9 — test review (b)

**Scope**: `tests/helpers/bsd-stubs.bash` (new `stat`, `wc` stubs),
`tests/probes.bats` (`BSD stat`), `tests/probes-edges.bats` (`probe writes
nothing` and its setup/teardown), `tests/helpers/probes.bash` (`hold_lock`
moved), `plans/sandbox-lies/reports/item-2-4-s9-red.md`. `lib/probes.sh`
touched only by temporary mutations, each restored and grep-proven (`git diff
--stat lib/probes.sh` empty at the end).
**Date**: 2026-09-25
**Mode**: review + fix

## Summary

The RED is genuine: `BSD stat` fails on its own assertion (`[ -z "$stderr" ]`,
the stub's refusal of `stat -c` reaching stderr), and everything else passes.
The first version of the `stat` stub handed every BSD form other than the
exact `-f %m <files>` to GNU stat. GNU stat's `-f` means filesystem mode, so
those forms came back with the wrong meaning. The `BSD stat` fixture also let
an age read from the atime land inside the window. `probe writes nothing`
caught only mktemp and `$TMPDIR` writes, which is less than its name claims.
All three are fixed, along with one `wc` padding detail and a comment that
would have gone stale.

**Overall Assessment**: Ready

## Mechanical check

- `scripts/run-bats.sh tests/probes.bats tests/probes-edges.bats` (foreground),
  before and after fixes: `19 passed, 1 failed`. The failure is `BSD stat` at
  `tests/probes.bats` line 316, `[ -z "$stderr" ]` (an assertion failure, not
  an ERROR).
- Full suite `scripts/run-bats.sh tests/` after fixes: `114 passed, 1 failed`
  (only `BSD stat`). The shared `bsd-stubs.bash` change broke no other suite.
- `shellcheck` on `lib/probes.sh` and the four changed test files: exit 0.
- Self-quiet (`bash lib/matchers.sh < <file>`): no output, rc=1 for all four
  changed files.
- Line counts: `bsd-stubs.bash` 156, `probes.bats` 325, `probes-edges.bats`
  358. All are under the 400-line cap.

## Mutation proofs (my own, different from the RED report's)

The same procedure applied to each: one exact-string replacement of a string
that occurs once in `lib/probes.sh` (checked with `command grep -cF` → 1),
then a run of `scripts/run-bats.sh tests/probes-edges.bats -f "probe writes
nothing"`, then the inverse replacement. After each restore, a grep count of
the injected text was 0 and `git diff --stat lib/probes.sh` was empty.

1. **Held branch only, silent mktemp.** `printf '%s\n' held "pid=$holder_pid"
   "path=$path"` → `mktemp >/dev/null 2>&1 || :; printf …`. Red at line 356,
   `[ ! -e "$calls" ]`, which is the held run's spy assertion. The mutant's
   stderr is silenced, so only the spy could catch it. This shows a write
   confined to the held branch is caught, and caught by the spy, not the
   stderr check.
2. **Orphan branch, file beside the lock** (checks the assertion added below).
   `printf '%s\n' "$outcome"` → `: >"$path.probe"; printf …`. Red at line
   344, the orphan run's tree-listing assertion.
3. **Shared path, relative write into the cwd** (checks the added `cd`).
   `text=$(cat)` → `text=$(cat); : >probe-scratch`. Red at line 331, the mask
   run's tree-listing assertion. No stray file was left in the repo.

The code review, or later, can check this forward:

4. **The BSD path goes green, and the padding strip is pinned.** I
   temporarily replaced `stat -c %Y "$path"` with `stat -f %m "$path"`, a
   stand-in for a BSD-path implementation. `BSD stat` passed (1/1). So the
   stubs do not fail correct code, and the new fixture is satisfiable. With
   `bytes=$(wc -c <"$path" | tr -d '[:space:]')` also replaced by
   `bytes=$(wc -c <"$path")`, it went red at line 318 (`grep -qxF "bytes=7"`).
   That is the deferred mutation from the RED report, now run. Both edits
   were reverted: grep count 0, empty diff.

## Issues Found

### Major Issues

1. **The `stat` stub handed BSD forms to GNU stat, where `-f` means
   filesystem mode**
   - Location: `tests/helpers/bsd-stubs.bash` `_bsd_stub_stat`
   - Problem: Only the exact `-f %m <files>` shape (`$1=-f`, `$2=%m`) was
     emulated. BSD accepts `-f%m`, `-L -f %m` and `-f %m` with no operand
     (stdin), but the stub passed each of them to GNU `stat`. There `-f` is
     filesystem mode, which prints filesystem info and `cannot read file
     system information for '%m'`, rc 1. That is stricter than BSD and fails
     correct code, with a confusing message. Other BSD formats (`-f %a`) and
     options (`-x`, `-q`, `-t`) had the same problem, silently getting GNU's
     different meanings. The refusal was also a bare `case -c*` scan, so a
     bundled `-Lc` got through to GNU (more lenient than BSD).
   - Fix: The stub now parses the macOS option set with `getopts
     ':FLlnqrsxf:t:'`. An illegal or missing-argument option prints BSD's
     `stat: illegal option -- X` plus BSD's usage line, exit 1. This covers
     `-c`, bundled `-Lc`, `--format`, `--printf`. `-f %m` (attached or not,
     with or without `-L`, several operands, no operand meaning stdin) is
     served from the real `stat [-L] -c %Y --`. Any other BSD option or
     format exits 2 with `make_bsd_stubs stat: only -f %m is emulated (got
     …)` instead of reaching GNU. The residual is stated in the comment: a
     missing file gets GNU's wording, not BSD's `stat: <f>: stat: No such
     file or directory`. The exit status (1) matches, and the probe keys on
     status and `[ -e ]`, not wording. I checked every form directly: `-c
     %Y`, `--format=%Y`, `-Lc %Y` → refusal rc 1; `-f %a`, `-x`, `-q -f %m` →
     rc 2; `-f %m`, `-f%m a b`, `-L -f %m link`, stdin → mtimes rc 0; missing
     file → rc 1.
   - **Status**: FIXED

2. **`BSD stat` let an atime-based age pass**
   - Location: `tests/probes.bats` `BSD stat`
   - Problem: `touch -t` backdates atime and mtime together. An age computed
     from the atime would land inside the ±60 s window, so the comment's
     claim that "a value derived from something other than the backdated
     mtime cannot land within a minute of it" was false for atime. ctime was
     already safe, because touch sets it to now.
   - Fix: `touch -m -t 200001010000`. Only the mtime is backdated, and atime
     and ctime stay at the write, decades outside the window. The comment was
     rewritten to say this.
   - **Status**: FIXED

3. **`probe writes nothing` claimed more than it checked**
   - Location: `tests/probes-edges.bats` `probe writes nothing`
   - Problem: The spy and the missing `$TMPDIR` catch only mktemp and
     `$TMPDIR`-relative writes. A file written beside the lock (`$path.tmp`)
     or into the working directory passed. The probe also ran from bats's own
     cwd, so a relative write would have landed in the repo checkout.
   - Fix: The test `cd`s into the payload cwd. Before each of the three runs
     it records `find "$repo" "$cwd" | LC_ALL=C sort`, and after each run it
     asserts the listing is unchanged. The `$BATS_TEST_TMPDIR` root is
     deliberately not listed, because bats' `run --separate-stderr` creates
     its temp file there. Mutations 2 and 3 above show the new assertions
     going red.
   - **Status**: FIXED

### Minor Issues

1. **`wc` stub padding was one column off BSD for large counts, and it
   swallowed a real-wc failure**
   - Location: `tests/helpers/bsd-stubs.bash` `_bsd_stub_wc`
   - Note: BSD prints `" %7ju"`: a space, then width 7. `%8s` gives the same
     output below 10^7 but drops the leading space above it. `n=$(wc -c)`
     followed by an unconditional `exit 0` hid a failing real wc. Fixed:
     `printf ' %7s\n'`, and `n=$("$2" -c) || exit`. Checked with `od -c`:
     seven spaces then `7\n`. The remaining leniency is stated in the comment:
     every other form (`wc -c <file-operand>`, `wc -l`) execs GNU unpadded,
     while BSD pads those too.
   - **Status**: FIXED

2. **A comment that would go stale after GREEN**
   - Location: `tests/probes.bats`, the comment above `BSD stat`
   - Note: "(the mtime read must fall back to `stat -f %m`, not written yet)"
     describes the pre-GREEN state, and "fall back" presupposes GNU-first
     while the runbook says BSD-first. It now reads "must use `stat -f %m`".
   - **Status**: FIXED

## Stub fidelity notes (checked, no change needed)

- Neither macOS nor FreeBSD stat has `-c`. FreeBSD's synopsis adds only `-H`,
  and the stub uses the macOS option set because macOS is the target. BSD
  `usage()` exits 1 after getopt's `illegal option -- X`, and the stub now
  matches both lines and the status.
- `%m` in BSD `-f` is `st_mtime` as decimal seconds, the same value GNU
  `-c %Y` prints. Without `-L` both read the link itself (lstat), which
  matches the probe's no-`-L` call.
- For stdin-only `wc -c`, GNU prints bare digits, which is the leniency the
  stub exists to remove.

## Wrong-reason hunting

- An age from something other than stat: ctime is excluded (now), and atime
  is now excluded by `touch -m`. `date -r "$path" +%s` would pass, but it
  reads the same mtime and exists on macOS and FreeBSD, so it would be a
  correct BSD implementation. Choosing `stat` over it is the item text's
  mandate, for the code review to check, not something this test should pin.
- The window comes from the fixture's own `real_mtime`, read with the real
  stat before the stub goes on `PATH`. `now` is taken after the probe runs,
  so the probe's age is ≤ `now - real_mtime` and well inside +60.
- `probe writes nothing` covers all three branches: mask, orphan, held. The
  held run asserts `held`, so the holder really is seen. Mutation 1 shows a
  write in the held branch alone is caught.
- Implementation-side, for the code review, not a test finding: the runbook's
  "BSD-first mtime read keeps stderr out of the value and checks it is all
  digits before the arithmetic". On this box GNU `stat -f %m file` exits 1,
  so a BSD-first read falls through to `-c %Y` by status. The digits guard is
  not reachable from these fixtures.

## Fixes Applied

- `tests/helpers/bsd-stubs.bash` `_bsd_stub_stat` — rewritten around getopts:
  BSD refusal plus usage line, exit 1; `-f %m` served in every BSD spelling;
  anything else not emulated exits 2 instead of reaching GNU `stat -f`.
  Comment rewritten, with the residual stated.
- `tests/helpers/bsd-stubs.bash` `_bsd_stub_wc` — `' %7s\n'` padding, real-wc
  failure passed through, residual leniency stated.
- `tests/probes.bats` `BSD stat` — `touch -m -t`; comment updated (atime and
  ctime discrimination, "not written yet" removed).
- `tests/probes-edges.bats` `probe writes nothing` — `cd "$cwd"`, and a
  before/after tree listing of the repo and cwd around each of the three runs.
  Header comment extended.

## Requirements Validation

| Requirement | Status | Evidence |
|-------------|--------|----------|
| Item text: a `stat` stub refusing `-c` as BSD does, serving `-f %m` from the real `stat -c %Y` | Satisfied | `_bsd_stub_stat`; forms checked directly (above) |
| Slice 9 `BSD stat`: `orphan`, `bytes=7`, `age=` within a minute of now minus the backdated mtime, under `make_bsd_stubs stat wc` | Satisfied (red on assertion as intended) | `tests/probes.bats` `BSD stat`; mutation 4 shows it goes green for a BSD-path SUT and pins the strip |
| Slice 9 `probe writes nothing`: mktemp spy, missing `TMPDIR`, held/unheld/absent, empty stderr, no spy call | Satisfied | `tests/probes-edges.bats`; mutations 1–3 |
| NFR-2 (portability) | Satisfied for the test side | stubs now make the GNU `-c` and unpadded-`wc` forms fail on Linux |

## Positive Observations

- `real_mtime` is read before the stub goes on `PATH`, which turns slice 3's
  loose lower bound into an exact window.
- `probe writes nothing` isolates the env override in a `bash -c` subprocess,
  so bats' own mktemp use in `run --separate-stderr` does not trip the spy.
- Moving `hold_lock` into the shared helper, with a guarded per-file
  teardown, keeps the held-job cleanup local to each suite.
