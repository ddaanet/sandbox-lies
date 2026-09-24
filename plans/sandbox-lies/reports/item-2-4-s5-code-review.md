# Review: Item 2.4 / slice 5 — code review (d)

**Scope**: `lib/probes.sh` at HEAD (the slice's `[ -c ]` branch), plus a
read of the whole file now that five slices have landed. Tests are out of
scope and were not edited.
**Date**: 2026-09-25
**Mode**: review + fix (TDD code review)

## Summary

The slice's rule is correct. `[ -c "$path" ]` runs after the absence test
and before the holder tool, `stat` and `wc`, and it returns `mask` under
either flag, which matches the detectors.md table row and design.md
("treats it as a mask, never as a file").

The whole-file read found three problems, all fixed:

- the control flow was a nested `if/else`
- the character-device comment gave a fixture as its reason
- a dangling-symlink lock leaked the holder tool's complaint to stderr

**Overall Assessment**: Ready

## Character-device rule: the cases the dispatch named

Each case was run against the SUT, both flags, from an unrelated CWD.

| Case | Result | Assessment |
|---|---|---|
| A character device under flag `true` | `mask` | Matches detectors.md ("mask either way") and design.md. Whether the `mask` *verdict* suits a call that was already unsandboxed is verdict text, so Item 4.1 owns it (see Recommendations). |
| A symlink to a directory | `orphan`, `age=`, no `bytes=`, empty stderr | Correct. `[ -c ]` is false. `fuser` on a fresh directory finds no holder. `stat -c %Y` does not follow the link and returns the link's own mtime. `[ -f ]` is false, so there is no size line. |
| A dangling symlink | before the fix: `orphan`, `age=`, and stderr `Specified filename <path> does not exist.` from `fuser` | Line 1 was right. The stderr was not (major issue 3). After the fix: `orphan`, `age=`, empty stderr. |
| `/dev/null` through a relative symlink (`../../…/dev/null`) | `mask` | Correct. The kernel resolves the link relative to its own directory, not the probe's CWD, and `path=` stays the lock path. |

Git creates a lock with `O_CREAT|O_EXCL`, and that fails with `EEXIST` on a
dangling symlink. So a dangling link at the lock path does produce this
error, and `orphan` is the correct reading: something is at the path, and
nothing can hold it.

## Contract check, every branch (after the fixes)

Every branch exits 0 and prints `path=$path` last:

- absent: `mask` (flag not `true`) or `gone` (flag `true`), then `path=`
- character device: `mask`, then `path=`
- held: `held`, `pid=`, then `path=`
- vanished at `stat`: `gone`, then `path=`
- otherwise: `orphan`, `bytes=` (regular readable file only), `age=`
  (when `stat` succeeded), then `path=`

`unknown` is still absent (slice 6). No `$2` resolution (slice 7).
`probe_config_lock` is still the inert `cat >/dev/null` (slice 8). No BSD
`stat` attempt (slice 9).

## Issues Found

### Critical Issues

None.

### Major Issues

1. **`probe_git_lock` nested five outcomes under one `if/else`, with
   `local`s declared mid-branch**
   - Location: `lib/probes.sh`, `probe_git_lock` (HEAD lines 65–152)
   - Problem: the function mixed two styles:
     - the absent case fell through an `if/else`
     - every present-lock outcome (`mask`, `held`, vanished `gone`) returned
       early from inside the `else`

     So the whole present-lock path sat one level deeper than it needed to,
     and the `stat` failure path three levels deep. Two `local` statements
     sat part-way down the `else`. Each outcome printed its token and its
     `path=` line with separate `printf`s, so the `path=%s` line repeated
     five times. Slice 8 has to lift the present-lock logic out for
     `probe_config_lock`, and a nested `else` block is harder to lift.
   - Fix (behaviour-preserving):
     - the absent case ends in `return 0` like every other outcome, and the
       present-lock body moves out one level
     - all `local`s go on the function's first line, as in
       `_probe_holder_pids`
     - each single-shape outcome prints in one call,
       `printf '%s\n' <token> [pid=…] "path=$path"`, so the contract lines
       for that outcome read together
     - `orphan` keeps its conditional lines

     Maximum nesting inside the function drops from 3 to 2. All 12 tests in
     both suites stay green.
   - **Status**: FIXED

2. **The character-device comment justified the rule by a test fixture**
   - Location: `lib/probes.sh`, comment above `[ -c "$path" ]`
   - Problem: the comment explained the branch with "a symlink to /dev/null
     lands here". That symlink is only how the suite builds a character device
     without root, so the comment described the fixture and not why a
     character device means mask in production. It also pointed the reader
     at the doc table instead of stating the reason.
   - Fix: the comment now gives the production reasons:
     - a character device is a `/dev/null` sandbox mask, which unsandboxed
       readers have seen while another session's sandbox was live (grounded
       in design.md's "Why the hook can see" paragraph)
     - it is never a lock git wrote, so it reads `mask` under either flag
     - it is tested before the holder tool, `stat` and `wc`, because
       `/dev/null` is open in many processes and would read `held`
     - `[ -c ]` follows a symlink

     No build-progress narration and no box-specific claim.
   - **Status**: FIXED

3. **A dangling-symlink lock sent the holder tool's complaint to stderr**
   - Location: `lib/probes.sh`, `_probe_holder_pids`, the last guard
   - Problem: the guard that keeps the tool's stderr quiet once the lock is
     gone tested `[ ! -e ] && [ ! -L ]`. A dangling symlink passes `-L`, so
     the guard did not fire. `fuser` stats the link's target, and
     `Specified filename <path> does not exist.` then reached stderr on
     every call, under both flags. Measured before the fix. `lsof` reports
     the same way (`status error on …`). The size-read comment already
     lists a dangling symlink as an expected shape, so the holder check was
     the one step that did not handle it. `-e` follows the link, so
     `[ ! -e ]` alone covers both cases where the tool has nothing to stat:
     - the vanished lock (unchanged)
     - the dangling link, where no process can hold a missing target open
   - Fix:
     - guard reduced to `[ ! -e "$path" ]`
     - the function's header comment says what the second case now covers

     The `stat` vanish check keeps `[ ! -L ]`, because `stat -c` does not
     follow the link and succeeds on a dangling link. After the fix, a
     dangling link gives `orphan`, `age=`, no `bytes=` and empty stderr.
     There is no test yet (see For the list revision).
   - **Status**: FIXED

### Minor Issues

None beyond the above.

## Fixes Applied

- `lib/probes.sh` `_probe_holder_pids`:
  - the absence guard is now `[ ! -e "$path" ]`
  - the header bullet names the dangling-symlink case (major 3)
- `lib/probes.sh` `probe_git_lock`:
  - the absent case returns early, and the present-lock body moves out one
    level
  - the `local`s are merged onto line 1
  - each single-shape outcome prints in one `printf '%s\n' …` (major 1)
- `lib/probes.sh`: the character-device comment is rewritten (major 2)

`lib/probes.sh` is 152 lines. `shellcheck lib/probes.sh` is clean.
`bash lib/matchers.sh < lib/probes.sh` prints nothing (rc=1, self-quiet).

## Mutated-SUT run (once)

This mutation is the implementation the slice rules out: a character device
folded into the absence test, so it follows the flag.

- The absence test
  `if [ ! -e "$path" ] && [ ! -L "$path" ]; then` (followed by
  `if [ "$flag" = true ]; then`) was replaced by
  `if { [ ! -e "$path" ] && [ ! -L "$path" ]; } || [ -c "$path" ]; then`.
  The string occurs exactly once; the script checked the count.
- Run: `scripts/run-bats.sh tests/probes.bats tests/probes-edges.bats` gave
  `11 passed, 1 failed`. The failure was `not ok 9 character device is mask`
  at line 274, `` `[ "${output%%$'\n'*}" = mask ]' ``, which is the flag
  `true` run (the mutant printed `gone`). The flag `false` run could not
  catch this mutation, and the flag `true` run does.
- Restored by the inverse replacement: `grep -c '|| \[ -c' lib/probes.sh`
  printed 0, and the suites were back to `12 passed, 0 failed`.

Every test that bears on this rule went red. The test review had already
pinned the other plausible wrong rule, a check on `[ -L ]` instead of
`[ -c ]`.

## For the list revision

- **`dangling symlink lock is a quiet orphan`** (`tests/probes-edges.bats`;
  proves major 3):
  - Fixture: `ln -s "$BATS_TEST_TMPDIR/nowhere" "$lock"`.
  - Run with flag `false` and flag `true`.
  - Expect: `orphan`, `path=$lock`, an `age=` line, no `bytes=` line, and
    empty stderr.
  - Proof by mutation: with the guard back at
    `[ ! -e "$path" ] && [ ! -L "$path" ]`, the stderr assertion goes red on
    this box, where `fuser` is psmisc. The case also pins that a dangling
    link reads neither `mask` nor `gone`.
- **`symlink to a directory is orphan without size`** is optional. The
  directory half of `non-regular lock has no size` already covers a
  directory, and the only thing a symlink adds is `[ -c ]`/`[ -f ]`
  following the link. Take it only if slice 7 or 8 changes how the path is
  resolved.

## Recommendations

- `REFACTOR-NEEDED: lib/probes.sh — lift everything after path extraction
  in probe_git_lock into a helper (e.g. _probe_lock_at <flag> <path>) that
  probe_config_lock also calls.`
  - Timing: slice 8's GREEN, not a separate dispatch now. After the flatten
    above, the move is a cut and paste with no re-indenting.
  - Why not now: slice 7 has not yet decided where `$2` resolution goes,
    whether in each caller or inside the helper, and cutting the helper
    boundary today would presuppose that answer.
- For slice 9, which rewrites the mtime read:
  - `mtime=$(stat … 2>&1)` also captures stderr on *success*, and
    `$((now - mtime))` evaluates whatever it holds as arithmetic. GNU
    `stat -c %Y` prints nothing on stderr when it succeeds, so this does not
    bite today.
  - The BSD-first rewrite should check the value is all digits
    (`case $mtime in ''|*[!0-9]*) …`) before the arithmetic, or keep the
    success-path stderr out of the variable.
- For Item 4.1 (out of scope here): the probe and detectors.md both give
  `mask` for a character device under flag `true`. The `mask` verdict's
  instruction "re-run with `dangerouslyDisableSandbox: true`" is a no-op
  for a call that was already unsandboxed. The verdict text for that case
  should be checked when the verdicts land.

## Gate

`cd /Users/david/code/sandbox-lies && just precommit`, final line:

```
precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests
```

It ran 107 tests: 107 passed, 0 failed. Nothing is committed. The only
change in the tree is `lib/probes.sh`, plus this report.

## Positive Observations

- The GREEN change was minimal, and it was placed where it keeps the holder
  tool, `stat` and `wc` away from the device, which is the ordering the item
  text requires.
- `path=` prints the lock path as named, not a resolved target, so the
  verdict names the file the user saw in git's error.
- Keying the rule on `[ -c ]` instead of `[ -L ]` means a symlink to a
  regular file still reads `orphan`, and the test review's control pins
  that.
