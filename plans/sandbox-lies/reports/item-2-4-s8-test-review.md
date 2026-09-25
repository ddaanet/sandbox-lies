# Test review: Item 2.4 / slice 8: config-lock and `$2` base resolution

**Scope**: `tests/probes-config.bats` (new), `tests/helpers/probes.bash`
(`config_lock_error` added), RED report `item-2-4-s8-red.md`. `lib/probes.sh`
was touched only for mutation runs and was restored each time
(`git diff --stat lib/probes.sh` is empty).
**Date**: 2026-09-25
**Mode**: review + fix (TDD test review)
**Item text**: current runbook Item 2.4 and slice 8. A relative path resolves
against the nearest ancestor of `$2`, `$2` itself included, that holds `.git`,
and falls back to `$2`. A missing or empty `$2` falls back to the probe's
working directory, never `/`. The brief's copy of this text is stale.

## Summary

The RED report is accurate. Its three new-behaviour tests fail on their
assertions, and its two green-on-arrival tests are non-vacuous. I proved each
of those two again with a different mutation. The review found three gaps
where a wrong implementation would pass:

- a probe that hard-codes `config.lock`
- a probe walking to the outermost `.git`, or starting its walk at `$2`'s
  parent
- a probe that reads the other probe's lock line

I added one sharp case for each. After the fixes, 6 tests fail on their
assertions (the 3 original plus the 3 added) and the other 26 pass.

**Overall Assessment**: Ready (for GREEN)

## Mechanical check

`scripts/run-bats.sh tests/probes.bats tests/probes-edges.bats
tests/probes-tools.bats tests/probes-config.bats` was run in the foreground.
Before the fixes the result matched the RED report: 26 passed, 3 failed.
Each failure is on an assertion:

- `config-lock reads its own error`: line 31, `= mask`. The stub
  `probe_config_lock` is `cat >/dev/null`.
- `config-lock from a subdirectory`: `= orphan`.
- `missing or empty cwd uses the working directory`: `= orphan`. The empty
  `$2` join produces `/.git/index.lock`.

None of these failed with an ERROR. The stub is complete: `probe_config_lock`
exists and is inert.

### Mutation proofs repeated with different mutations

Each mutation was an exact-string replacement of a string that occurs once
in `lib/probes.sh`. Each was restored by the inverse replacement and
grep-proved.

1. **`pathless text never names the base`.** The RED report's mutation
   dropped the `| ''` arm. Mine joins the empty path onto the process cwd
   instead: `/* | '') printf '%s\n' "$1" ;;` becomes `... "${1:-$PWD}" ;;`.
   - Result: red at line 120, `!= held`. The false-flag run reads `held`,
     because fuser names the bats shell sitting in the directory.
   - Restore check: `grep -c '"${1:-$PWD}"'` returns 0.
2. **`no .git above cwd keeps cwd`.** The RED report's mutation dropped the
   `$2` join. Mine falls back to the process cwd instead of `$2`:
   `*) printf '%s/%s\n' "$2" "$1" ;;` becomes `... "$PWD" "$1" ;;`.
   - Result: red at line 201 on the `path=$lock` grep. The process cwd is
     bats' own directory, the repo root.
   - Restore check: `grep -c '$PWD'` returns 0, and the `"$2" "$1"` line is
     back at line 147.

## Issues Found

### Major Issues

1. **Hard-coding `config.lock` passes the config-lock test**
   - Location: `tests/probes-config.bats`, `config-lock reads its own error`
   - Problem: the only named file in that test is `<repo>/.git/config`. A
     probe that rebuilds the lock as `dirname(named)/config.lock` produces the
     same path and passes. Git names other files: from a linked worktree it
     prints an absolute `<main>/.git/worktrees/<wt>/config.worktree`. I
     checked this against real git in a scratch linked worktree. It printed
     `.../main/.git/worktrees/wt/config.worktree` for `config --worktree` and
     an absolute `.../main/.git/config` for the common config. From a
     subdirectory of the main worktree it printed the relative
     `.git/config`, which confirms the item's premise. None of the probes
     split on whitespace in this fixture either.
   - Fix: added `config-lock appends .lock to the named file`. The fixture is
     the linked-worktree `config.worktree` shape under
     `$BATS_TEST_TMPDIR/it's here`. With the lock present, the probe must
     print `orphan`, `bytes=7` and `path=<...>/config.worktree.lock`, with
     empty stderr.
   - **Status**: FIXED. The test is red on `= orphan` at line 61.
2. **Nothing pins the nearest `.git` or counts `$2` itself**
   - Location: `config-lock from a subdirectory`
   - Problem: the fixture has one `.git`, one level above `$2`. That test
     still passes for each of these wrong walks:
     - walking to the outermost `.git`
     - taking a single `dirname` step
     - starting the walk at `$2`'s parent
   - Fix: added `config-lock resolves at the nearest .git`. It nests
     `outer/.git` and `outer/inner/.git`. The inner lock is present and the
     outer lock is absent, so the outermost walk reads `mask` with the outer
     path. There are two runs:
     - `$2` = `inner/a/b`: two levels down, which catches a single step.
     - `$2` = `inner`: catches a walk that starts at the parent.

     Both runs must print `orphan` and `path=inner/.git/config.lock`.
   - **Status**: FIXED. The test is red on `= orphan` at line 170.
3. **Each probe's own-line rule is untested**
   - Location: `config-lock reads its own error`, which gets config text only
   - Problem: the following implementations pass every case:
     - a shared extractor that accepts either shape
     - a `probe_config_lock` that falls back to the git-lock extractor
     - a `probe_git_lock` that takes the first lock line of any shape
   - Fix: added `each probe reads only its own lock line`. Its fixture
     always puts the decoy line first, and the lock that line names is
     present where the probe's own lock is absent. It has three runs:
     - `probe_git_lock` gets the config line, then the git line: `mask`,
       `path=<index.lock>`.
     - `probe_config_lock` gets the git line, then the config line: `mask`,
       `path=<config.lock>`.
     - `probe_config_lock` gets git-lock text alone, with `index.lock`
       present: neither `orphan` nor `held`, and no `path=<index.lock>`.
       This negative is paired with the positive before it and differs only
       in the config line. The pathless outcome itself stays open.
   - **Status**: FIXED. The test is red at line 93 (`= mask`), which is the
     `probe_config_lock` direction. The `probe_git_lock` direction passes on
     arrival and is mutation-proven:
     - Mutation: `LC_ALL=C sed -n "s/` becomes
       `LC_ALL=C sed -n -e "s/.*lock config file \(.*\): File.*/\1.lock/p" -e "s/`,
       a combined extractor.
     - Result: red at line 83, `= mask`.
     - Restore check: `grep -c 'lock config file' lib/probes.sh` returns 0.

### Minor Issues

1. **Stale helper header**
   - Location: `tests/helpers/probes.bash:1-3`
   - Note: the header named three suites and "probe_git_lock cases" only.
     It now names `probes-config.bats` and both error builders.
   - **Status**: FIXED

## Wrong-reason hunt: cases checked and found sound

- **`no .git above cwd keeps cwd`: the ancestor assertion works.** In a
  scratch bats file, a `[ ! -e ]` inside the `while` body failed the test at
  `/Users/david/code/sandbox-lies/.git`, so errexit applies in the loop body.
  The loop checks `/.git` as well. The test fails for three wrong fallbacks:
  - falling back to the bats cwd: the repo root, which has a real `.git`
    (mutation 2 above)
  - falling back to `/`
  - dropping the `$2` join (the RED report's mutation)
- **`missing or empty cwd uses the working directory`: the probe's working
  directory is set explicitly.** The test runs `cd "$repo"` before `run`, and
  `run` inherits it. `path=` must be the absolute `$repo/.git/index.lock`.
  That fails for each of these fallbacks:
  - `/`
  - `$HOME`
  - `.`, whose path stays relative
  - the bats cwd, captured when `setup()` sources the library before the
    `cd`, which gives the repo root
  - `$BATS_TEST_TMPDIR`
  - Both `$2` absent and `$2` = `""` are exercised.
- **`pathless text never names the base`.** The test's `cd` makes the process
  cwd equal `$2`, so both join targets are holdable. Mutation 1 and the RED
  report's mutation both turn it red.
- **`config_lock_error`.** It builds the line from two fragments, and no
  source line starts with git's text. The line carries no quotes and no
  `.lock` suffix, which matches the `fire-configlock-remote-add` fixture's
  first line.

Not pinned (left open, not a finding): a relative path with a missing `$2`
is not tested for walking up from the working directory. The `$repo` fixture
holds `.git` itself. The item text does not say whether the walk applies
after that fallback.

## Fixes Applied

- `tests/probes-config.bats` added three tests:
  - `config-lock appends .lock to the named file`
  - `each probe reads only its own lock line`
  - `config-lock resolves at the nearest .git`

  The file is now 228 lines.
- `tests/helpers/probes.bash:1-3`: header updated.

## Final run

`scripts/run-bats.sh tests/probes.bats tests/probes-edges.bats
tests/probes-tools.bats tests/probes-config.bats`, run in the foreground:
**26 passed, 6 failed**. Every failure is an assertion on line 1 of the
output:

| Test | Line | Failed assertion |
|------|------|------------------|
| 25 `config-lock reads its own error` | 31 | `= mask` |
| 26 `config-lock appends .lock to the named file` | 61 | `= orphan` |
| 27 `each probe reads only its own lock line` | 93 | `= mask` |
| 29 `config-lock from a subdirectory` | 150 | `= orphan` |
| 30 `config-lock resolves at the nearest .git` | 170 | `= orphan` |
| 32 `missing or empty cwd uses the working directory` | 219 | `= orphan` |

All 22 cases from the earlier suites pass. So do `pathless text never names
the base` and `no .git above cwd keeps cwd`.

## Checks passed

- `lib/probes.sh` is unchanged: `git diff --stat` is empty.
- Self-quiet: `bash lib/matchers.sh <` prints nothing with rc=1, for both
  `tests/probes-config.bats` and `tests/helpers/probes.bash`.
- shellcheck: the only notice is SC1091 (info) on the `source` line, which
  every probes suite carries.
- Line counts are under the cap: `tests/probes-config.bats` is 228.
- `docs/design.md` was not touched, and nothing was committed.

## Requirements Validation

| Requirement | Status | Evidence |
|-------------|--------|----------|
| FR-4 (probe contract, config-lock path) | Covered by red tests | tests 25–27, 29, 30 |
| Item 2.4 path-base rule (nearest `.git`, then `$2`, then the working directory) | Covered | tests 29, 30, 31, 32 |
| NFR-2 (portability, whitespace-safe paths) | Covered for config-lock | test 26 uses a quoted, spaced path |
