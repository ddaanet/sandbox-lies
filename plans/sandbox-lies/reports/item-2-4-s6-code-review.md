# Review: Item 2.4 / slice 6, code review (d)

**Scope**: `lib/probes.sh` as changed by HEAD (`✨ Item 2.4/6 — no holder
tool reads unknown`): the `return 2` channel out of `_probe_holder_pids`, its
capture and the outcome selection in `probe_git_lock`, and the comments on
both. Tests were read for context and not edited.
**Date**: 2026-09-25
**Mode**: review + fix

## Summary

The slice is minimal and correct for the case it targets. With neither
`lsof` nor `fuser` on `PATH` the probe prints `unknown`, keeps `bytes=`,
`age=` and `path=`, and puts nothing on stderr. The status channel is sound
under the hook's own options (`hooks/annotate.sh` sets only `set -u`). It
was not sound under a caller running `set -e`: the bare `pids=$(...)`
assignment returned 2 and aborted the probe with no output. I fixed that
without changing behaviour, and tightened both comments. One real gap
remains and needs a test first, so it goes to the list revision: a holder
tool that is present but errors (an exec failure, or the tool erroring on
the path) still reads `orphan`.

**Overall Assessment**: Ready. The only open item is a major finding routed
to the list revision.

## Exit-status channel: what was measured

A scratch lock was used, with `PATH` restricted to the probe's own tools.

| Caller options | Before fix | After fix |
|---|---|---|
| `set -u` (hook) | `unknown`, rc 0 | `unknown`, rc 0 |
| `set -e`, no tool | **dies rc 2, no output** | `unknown`, rc 0 |
| `set -eo pipefail` + `inherit_errexit`, no tool | **dies rc 2** | `unknown`, rc 0 |
| `set -e` + `inherit_errexit`, fuser present, unheld | **dies rc 1** (fuser's exit 1 fails the `err=$(…)` assignment inside the function) | `orphan`, rc 0 |
| `set -e`, fuser present, unheld | `orphan`, rc 0 | `orphan`, rc 0 |

The fix is `pids=$(…) || holder_status=$?`. The `||` puts the whole
function body in an errexit-ignored context, and that holds even under
`inherit_errexit` (last row). So the tool's own exit cannot leak out either.
`pipefail` has no bearing: nothing in the diff is a pipeline.

**Can the function return 2 by another route?** No. Its exits are:

- the explicit `return 0`s;
- `return 2` (neither tool on `PATH`);
- the status of the final `printf '%s\n' "$err" >&2`.

A failed `printf` returns 1: measured with stderr closed, it gave
`write error: Bad file descriptor` and rc 1. Without errexit the tool's exit
never becomes the function's status, because every path ends in an explicit
`return` or that `printf`. An unbound variable inside the substitution exits
1 (measured). So 2 means only "no tool".

## Issues Found

### Critical Issues

None.

### Major Issues

1. **A caller under `set -e` dies on the no-tool path**
   - Location: `lib/probes.sh` `probe_git_lock`, the `_probe_holder_pids`
     capture.
   - Problem: `pids=$(_probe_holder_pids "$path")` followed by
     `holder_status=$?` is a failing simple command under errexit. The probe
     exits 2 before printing anything. That is a regression for such
     callers, since the function returned 0 before this slice. It is not
     live today: the hook is `set -u` only, and bats' `run` shields the
     suite. But Item 4.1 sources this library into the hook, and FR-3 needs
     the probe to degrade, not vanish.
   - Fix: `holder_status=0` in the `local` line, and
     `pids=$(_probe_holder_pids "$path") || holder_status=$?`, with a
     one-line comment giving the reason.
   - **Status**: FIXED. Verified with the table above.

2. **A holder check that errored reads `orphan`**
   - Location: `lib/probes.sh` `_probe_holder_pids`, the passthrough branch
     (`printf '%s\n' "$err" >&2`, the function's last line).
   - Problem: a tool is present but fails, the path is still there, and no
     pid comes out. The function prints the stderr and returns 0, so the
     probe reads `orphan`. That hands the lock the verdict carrying "Retry
     the command unsandboxed; a second identical failure means the lock
     predates this session". A-4 withholds that from an unverified lock.
     Reproduced with two stubs over an unheld 7-byte lock:
     - a `fuser` with a missing interpreter prints `cannot execute: required
       file not found` on stderr, and the probe outputs `orphan`,
       `bytes=7`, …;
     - an `lsof` that prints `status error on <path>: Permission denied`
       and exits 1 also outputs `orphan`.

     The stderr reaches only the hook's stderr, not the agent.
   - Why not fixed here: this adds behaviour, and no current test pins it.
     The one-line fix below survives every existing case (a mutation-style
     check: the passthrough test has a pid and exits `held` first). It also
     widens `unknown` beyond the `detectors.md` condition ("no holder tool on
     `PATH`"), and `docs/` is out of scope for this dispatch.
   - **Status**: DEFERRED to the list revision (the dispatch's route for a
     behaviour change that needs its own red test).

### Minor Issues

1. **`_probe_holder_pids` header: long, and it blurred two exits**
   - Location: `lib/probes.sh` lines 26–34 at HEAD.
   - Note: the text ran "only the pids decide, not the exit — except the
     neither-tool case…". That sentence mixed the tool's exit, which is
     ignored, with the function's own return status, which carries the
     signal. It also named the caller's outcomes. Rewritten in 6 lines
     instead of 9: the tool's exit is ignored and only the pids decide; the
     function returns 2, printing nothing, when neither tool is on `PATH`,
     because the empty output alone cannot tell that apart.
   - **Status**: FIXED

2. **Outcome-selection comment overclaimed**
   - Location: `probe_git_lock`, above `if [ "$holder_status" -eq 2 ]`.
   - Note: "any other status got here by actually checking and finding no
     holder" is false for major 2, where the check errored. It now reads
     "Otherwise a tool ran and named no holder", which is true in every
     case.
   - **Status**: FIXED

## Decision the test review handed on (its minor 4)

The orphan-expecting cases run on the host `PATH`, and after this slice they
read `unknown` on a host with neither tool. **Decision: no change.**

- Both target platforms ship a holder tool: psmisc `fuser` on this Linux box
  (`/usr/bin/fuser`), and `lsof`/`fuser` in the macOS base system.
- The `held` cases already carry the same dependency.
- On a host without either tool the failure is loud, a red `orphan`
  assertion, not a silent pass.

A dangling symlink with no tool reads `unknown` rather than `orphan`. That is
the safe direction, since the removal instruction is withheld, and the case
is too rare to need its own branch.

## Mutated-SUT run (once)

`[ "$holder_status" -eq 2 ]` → `[ "$holder_status" -ne 0 ]` over
`tests/probes.bats tests/probes-edges.bats` gave **17 passed, 0 failed**.
The mutant was restored by inverse replacement, and `grep -cF -- '-ne 0 ]'`
now gives 0.

The suite pins 2 → `unknown` and 0 → `orphan`, but not how the other
statuses map. Today the only other status is 1, from a failed stderr
`printf`. That is harmless now, and it becomes relevant if major 2 lands as
proposed below.

## For the list revision

**Proposed slice — `errored holder check is unknown`** (`probes-edges.bats`,
about 25 lines):

1. Set up a 7-byte unheld lock and `tools_only_path`.
2. Run 1: a `fuser` stub (`#!/bin/sh`) prints `fuser: cannot stat: Permission
   denied` on stderr, no pid, and exits 1. Expect:
   - line 1 `unknown`;
   - `bytes=7`;
   - stderr equal to that line (still passed through);
   - no `pid=`.
3. Run 2: replace the stub with an exec failure, a `fuser` whose shebang
   names a missing interpreter. Expect line 1 `unknown` and a non-empty
   stderr.
4. Pair both with the existing positives: `present unheld lock is orphan`
   (the tool ran quietly) and `unexpected holder-tool stderr is passed
   through` (error plus pid is still `held`).

- **Implementation (GREEN)**: in `_probe_holder_pids`, after the passthrough
  `printf`, `return 2`. Update the header sentence to "Returns 2 when
  neither tool is on `PATH` or the tool's stderr was unexpected".
  Consider `-ne 0` in the caller so that a failed stderr write also reads
  `unknown`.
- **Docs (orchestrator / phase-boundary corrector)**: the `detectors.md`
  `git-lock` table's `unknown` condition becomes "path present, no holder
  tool on `PATH` or the holder check errored". The `orphan` condition
  already says "holder check ran".
- **Mutation to prove it**: delete the new `return 2`. Run 1 reads `orphan`
  and goes red.

## Fixes Applied

- `lib/probes.sh` `probe_git_lock` `local` line: `holder_status=0`.
- `lib/probes.sh` capture: `pids=$(_probe_holder_pids "$path") ||
  holder_status=$?`, plus a one-line reason comment. This replaces the bare
  assignment followed by `holder_status=$?`.
- `lib/probes.sh` `_probe_holder_pids` header: the exit-status sentences are
  rewritten, 9 lines down to 6.
- `lib/probes.sh` outcome-selection comment: made accurate for every path
  that reaches it.

`lib/probes.sh` is now 163 lines (it was 165).

## Gate

- `scripts/run-bats.sh tests/probes.bats tests/probes-edges.bats`, after the
  fixes and after the mutant was restored: 17 passed, 0 failed.
- `just precommit`, final line: `precommit passed: plugin.json, hooks.json,
  shellcheck, bash -n, rumdl, line limits, links, tests` (bats: 112 passed, 0
  failed).
- Nothing was committed.

## Positive Observations

- `unknown` reuses the `orphan` tail unchanged, so the `bytes=`/`age=`
  omission rules and the gone-on-vanish read apply to it for free.
- The `return 2` fires before either tool could run, so it cannot disturb
  the `held`, stderr-tolerance or vanish branches.
- No new stderr suppression, and nothing that is not bash 3.2 compatible.
