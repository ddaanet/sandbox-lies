# Review: Item 4.1 slices 7-8 (+ carried stdin test) — test review

**Scope**: the uncommitted additions to `tests/hook-locks.bats` (three cases:
`every lock fixture yields its verdict`, `no probe without a verdict`,
`probe reads the result text on stdin`) against the RED report
`item-4-1-s7-red.md` and runbook Item 4.1 slices 7-8. Out: implementation, docs,
slice 9, Items 4.2/4.3. **Date**: 2026-09-25 **Mode**: review + fix

## Summary

All three cases are sound in shape and each reds on its own assertion under an
independent mutation. Three gaps found and fixed: the test file failed the
self-quiet gate (`tests/docs.bats` red), the sweep did not prove each run
reached its stub, and slice 8's negative had no positive pairing.

**Overall Assessment**: Ready

## Issues Found

### Critical Issues

1. **Test file fires `git-lock` — self-quiet gate red**
   - Location: `tests/hook-locks.bats`, stdin test, `stderr=` assignment
   - Problem: the success-half payload held git's index-lock line and its full
     follow-on sentence as literals, so the file itself fires the `git-lock`
     matcher. `bash lib/matchers.sh < tests/hook-locks.bats` printed `git-lock`;
     `bats tests/docs.bats` failed with `tests/hook-locks.bats: git-lock`. The
     RED report's full-suite run covered only `hook-locks.bats`, so the
     precommit gate would have refused the GREEN commit.
   - Fix: assemble the follow-on from two fragments (the same device
     `match_git_lock` uses), with a comment naming why.
   - **Status**: FIXED — matchers now exit 1 on the file; `docs.bats` green.

### Major Issues

1. **Sweep did not prove each run reached its stub**
   - Location: `every lock fixture yields its verdict`
   - Problem: the real `probe_git_lock`/`probe_config_lock` also answer `mask`
     for a lock path absent on this machine, so a sweep whose stubs were not the
     answering probe would pass while the real probe statted the fixtures' host
     paths — the case `stub_probe`'s own comment warns about. The sweep never
     read `$PROBE_CALLED` (and the second `stub_probe` call overwrote the
     first's). Demonstrated: appending a sentinel-less `probe_config_lock`
     override after the stubs left the sweep green.
   - Fix: keep both sentinels (`lock_called`, `config_called`), clear both
     before each run, and record a named miss when the run's own detector's
     sentinel is absent. Same override afterwards reds with
     `fire-configlock-{fetch,remote-add}.txt (flag absent|true): stub probe not called`
     (4 lines); override then removed.
   - **Status**: FIXED

2. **Slice 8 was a bare negative**
   - Location: `no probe without a verdict`
   - Problem: empty output and no recorded call also hold if the recording stub
     cannot record, or if the stubbed `detect` is not the one sourced and the
     fixture yields something the hook drops.
   - Fix: after the negative, append `verdict_fake` to the copied `verdicts.sh`
     and re-run the same payload: the recorded call must exist and
     `systemMessage` must equal the stub's human line. The pair differs only in
     the guard's trigger (verdict present or absent).
   - **Status**: FIXED

### Minor Issues

None.

## Check 1 — mechanical, with independent mutations

`bats tests/hook-locks.bats` (foreground) before fixes: 13/13 ok. Each mutation
below differs from the RED report's; each is an exact-string Edit, restored by
the inverse Edit.

| Test | Mutation (SUT) | Red on |
|---|---|---|
| sweep | `lib/matchers.sh` `match_config_lock`: regex suffix ` MUTANT` (config-lock stops firing) | final `[ -z "$misses" ]`, listing both `fire-configlock-*` fixtures at both flags, `got ''`; no `fire-lock-*` listed |
| slice 8 | `hooks/annotate.sh`: inserted a probe call ahead of the `declare -F "$fn"` gate, output discarded (probe before verdict gate) | `[ ! -f "$called" ]` — output stayed empty, so the sentinel alone caught it |
| stdin | `hooks/annotate.sh`: `(.error \| strings)` → `(.error \| strings), "MUTANT"` (extra line on the failure text) | the failure half's `[ "$(cat "$recorded")" = "$text" ]` — the half the RED report's mutation never reached; success half passed |

After the fixes, re-run: the slice 8 mutation reds at the same assertion; the
RED report's order swap on the success half reds at the join equality with the
fragment-built stderr (so the fragments still fire `git-lock`).

Restore proof: `grep -rc MUTANT hooks lib` → 0 in every file;
`git diff --quiet -- hooks lib` → clean; `git status --porcelain` shows only
`tests/hook-locks.bats` modified and the RED report untracked.

## Check 2 — wrong-reason hunting

- **Sweep coverage.** 7 fixtures: 5 `fire-lock-*` (add-commit, commit-amend,
  piped-tail, rebase-inline, restore), 2 `fire-configlock-*` (fetch,
  remote-add). Both globs are iterated. Payload shape follows Item 2.3's rule:
  first line `Exit code` → `failure_payload` (commit-amend, rebase-inline,
  restore, remote-add); otherwise `post_payload` stdout (add-commit, piped-tail,
  fetch). Flags `''` (absent) and `true`: 14 runs. Expected human line is
  per-family, so a swapped verdict reds.
- **Zero-iteration.** Cannot pass silently: an unmatched glob iterates once on
  the literal pattern and `text=$(cat "$f")` fails under bats' errexit (checked
  in a scratch bats file). A fixture that stops firing yields `got ''` as a
  named miss. `[ "$count" -gt 0 ]` is redundant given that, but it is
  `hook.bats`'s established sweep pattern — left.
- **Slice 8.** `stub_lib matchers.sh` appends to `$HOOK_COPY/lib/matchers.sh`,
  which `annotate.sh` sources via `$script_dir/../lib`, so `detect` prints
  `fake` in the copy the hook runs; the new positive half proves it (the call is
  only recorded when `detect` reported `fake`). A hook calling the probe before
  checking the verdict reds (mutation above).
- **Stdin test.** Pins both parts and their order: exact equality against
  stdout, newline, stderr with distinct non-empty parts (order swap reds); the
  failure half pins `error` verbatim (extra-line mutation reds).
  `[ -f "$recorded" ]` guards each half against a probe never called.

## Check 3 — self-quiet

Critical 1 above. After the fix: `lib/matchers.sh` on `tests/hook-locks.bats`
exits 1; on `item-4-1-s7-red.md` (committed with the slice) exits 1;
`bats tests/docs.bats` ok. This report describes the follow-on sentence without
quoting it.

## Fixes Applied

- `tests/hook-locks.bats` stdin test — follow-on sentence built from two
  fragments; comment names the self-quiet reason.
- `tests/hook-locks.bats` sweep — per-detector sentinels captured from
  `stub_probe`, cleared before each run, absence recorded as a named miss;
  comment extended with the reason.
- `tests/hook-locks.bats` slice 8 — positive half with `verdict_fake` defined:
  call recorded, `systemMessage` equals the stub's line.

## Final state

- `bats tests/hook-locks.bats`: 13/13 ok.
- `direnv exec . just precommit`: `bats: 147 passed, 0 failed`;
  `precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests`.
- `tests/hook-locks.bats`: 382 lines, under the 400 cap.

## Positive Observations

- Miss accumulation names every broken fixture/flag in one red.
- `$(cat …)` on both sides of the stdin comparison cancels the hook's added
  trailing newline symmetrically.
- The slice 8 fixture is a real lock fixture, so a stubbed `detect` that failed
  to take would surface as output.
