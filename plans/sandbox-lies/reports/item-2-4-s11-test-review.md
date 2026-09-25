# Test review: Item 2.4 / slice 11 (closing follow-up)

**Scope**: the three new cases in `tests/probes-config.bats` and the move of
`run_probe_bounded` into `tests/helpers/probes.bash`, together with its one
consequence in `tests/probes-edges.bats`, where the old copy was deleted.
`lib/probes.sh` was touched only for mutations. It ends byte-identical to
HEAD.
**Date**: 2026-09-25
**Mode**: review + fix (TDD test review)

## Summary

All three cases catch what they claim to catch. Each went red on its own
assertion under a mutation I wrote myself, different from the RED report's.
The fixtures match the runbook's slice text. The problems were in how the
helper was moved:

- `tests/probes-edges.bats` kept its own copy of `run_probe_bounded`. Its
  later definition overrode the shared one, so two copies existed and the
  helper's claim to be "shared by" that file was false.
- An unrelated blank comment line was dropped from `hold_lock`.
- The timeout branch's `kill` had no errexit guard.
- The new test comments contained build-progress narration.

All of these are fixed. The suites are green.

**Overall Assessment**: Ready

## Mechanical checks

- Four-file probe suite before fixes: `bats: 35 passed, 0 failed`.
- My own mutations: each one is an exact-string replacement of a string that
  occurs once in `lib/probes.sh`. After each run it was restored by the
  inverse replacement, the restore was checked with a grep count, and
  `git diff --quiet lib/probes.sh` passed.

  | Test | Mutation (different from the RED report's) | Red on |
  |---|---|---|
  | `relative cwd terminates at the working directory` | `*) dir="$PWD/$dir" ;;` → `*) dir="./$dir" ;;` (relative base kept relative) | line 255 `[ "$status" -eq 0 ]` (status 124 from the bound), 1 of 11 failed |
  | `a .git file is walked past` | `if [ -d "$dir/.git" ]; then` → `if [ -d "$dir/.git" ] \|\| [ -f "$dir/.git" ]; then` | line 283 `[ "${output%%$'\n'*}" = orphan ]`, 1 of 35 failed |
  | `trailing slash on cwd` | `"${base%/}"` → `"${base%//}"` (strips only a doubled slash) | line 299 `grep -qxF "path=$lock"`, 1 of 35 failed |

- Hang guard: under mutation 1, the whole `tests/probes-config.bats` run took
  6 s of wall time. After the run, `ps -eo pid,args` showed no process
  mentioning bats, probes or the lock. After the helper was consolidated, I
  also checked the edges case the helper was written for. I mutated
  `if [ -f "$path" ] && [ -r "$path" ]; then` to `if [ -r "$path" ]; then`,
  which makes the FIFO read block. `non-regular lock has no size` failed
  within the bound (line 79, status 124, 6 s wall time), no stray process was
  left, and the mutation was restored and grep-proven.
- The bound uses bash builtins (`set -m`, `kill -0`, `kill -- -pgid`, `wait`)
  plus `sleep 0.1`. Fractional `sleep` is accepted by both GNU and BSD/macOS
  `sleep`. There is no GNU `timeout`.

## Wrong-reason hunting

- **Relative cwd.** The `.git`-free precheck walks every ancestor of `$w` up
  to `/` and asserts `/.git` separately. I ran a scratch bats file to confirm
  that a failing `[ ]` inside a `while` body fails the test. Both `rel` and
  `rel/x` are exercised, each with its own exact `path=`. `rel` has no slash
  to strip; `rel/x` has one. What else could produce the passing observable?
  Only an absolute join onto `$PWD`, which is the behaviour under test. A
  root-anchored or unanchored base changes `path=` or hangs, and the bound
  turns a hang into a fail.
- **`.git` file.** `<r>/sm/.git` is written by `printf 'gitdir: x' >`, so it
  is a regular file with `gitdir:` content. A walk that stops there, or no
  walk at all, names an absent lock under `sm`, which reads `mask`, not
  `orphan`. The positive outcome and the exact `path=` together rule out both.
- **Trailing slash.** `grep -qxF` matches the whole line, so a doubled `/`
  fails. `<repo>/.git` exists at the first step of the walk, so the base keeps
  its trailing slash into the join. That makes the join's strip, not the
  walk, the thing under test.
- Self-quiet: `bash lib/matchers.sh <` each of `tests/probes-config.bats`,
  `tests/probes-edges.bats` and `tests/helpers/probes.bash` printed nothing,
  with `rc=1`.
- Line counts: `tests/probes-config.bats` 299, `tests/probes-edges.bats` 318,
  `tests/helpers/probes.bash` 130. All are under 400.

## Issues Found

### Major Issues

1. **`run_probe_bounded` was duplicated, and the local copy shadowed the
   shared one**
   - Location: `tests/probes-edges.bats:32-70` (its original definition),
     `tests/helpers/probes.bash:85-126`.
   - Problem: the RED report moved the helper but left the edges file's
     definition in place. Because that definition comes after
     `load helpers/probes`, it overrode the shared one. The edges FIFO case
     therefore never ran the shared helper, and the helper comment's "Shared
     by tests/probes-edges.bats" was false. The two copies had already
     drifted: their comments differed.
   - Fix: I deleted the edges copy and merged its one extra detail, the FIFO
     grandchild, into the helper comment. The shared helper was then proven to
     bound the edges FIFO hang (see Mechanical checks).
   - **Status**: FIXED

### Minor Issues

1. **Unrelated edit to `hold_lock`'s comment**
   - Location: `tests/helpers/probes.bash`, the blank `#` line before "Shared
     by tests/probes.bats …".
   - Problem: the diff dropped a paragraph break that has nothing to do with
     this slice.
   - **Status**: FIXED (restored).
2. **The timeout branch's `kill` could trip errexit**
   - Location: `run_probe_bounded`, `kill -- "-$pid" 2>/dev/null`.
   - Problem: if the group exits between the `kill -0` poll and the kill,
     `kill` returns 1. Under bats' `set -e` the test would then abort on that
     line, before `$status` is set, with `set -m` still on. The test fails
     either way, but on the wrong line.
   - Fix: `|| :`, plus a clause in the helper comment explaining it.
   - **Status**: FIXED
3. **Build-progress narration in the new test comments**
   - Location: `tests/probes-config.bats`, in the header of the new block
     ("Follow-up from slice 8's code review …") and in the relative-cwd
     comment ("as slice 5's FIFO case is"). That comment also said "not just
     joined onto the payload's cwd unchanged", which was muddled.
   - Problem: slice 8's code review had already flagged this kind of slice
     narration in this file.
   - Fix: I rewrote both comments. They now state that the behaviour landed
     ahead of its tests and was proven by mutation. The relative-cwd comment
     also says why both `rel` and `rel/x` are run.
   - **Status**: FIXED

## Fixes Applied

- `tests/probes-edges.bats`: removed the local `run_probe_bounded` and its
  comment, 40 lines. The file now uses the shared helper.
- `tests/helpers/probes.bash`:
  - restored the blank comment line in `hold_lock`;
  - folded the FIFO-grandchild detail and the errexit note into the
    `run_probe_bounded` comment;
  - `kill -- "-$pid" 2>/dev/null || :`.
- `tests/probes-config.bats`: rewrote the block header and the relative-cwd
  comment. The test bodies are unchanged.

## Gates after fixes

- Four-file probe suite, foreground: `bats: 35 passed, 0 failed`.
- `git ls-files -z -- '*.sh' '*.bash' '*.bats' | xargs -0 shellcheck` gave
  `rc=0`.
- `direnv exec . just precommit` gave
  `precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests`,
  with bats at `130 passed, 0 failed`.
- `git diff --quiet lib/probes.sh` passes. Nothing was committed.

## Requirements Validation

| Requirement | Status | Evidence |
|---|---|---|
| Slice 11: relative cwd terminates, `rel` then `rel/x`, bounded | Satisfied | `tests/probes-config.bats` "relative cwd terminates at the working directory"; mutation 1 |
| Slice 11: `.git` file walked past | Satisfied | "a .git file is walked past"; mutation 2 |
| Slice 11: trailing slash, no `//` | Satisfied | "trailing slash on cwd"; mutation 3 |
| Residuals recorded, not tested | Satisfied | runbook slice 11 text; none tested |

## Positive Observations

- Every case asserts a positive outcome together with an exact `path=`, so
  each mutation reds on a precise line.
- The `.git`-free precheck reuses the established pattern from "no .git above
  cwd keeps cwd".
- Keeping the bounded runner in one place means a single definition now
  guards both hang-prone cases.
