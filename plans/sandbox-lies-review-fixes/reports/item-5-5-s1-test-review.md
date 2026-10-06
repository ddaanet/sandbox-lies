# Review: Item 5.5 slice 1 — test review (RED)

- **Scope**: `tests/probes-lock-newline.bats` (new, staged) and
  `reports/item-5-5-s1-red.md`. `lib/probes.sh` read-only context.
- **Date**: 2026-10-06
- **Mode**: review + fix

## Summary

The four RED tests all failed on their own whole-output assertions against the
unchanged SUT, and their positive halves passed. They had four gaps. One of the
six `path=` print sites was unpinned: the character-device mask at
`lib/probes.sh` line 77. The held test had no blank-twin half. The git-lock
tests had no cwd-keyed-guard half. The suite had no `make_bsd_stubs` re-run. The
orphan age value was also unpinned. I fixed all five issues. The file now has
six tests, all red on their final assertion. I ran the suite against a scratch
copy of the SUT with the correct GREEN and eight wrong GREENs: every wrong GREEN
reds at least one test, and the correct one passes all six.

**Overall Assessment**: Ready

## Issues Found

### Critical Issues

None.

### Major Issues

1. **Character-device `path=` site unpinned**
   - Location: `lib/probes.sh:77`; no case reached it.
   - Problem: a GREEN that guards every site except the `[ -c ]` mask print
     passed all four tests. Before the fix, five of the six sites were pinned.
   - Fix: a new test, `git-lock character device`, symlinks each twin's
     `index.lock` to `/dev/null` and runs with flag `true`. Under that flag an
     absent lock reads `gone`, so `mask` can only come from line 77. `<g>`
     expects `mask` plus `path=`, and `<b>` expects `mask` alone.
   - **Status**: FIXED

2. **Held test had no blank-twin positive half**
   - Location: held test. The old version ran `mkdir` on `<g>` and never used
     it.
   - Problem: a guard at line 95 that also dropped paths holding blanks passed.
     The file header claims that every case catches that GREEN on `<g>`.
   - Fix: hold `<g>`'s lock first and expect `held`, `pid=`, `path=<g>/…`. Then
     `kill_holder`, remove `holder-ready` (otherwise `hold_lock` returns before
     the second open), and hold `<b>`'s lock.
   - **Status**: FIXED

3. **No `make_bsd_stubs` re-run (CLAUDE.md)**
   - Location: whole file.
   - Problem: the file loads `helpers/bsd-stubs` but never calls it.
   - Fix: the orphan body moved into `orphan_twins <PATH>`. A second test,
     `git-lock orphan under BSD sed, stat and wc`, runs it under
     `make_bsd_stubs "$bsd" sed stat wc`, and it reds on the same final
     assertion. The helper sits above the tests, as in `check-jq.bats` and
     `hook-cap.bats`. Below them, shellcheck raises SC2030/SC2031 on
     `$output`/`$status`, and the precommit gate counts info-level findings.
   - **Status**: FIXED

4. **No cwd-keyed-guard half in the git-lock tests**
   - Location: gone test.
   - Problem: only `probe_config_lock` was pinned against a guard keyed on the
     payload cwd. A guard keyed on `$2` in `probe_git_lock` passed. The runbook
     requires the guard in `_probe_lock_at`, which never receives the cwd. A
     GREEN that put it in the wrappers would still be plausible.
   - Fix: a middle half in the gone test runs from cwd `<b>` with text naming
     the absolute `<g>/.git/index.lock` and flag `true`. It expects `gone` plus
     `path=<g>/.git/index.lock`. The mutant run confirms that it, together with
     the config-lock half, kills the cwd-keyed GREEN. One such half per wrapper
     is enough, so the orphan, held and device tests do not need one.
   - **Status**: FIXED

### Minor Issues

1. **Orphan age and token unpinned**
   - Location: orphan test (now `orphan_twins`).
   - Problem: `age=` was read from the output's first `age=` line and compared
     against the output it came from, so any value passed, including a lone
     forged `age=99999`. The token likewise came from the output's own line 1,
     which made the `<g>` half tautological on line 1. Neither could pass a
     plausible GREEN on its own: the whole-output equality still kills a forged
     second line. But the age half asserted nothing.
   - Fix: both twins' `age=` values must lie within ±60s of
     `now - index_mtime(lock)`, with the mtime backdated to 2000. The token must
     be `orphan` or `unknown`. It is still read from `<g>`'s run so the case
     stays host-agnostic, as the RED author intended.
   - **Status**: FIXED

## Fixes Applied

- `tests/probes-lock-newline.bats`
  - The header names the five pinned sites and the vanish-gone residual.
  - New `orphan_twins` helper with the age-window and token-membership pins.
  - New BSD-stub orphan test and new character-device test.
  - The held test gains its `<g>` half; the gone test gains its absolute-`<g>`
    half.
  - The file is now 174 lines (under 400) and passes `shellcheck` (run together
    with `lib/` and `tests/helpers/`, as precommit runs it). `lib/matchers.sh`
    over the file is quiet (exit 1).
  - Re-staged with `git add` (nothing committed). In the foreground,
    `tests/docs.bats` and `tests/probes-config.bats` pass (13/13), and
    `scripts/check-line-limits.sh` passes.

## Per-test result (unchanged SUT, foreground)

| # | Test | Result | Failing line |
| - | ---- | ------ | ------------ |
| 1 | config-lock | not ok | `[ "$output" = mask ]` |
| 2 | git-lock orphan | not ok | `orphan_twins` final `<b>` equality |
| 3 | orphan under BSD sed, stat, wc | not ok | same line, under stubs |
| 4 | git-lock held | not ok | `held`/`pid=` equality on `<b>` |
| 5 | git-lock character device | not ok | `[ "$output" = mask ]` |
| 6 | git-lock gone | not ok | `[ "$output" = gone ]` |

Every positive half and the absolute-path halves ran before the failing line and
passed. No case errored, and none exited with 127.

## Mutant run (scratch copy of `lib/` + `tests/` under `$TMPDIR`, deleted)

| SUT variant | Reds |
| ----------- | ---- |
| Correct GREEN: newline guard, all six sites | none (6/6 ok) |
| Guard also drops blanks | 1–6 |
| Site 62 (gone, absent) unguarded | 6 |
| Site 64 (mask, absent) unguarded | 1 |
| Site 77 (character device) unguarded | 5 |
| Site 95 (held) unguarded | 4 |
| Site 155 (final orphan) unguarded | 2, 3 |
| Guard keyed on the payload cwd | 1, 6 |
| Newline path prints the outcome alone (drops bytes/age/pid) | 2–6 |
| Newline path prints the pathless `nopath` | 1–6 |

Site 120, the gone print after a vanish between the presence test and `stat`,
stays unpinned. Nothing triggers it deterministically, and the runbook records
it as a residual covered by the single guard.

## Held test across hosts

The holder tool on this host is `fuser`; `lsof` is not installed. The held case
needs some holder tool, as the sibling held cases in `tests/probes.bats` do. On
a host with neither tool, the outcome is `unknown` and the `<g>` half fails
before and after GREEN, the same exposure those siblings already have.
`teardown` calls `kill_holder`, which kills the second holder. The test kills
the first one itself.

## Requirements Validation

| Requirement | Status | Evidence |
| ----------- | ------ | -------- |
| FR-4 (A-3 contract: outcome stands, `path=` left out for a newline path) | Satisfied by the tests | Six cases, whole-output equality; the mutant table above |

## Positive Observations

- Whole-output equality throughout, so a forged line or a dropped key line
  fails, not only a missing `path=`.
- The blank twin `<g>` holds the review's exact forging shape (a clean middle
  `age=` line).
- Error text comes from the `git_lock_error`/`config_lock_error` fragment
  builders, so the file does not fire a detector.
