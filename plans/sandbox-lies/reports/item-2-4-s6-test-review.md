# Review: Item 2.4 / slice 6, test review (b)

**Scope**: the uncommitted changes to `tests/probes.bats`,
`tests/probes-edges.bats` and `tests/helpers/probes.bash`, plus the RED report
`item-2-4-s6-red.md`. `lib/probes.sh` was read for context and mutated only
in transient mutation runs. It is byte-identical to HEAD
(`git hash-object` = `4f71034…`, the same as `HEAD:lib/probes.sh`).
**Date**: 2026-09-25
**Mode**: review + fix

## Summary

The slice adds `no holder tool is unknown`, which is red on its own
assertion. It also adds four cases that pass because their behaviour landed
earlier, and each is mutation-proven. There is a new `tools_only_path`
helper. All five cases are sound. `lsof decides when present` had three
gaps:

- The recorder joined arguments with `echo`, so argument boundaries were
  lost.
- The path had no space, so a missing quote could not show.
- Nothing proved that `fuser` was never called.

Two stubs printed a stdout shape that psmisc does not produce. The
passed-through stderr was checked for a substring, but the test claims
"whole". The RED report also left the `<path>:ce` half of the stderr case
without a mutation. All of these are fixed and each fix is proven by
mutation.

**Overall Assessment**: Ready

## Mechanical check

`scripts/run-bats.sh tests/probes.bats tests/probes-edges.bats` ran in the
foreground: 16 passed, 1 failed. It was the same before and after the fixes,
and again after the last mutation was restored.

- `not ok 10 no holder tool is unknown`: it fails on
  `[ "${output%%$'\n'*}" = unknown ]` (probes.bats:293). This is an
  assertion, not an ERROR. The SUT prints `orphan`.
- Everything else passes. No other test ERRORs.

## Mutations of my own (each different from the RED report's)

Each run followed the same steps:

1. Replace a string that occurs exactly once (a python replace that asserts
   the count is 1).
2. Run the test alone (`-f`).
3. Restore by the inverse replacement.
4. `grep -cF` the mutant, which must give 0.
5. Check `git hash-object lib/probes.sh`, which must equal HEAD's blob.

| Case | Mutation (remove → insert) | Red on |
|---|---|---|
| lock vanishing during the holder check | `{ err=$(fuser "$path" 2>&1 >&3 3>&-); } 3>&1` → `err=''; fuser "$path"` (tool stderr not captured) | `[ -z "$stderr" ]` (edges:164) |
| unexpected stderr, foreign-line half | `if [ "$rest" != "$err" ] && [ -z "${rest//[[:alpha:]]/}" ]; then` → `if [ "$rest" != "$err" ]; then` (over-broad prefix tolerance) | stderr equality (edges:201) |
| unexpected stderr, `<path>:ce` half (not proven in RED) | `[ -z "${rest//[[:alpha:]]/}" ]` → `[ -z "$rest" ]` (exact `<path>:` only) | second `[ -z "$stderr" ]` (edges:213) |
| lsof decides: lsof first | `if command -v lsof >/dev/null; then` → `if false; then` | `grep -qxF "pid=42"` (edges:250) |
| lsof decides: quoting (new assertion) | `lsof -w -t "$path"` → `lsof -w -t $path` | args equality (edges:252) |
| lsof decides: fuser untouched (new assertion) | the lsof line → same `; fuser "$path" >/dev/null 2>&1` | `[ ! -e "$fuser_calls" ]` (edges:253) |
| dangling symlink quiet orphan | `\n    if [ ! -e "$path" ] && [ ! -L "$path" ]; then` → `\n    if [ ! -e "$path" ] ; then` (entry check drops `-L`) | `= orphan` (edges:271) |

A probe that answers `unknown` for every present lock with no pid would pass
the new test. I tested this with `printf 'orphan\n'` → `printf 'unknown\n'`
over the full two-file run. The new test goes green, and the probe is caught
by `present unheld lock is orphan` (probes.bats), the quote-and-space case,
`non-regular lock has no size`, `future mtime is age 0`,
`character device is mask` and `dangling symlink lock is a quiet orphan`.
So the discrimination comes from the orphan cases, which run on the host's
own `PATH`, where fuser is present.

## Wrong-reason hunting

- **Does the tools-only `PATH` really exclude lsof and fuser?** Yes.
  `tools_only_path` symlinks eight individual files, not directories, so
  `/usr/bin` (where `fuser` lives) never gets onto `PATH`. The stubs use
  `#!/bin/sh`, an absolute path. No helper defines a `fuser` or `lsof`
  function (grepped `tests/helpers/`). Bash's hash table is flushed on a
  temporary `PATH=` assignment for a function call. I measured this:
  `hash fuser; PATH=<empty dir> f` makes `command -v fuser` inside `f` find
  nothing. The vanishing and stderr cases would read `orphan` if the real
  `/usr/bin/fuser` were used, so they also prove that the stub is the one
  resolved. `command -v` in the helper could return a bare name for a
  function or an enabled builtin. None of the eight is either. If one were,
  the symlink would point at itself and the probe's call would fail with
  ELOOP onto stderr, which reds the test rather than passing it. The same
  `command -v` idiom is in `make_spy` and `vanished lock is gone`, so it is
  pattern-consistent and was not changed. The fail-safe direction holds for
  the new case: a leaked `fuser` reads `orphan` and keeps the test red. It
  cannot turn it green.
- **Stub stream shapes compared with the real tools.** I measured psmisc
  fuser on this box. When held, stdout is `     8` with no newline, and
  stderr is `<path>:\n`. Access letters go to stderr, appended after the
  colon (`<dir>:ccc\n` for a cwd holder), so the `<path>:ce` stub shape is
  real. A missing file, and also a dangling symlink, gives exit 1 with
  stderr `Specified filename <p> does not exist.`, which the vanishing stub
  reproduces exactly. The lsof stub prints `42\n43\n`, one pid per line as
  `lsof -t` does.
- **Stubs write only under `$BATS_TEST_TMPDIR`.** The lsof and fuser call
  logs and the tools dir are all under it. The vanishing stub's `rm -f`
  targets the lock operand only.
- **Self-quiet:** the matcher loop over all three changed files printed
  nothing and gave `rc=1` for each.
- **shellcheck** `-x` on the three files: clean.

## Issues Found

### Critical Issues

None.

### Major Issues

1. **`lsof decides` did not prove the argument vector or that fuser was
   not called**
   - Location: `tests/probes-edges.bats`, `lsof decides when present`
   - Problem: `echo "$@" >calls` compared with `"-w -t $lock"` joins
     arguments with spaces. A merged argument (`"-w -t $path"`) or an
     unquoted `$path` would pass, and the lock path had no space, so the
     quoting mutation stays green. The fuser decoy printed `99` but recorded
     nothing. A probe that calls both tools and keeps lsof's first pid still
     reads `pid=42`.
   - Fix: the repo dir is now `r r`. The lsof stub records
     `printf '%s\n' "$@"` and the test compares it with
     `printf '%s\n' -w -t "$lock"`. The fuser stub records its call to
     `$BATS_TEST_TMPDIR/fuser-calls`, and the test asserts
     `[ ! -e "$fuser_calls" ]`. That negative is paired with the positive
     lsof-args assertion on the same fixture. Both are proven by the
     mutations above.
   - **Status**: FIXED

### Minor Issues

1. **fuser stub stdout was not the psmisc shape**
   - Location: both stubs in `unexpected holder-tool stderr is passed
     through`, and the lsof case's decoy
   - Note: they printed `   77\n`. psmisc prints the pid space-padded with
     no trailing newline. The fix is `printf '     77'` (and `'     99'` with
     a `<path>:` stderr line for the decoy), and the case comment now names
     the shape.
   - **Status**: FIXED
2. **"Passed through whole" was asserted as a substring**
   - Location: same case, the first run
   - Note: `grep -qF "fuser: something odd"` would pass if the probe dropped
     the `<path>:` line and kept the foreign one. The assertion is now
     `[ "$stderr" = "$(printf '%s:\nfuser: something odd' "$lock")" ]`.
   - **Status**: FIXED
3. **RED report: the `<path>:ce` half had no mutation proof**
   - Location: `item-2-4-s6-red.md`, mutation 2
   - Note: that mutation reds only the foreign-line half (line 199 there).
     The mutation table above now proves the `:ce` half on its own.
   - **Status**: FIXED (proof supplied here; the RED report was left as
     written)
4. **After GREEN, some orphan cases become host-dependent**
   - Location: `present unheld lock is orphan` and the other orphan-expecting
     cases in both files, including `dangling symlink lock is a quiet orphan`
   - Note: these run on the host's own `PATH`. After slice 6's GREEN, a host
     with neither lsof nor fuser would read `unknown` there. Whether a
     dangling symlink, which nothing can hold, should read `orphan` without
     a tool is a GREEN decision. The same host dependency already exists in
     the `held` cases.
   - **Status**: OUT-OF-SCOPE. Those tests belong to other slices, and the
     implementation choice is GREEN's. For the orchestrator: the slice 6
     code review should decide it. The alternative is to give the orphan
     cases a stub fuser that answers "no holder".

## Fixes Applied

- `tests/probes-edges.bats`, `unexpected holder-tool stderr …`: comment
  names the psmisc shape. Both stubs now print `'     77'` with no newline.
  The first run asserts stderr equality in place of the substring grep.
- `tests/probes-edges.bats`, `lsof decides when present`: the repo path has a
  space, the lsof stub keeps a per-argument log compared exactly, and the
  fuser decoy is psmisc-shaped, records its calls and is asserted uncalled.
  The comment is updated.

## Line counts and placement of slices 7–9

After the fixes: `tests/probes.bats` has 295 lines, `tests/probes-edges.bats`
284, `tests/helpers/probes.bash` 37, against a cap of 400.

- Slice 7 (`relative path resolves against cwd`, about 18 lines) and slice 8
  (`config-lock reads its own error`, about 30 lines) are contract cases.
  Put them in `probes.bats`, which brings it to about 345.
- Slice 9's `BSD stat` case (about 22 lines) is also contract-shaped and
  fits in `probes.bats`, which brings it to about 367.
- Slice 9's `probe writes nothing` (three locks, a spy and a `TMPDIR` setup,
  about 50 lines) is mutation-proven, which matches the edge suite's header.
  Put it in `probes-edges.bats`, which brings it to about 335. If slice 8's
  config-lock error builder lands in `helpers/probes.bash`, it saves a few
  lines in `probes.bats`.
- Putting all of slice 9 in `probes.bats` would take it to about 415, over
  the cap.

## Positive Observations

- The new case is red on its own assertion against an inert SUT, and it
  checks `bytes=7`, so a bare `unknown` token without the size read would
  not pass.
- `tools_only_path` keeps the tool list in one place and bakes absolute
  paths in before the `PATH` restriction. `realrm` follows the
  `vanished lock is gone` precedent.
- The RED report's four mutations reproduce, and its `mktemp` finding
  (bats' own `run --separate-stderr`, test_functions.bash:367) is correct.
