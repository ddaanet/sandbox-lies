# Review: Item 2.4 / slice 10 — code review (d)

**Scope**: HEAD (`✨ Item 2.4/10 — an errored holder check reads unknown`),
`lib/probes.sh` only; then a whole-file read of `lib/probes.sh` with slices
1–7, 9 and 10 landed. Tests not edited.
**Date**: 2026-09-25
**Mode**: review + fix

## Summary

The slice's two-line change is correct. `_probe_holder_pids` returns 2 after
passing unexpected stderr on. The caller reads a pid before it reads the
status, so a named holder still reads `held`. The vanish rule still returns
0 quietly before the passthrough. The header comment claimed "printing
nothing" for the errored case, which is false when the tool printed a pid;
that is fixed. The whole-file read found three more things: the file put its
helpers ahead of the entry point, a residual comment that went stale when
slice 6 added the lsof stub test, and an "exception 1 of 2" with no matching
"2 of 2". All are fixed. The code is unchanged: the non-comment lines are
identical as a multiset before and after, and only their order moved.

**Overall Assessment**: Ready

## Dispatch checks

- **Pid plus return 2 reads `held`**: confirmed. The `holder_pid` test
  (`probe_git_lock`, the `if [ -n "$holder_pid" ]` block) returns `held`
  before `holder_status` is read at the outcome selection. The mutated-SUT
  run below proves a test pins this.
- **`pids=$(_probe_holder_pids "$path") || holder_status=$?` under
  `set -e`**: correct. An assignment whose value is a command substitution
  takes that substitution's exit status. The `||` puts the assignment in a
  list, so errexit does not fire on it, and `$?` on the right-hand side is
  the function's 2. `-ne 0` rather than `-eq 2` also reads a subshell dying
  some other way (for example an unset variable under `set -u`) as `unknown`
  rather than `orphan`, which is the safer direction.
- **Vanish beats errored**: confirmed. In `_probe_holder_pids` the
  `[ ! -e "$path" ] && return 0` guard sits before the `printf … >&2; return
  2` passthrough, so a lock that is gone after the check swallows the tool's
  complaint and returns 0. The probe's stat then reads `gone`. `lock
  vanishing during the holder check reads gone` pins it on empty stderr: move
  the guard below the passthrough, or delete it, and that assertion fails.
  A lock that was present at the check (errored, returns 2) and vanishes
  before the stat also reads `gone`, because the stat's vanish branch
  returns before the outcome selection. The tool's stderr has already been
  passed on by then. That is acceptable: it was unexpected when it was
  produced.

## Issues Found

### Critical Issues

None.

### Major Issues

None.

### Minor Issues

1. **"Returns 2, printing nothing" was false for the errored case**
   - Location: `lib/probes.sh`, the `_probe_holder_pids` header
   - Note: the tool's stdout goes straight out through fd 3, so any pids
     have already been printed when the stderr check returns 2. The same
     paragraph also said "only the pids decide", which slice 10 made untrue:
     stderr now decides between `unknown` and `orphan`. Reworded: the
     tool's exit is ignored and its pids and stderr decide. It returns 2 when
     no tool is on `PATH` (printing nothing), and when the stderr was
     unexpected, an exec failure's included. That stderr is passed on, any
     pids have already gone out, and a holder the tool named still reads
     `held`.
   - **Status**: FIXED

2. **Helpers came before the entry point**
   - Location: `lib/probes.sh`, the whole file
   - Note: the file read `_probe_lock_path`, `_probe_holder_pids`,
     `_probe_resolve_path`, `_probe_is_seconds`, then `probe_git_lock`. That
     breaks the "entry points first, definitions after their users" rule,
     and `lib/matchers.sh` follows the rule (`detect` first). The new order
     is `set -u`, `probe_git_lock`, `probe_config_lock`, then the helpers in
     order of first use (`_probe_lock_path`, `_probe_resolve_path`,
     `_probe_holder_pids`, `_probe_is_seconds`). The move was a mechanical
     line-range reorder, with the line multiset asserted equal. Bash
     resolves functions when they are called, and every call happens after
     the file is sourced, so behaviour does not change. `_probe_holder_pids`
     said "the stat below", which the move made wrong. It now says "the
     probe's stat".
   - **Status**: FIXED

3. **Stale lsof residual**
   - Location: `lib/probes.sh`, the end of the `_probe_holder_pids` header
   - Note: "the lsof branch runs in the suite only on hosts that have lsof"
     was written in slice 4's code review. Slice 6 then added `lsof decides
     when present` (`tests/probes-edges.bats`), which runs the branch against
     a stub on every host. Now reads: the suite runs the lsof branch against
     a stub; the real lsof, and so what `-w` keeps out, only on hosts that
     have it.
   - **Status**: FIXED

4. **"exception 1 of 2" had no matching "2 of 2"**
   - Location: `lib/probes.sh`, the mtime comment and the
     `_probe_holder_pids` header
   - Note: the item names two commented exceptions: the BSD `stat` attempt,
     and fuser's `<path>:` line, captured and matched. Only the first was
     labelled, so a reader who searched for the second would find nothing.
     The fuser bullet now carries `(no-stderr-suppression exception 2 of 2)`.
   - **Status**: FIXED

## Fixes Applied

- `lib/probes.sh` `_probe_holder_pids` header: the return-2 contract is
  reworded (pids already out, and still read `held`; stderr decides too;
  exec failure named); "the stat below" became "the probe's stat"; the lsof
  residual is corrected; the fuser bullet is labelled exception 2 of 2.
- `lib/probes.sh`: `probe_git_lock` and `probe_config_lock` moved directly
  below `set -u`, with the helpers after them in order of first use. No code
  line changed. Checked with a `grep -v` of comment and blank lines, sorted,
  and diffed against the pre-edit copy: identical.

## Mutated-SUT run

- Mutation (exact-string replacement, one occurrence): `if [ -n
  "$holder_pid" ]; then` → `if [ -n "$holder_pid" ] && [ "$holder_status"
  -eq 0 ]; then`. This is the plausible wrong implementation in which an
  errored check never reads `held`.
- `scripts/run-bats.sh tests/probes.bats tests/probes-edges.bats
  tests/probes-tools.bats` (foreground): **23 passed, 1 failed**. `not ok 17
  unexpected holder-tool stderr is passed through`, `tests/probes-edges.bats`
  line 213, `[ "${output%%$'\n'*}" = held ]` failed. The test that stayed
  green stayed green for the right reason: no other case combines a pid with
  unexpected stderr.
- Restored by inverse replacement. `grep -cF '] && [ "$holder_status" -eq 0
  ]; then' lib/probes.sh` → 0.

## Whole-file read, other observations (no change)

- 206 lines against the 400 cap.
- `probe_config_lock` is still the slice-8 stub, and `"${2-}"` is the open
  `$2` question. Both are out of scope and untouched.
- Self-quiet: `bash lib/matchers.sh < lib/probes.sh` → no output, rc=1.
- The only `2>/dev/null` is exception 1, the BSD `stat` attempt.

## Gate

`just precommit`, run in the foreground after all edits. Final line:
`precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line
limits, links, tests` (`scripts/run-bats.sh tests/`: 119 passed, 0 failed).

## For the list revision

No new test required. Every rule this review checked is already pinned.
Pid-over-errored is pinned (see the mutation above), and vanish-over-errored
is pinned by `lock vanishing during the holder check reads gone`'s
empty-stderr assertion. Not pinned, and low value: a lock present at an
errored check that vanishes before the stat. It reads `gone`, and the tool's
stderr has already been passed on.

## Requirements Validation

| Requirement | Status | Evidence |
|---|---|---|
| Slice 10: errored holder check → `unknown` | Satisfied | `_probe_holder_pids` `return 2`; outcome selection `-ne 0`; `errored holder check is unknown` green |
| Held still wins over errored | Satisfied | pid test before status test; mutation above |
| Vanish still wins over errored | Satisfied | guard before passthrough; `lock vanishing during the holder check reads gone` |
| No stderr suppression beyond the two exceptions | Satisfied | one `2>/dev/null`; both exceptions now labelled |
| Bash 3.2 portability | Satisfied | no constructs added |

## Positive Observations

- The GREEN kept the change to two lines and did not touch the pid parse.
- Using `-ne 0` rather than `-eq 2` makes any unexpected subshell failure
  read `unknown`, never `orphan`.
