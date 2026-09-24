# Review: Item 2.4 / slice 3 — code review

**Scope**: `lib/probes.sh`, the orphan branch the slice commit (HEAD,
`✨ Item 2.4/3 — present unheld lock is orphan`) added to `probe_git_lock`.
Tests out of scope (not edited).
**Date**: 2026-09-25
**Mode**: review + fix (code review, TDD slice)

## Summary

The branch passes its three tests. But every edge case the dispatch named
misbehaved when I ran it (scratch runs in `$TMPDIR`, output below):

- A FIFO at the lock path hung the probe.
- A directory, an unreadable lock and a dangling symlink each wrote to
  stderr.
- A lock that vanished before `stat` printed `orphan` with
  `age=<seconds since the epoch>` and a `stat` error.
- A future mtime printed a negative age.

All of these are fixed in place. Each fix is a behaviour change that no test
pins yet, so each has a proposed test under "For the list revision". Slices
4–9 still red.

**Overall Assessment**: Ready (after fixes). The pinning tests belong in the
next list revision.

## Edge cases observed on the committed branch

Each case was run through `probe_git_lock` with a `timeout 3` wrapper and the
error text built from fragments. The paths were in a scratch directory, and
`$2` was a nonexistent directory.

| case | stdout | stderr |
|---|---|---|
| directory at the lock path | `orphan`, `bytes=0`, `age=0` | `wc: 'standard input': Is a directory` |
| FIFO at the lock path | nothing; rc 124 (`wc` blocked on the open until the timeout) | — |
| unreadable lock (`chmod 000`) | `orphan`, `bytes=` (empty), `age=0` | `…/u.lock: Permission denied` (the shell's redirect) |
| future mtime (`touch -t 2099…`) | `age=-2280615849` | — |
| dangling symlink at the lock path | `orphan`, `bytes=` (empty) | `…: No such file or directory` |
| lock removed just before `stat` runs (a `stat` stub on `PATH` removes it, then runs the real `stat`), flag `true` and flag `false` | `orphan`, `bytes=7`, `age=1790289351` | `stat: cannot statx …: No such file or directory` |

The vanished-lock row is the arithmetic-garbage case the dispatch asked
about. `mtime` is set to the empty string, so `set -u` does not fire, and
bash evaluates an empty operand in `$((now - mtime))` as 0. The age comes out
as the current epoch time, which is a plausible-looking integer.

## Issues Found

### Critical Issues

None.

### Major Issues

1. **A vanished lock reads as `orphan` with the epoch as its age**
   - Location: lib/probes.sh, orphan branch (`mtime=$(stat -c %Y "$path")`)
   - Problem: git removes a lock when the process holding it exits, so the
     lock can disappear between the `-e` test and `stat`. The probe then
     does three wrong things:
     - it prints `orphan`, which tells the agent the lock is still there;
     - its age is the current epoch time;
     - the `stat` error goes to stderr.

     Slice 4 puts a holder check (`fuser`, or on macOS a slow `lsof`) inside
     this window. A lock whose holder exits during that check is the common
     case, not a rare one.
   - Which outcome: `gone`, whatever the flag. The probe saw a real lock
     outside the sandbox, and then saw it removed. That matches the `gone`
     verdict text: "No lock exists now; git cleaned it after the failure.
     Retry once." `mask` would claim that "no such file exists outside the
     sandbox", which the probe has just disproved. `orphan` and `unknown`
     would claim the lock still exists.
   - Fix: capture `stat`'s stdout and stderr together (`2>&1`) as the
     capture-and-match form, not a suppression. The match is on the lock's
     presence, not on the message text, because the text differs between
     GNU, BSD and the slice 9 stub:
     - `stat` fails and the path is now absent (`! -e` and `! -L`): print
       `gone` and `path=`, and return.
     - `stat` fails and the path is still present: print the captured text
       on stderr and leave out the `age=` line.

     `stat` now runs before the size read, so a lock that vanished is
     detected before `wc` opens it.
   - Checked: the stub run above now prints `gone` and `path=` under both
     flags, with empty stderr. A `stat` stub that fails while the lock stays
     present prints its message on stderr and `orphan`, `bytes=7` and `path=`,
     with no `age=` line.
   - **Status**: FIXED (pinning test in the list revision; docs row flagged
     below)

2. **A FIFO at the lock path blocks the probe until the hook times out**
   - Location: lib/probes.sh, `wc -c <"$path"`
   - Problem: `<"$path"` on a FIFO with no writer blocks in `open(2)`. The
     hook would be killed at its 10 s timeout, and every annotation for that
     call would be lost. A directory, an unreadable lock or a dangling
     symlink makes the same read write to stderr and print `bytes=0` or an
     empty `bytes=`.
   - Fix: read the size only when `[ -f "$path" ] && [ -r "$path" ]` is true;
     otherwise leave out the `bytes=` line. The guard removes the expected
     failures, so nothing needs capturing. A comment states the residual
     case: a lock that vanishes between the guard and the open still prints
     the shell's redirect error. That window is microseconds, because the
     `stat` above has just seen the lock.
   - Checked: FIFO, directory, unreadable and dangling cases now return
     immediately with `orphan`, no `bytes=` line, and empty stderr.
   - **Status**: FIXED (pinning tests in the list revision)

### Minor Issues

1. **Clock skew gives a negative age**
   - Location: lib/probes.sh, `age=$((now - mtime))`
   - Problem: a future mtime printed `age=-2280615849`. The slice contract
     and every test assert that `age` is an integer ≥ 0.
   - Fix: clamp a negative age to 0, with the comment "An mtime in the future
     (clock skew) reads as just written."
   - **Status**: FIXED (pinning test in the list revision)

2. **`age=` computed from an empty or failed `mtime`**
   - Location: lib/probes.sh, same line
   - Problem: the arithmetic ran whatever `stat` returned. Today on macOS,
     before slice 9, BSD `stat -c` fails, so `age` would be the epoch time.
   - Fix: the age is computed and printed only when `mtime` is non-empty,
     which happens only after `stat` succeeds. The rule is now uniform: a
     key line appears only when its value was read.
   - **Status**: FIXED

### Checked, no finding

- **`local` placement**: `local mtime bytes='' now age` sits inside the
  `else`. In bash, and in bash 3.2 too, `local` is function-scoped wherever
  it is declared. No `local v=$(cmd)` masks a status: `mtime` is declared
  first and assigned inside `if !`, so `stat`'s exit status reaches the test.
- **`tr -d '[:space:]'` under BSD**: POSIX character classes are supported
  by BSD `tr`, and the strip removes BSD `wc`'s left padding. The strip is
  not pinned, though (mutation below).
- **No `2>/dev/null`**: the only redirect I added is the `stat` `2>&1`
  capture, and its text reaches stderr whenever the vanished-lock match does
  not explain it.

## Mutation run (once, in place)

- Mutation: `bytes=$(wc -c <"$path" | tr -d '[:space:]')` →
  `bytes=$(wc -c <"$path")`. `command grep -c` returned 1 on the target
  before the mutation, and `grep -c 'tr -d'` returned 0 after it.
- `scripts/run-bats.sh tests/probes.bats` gave **6 passed, 0 failed**. The
  slice's tests stayed green, so the BSD padding strip is unpinned on Linux:
  GNU `wc -c` on stdin does not pad. This confirms the test review's
  recommendation (see the list revision).
- Restored by the inverse replacement. `grep -c "tr -d '[:space:]'"` returned
  1, and the post-restore gate is green (below).

## Later slices still red

After the fixes, I traced each later slice's named test through the current
code:

- **Slice 4** (`held`, `pid=`): there is no holder check, so the probe prints
  `orphan`, and the test reds on line 1.
- **Slice 5** (symlink to `/dev/null`, `mask` under both flags): `stat`
  reads the link (no dereference) and succeeds, and `-f` is false for a
  character device, so the probe prints `orphan` with no `bytes=` line. The
  test reds on line 1.
- **Slice 6** (`unknown`): the probe prints `orphan`, and the test reds on
  line 1.
- **Slice 7** (relative path, run from an unrelated CWD): the relative path
  is not found, so the probe prints `mask` where the test wants `orphan`,
  and it reds.
- **Slice 8**: `probe_config_lock` is still the stub, so the test reds.
- **Slice 9** (`make_bsd_stubs stat`, which refuses `-c`): `stat` fails
  while the lock is present. The refusal reaches stderr and there is no
  `age=` line, so the test reds on `[ -z "$stderr" ]` and on the `age=`
  match.

  Before this fix, slice 9 could have gone green by accident apart from
  stderr, because `age=<epoch>` satisfies both `^age=[0-9]+$` and `> 86400`.

## For the list revision

Proposed tests, none written. Each fix above is already in the SUT, so each
test needs a mutation proof in place of a red, as slice 3 did for `unexpected
flag reads as sandboxed`.

1. **`vanished lock is gone`**: a present 7-byte lock, with a `stat` stub on
   `PATH` that removes its file operand and then runs the real `stat`. Run it
   under flag `false` and flag `true`. Expect `gone` both times, the exact
   `path=` line, no `bytes=` or `age=` line, and empty stderr.
   - Mutation: route a failed `stat` to the `orphan` print, or to the
     absent-lock flag logic. The second mutation reds the flag-`false` run.
2. **`non-regular lock has no size`**: a FIFO at the lock path (`mkfifo`).
   Expect `orphan`, no `bytes=` line, empty stderr, and a return well inside
   the test. Wrap the call in a background job plus `kill` rather than GNU
   `timeout`, which macOS lacks.
   - A directory at the lock path gives the same result and is cheaper; use
     one or both.
   - Mutation: drop the `[ -f ]` guard.
3. **`future mtime is age 0`**: `touch -t 209901010000` on a present lock.
   Expect `age=0` exactly.
   - Mutation: drop the clamp.
4. **Slice 4 (holder check)**:
   - Order the reads so that `stat` still runs after the holder check, or
     re-check presence after it. A lock whose holder exits during `fuser` or
     `lsof` is the realistic vanish, and it must read `gone`, not `orphan`.
   - A held lock under a quoted, spaced path is the only case that pins the
     quoting of `lsof` and `fuser` (carried over from the test review).
5. **Slice 9 (BSD)**: add a `wc` stub to `bsd-stubs.bash` that left-pads
   its count as BSD does. Without it the `tr` strip is unpinned (mutation
   above). Also pin the age against the backdated mtime (`age` within a
   minute of `now - 946684800`), not just `> 86400`, so an age derived from
   something other than the mtime cannot pass.
6. **Item 4.1 (verdicts)**: `orphan` and `unknown` can now arrive without a
   `bytes=` line (non-regular or unreadable lock) or an `age=` line (`stat`
   failed with the lock present). The verdict text must not interpolate a
   missing value.

## Deferred Items

The following items were identified but are out of scope:

- **`docs/references/detectors.md` git-lock outcome table**: the `gone` row
  reads "flag true, path absent". The probe now also prints `gone` under
  flag `false` when the lock vanishes between the presence test and `stat`.
  Reason: `docs/` is scope OUT (the phase-boundary corrector owns it). The
  row needs a clause such as "or present when probed and removed during the
  probe", which is for that corrector or for Item 4.1.
- **Text with no lock line** (an empty `path`): left open by the runbook's
  slice 3 note. Not re-raised.

## Fixes Applied

- lib/probes.sh, `probe_git_lock` orphan branch:
  - `stat` moved first, with capture-and-match: a vanished lock prints
    `gone` and `path=`; any other failure is surfaced on stderr and the
    `age=` line is left out (Major 1).
  - The size read is guarded by `[ -f ] && [ -r ]`, and the `bytes=` line is
    left out otherwise; the residual race is commented (Major 2).
  - Negative ages are clamped to 0 (Minor 1).
  - The age is computed only from a read `mtime` (Minor 2).
- No other file changed.

## Gate

- `scripts/run-bats.sh tests/probes.bats`: `bats: 6 passed, 0 failed`, both
  after the fix and after the mutation restore.
- `just precommit`, final line: `precommit passed: plugin.json, hooks.json,
  shellcheck, bash -n, rumdl, line limits, links, tests`
  (`bats: 101 passed, 0 failed`).

## Requirements Validation

| Requirement | Status | Evidence |
|---|---|---|
| Slice 3: present unheld 7-byte lock, both flags → `orphan`, `bytes=7`, `age=` ≥ 0 | Satisfied | `present unheld lock is orphan` green |
| Slice 3: quote and space in path → `orphan`, full `path=` | Satisfied | `quote and space in the lock path` green |
| A-3: exit 0, line 1 in `mask\|gone\|held\|orphan\|unknown` | Satisfied, now also on the edge cases | FIFO no longer hangs; vanished lock → `gone` |
| No stderr suppression | Satisfied | no `2>/dev/null`; `stat` stderr captured and surfaced unless explained |
| Portability (bash 3.2, BSD) | Satisfied for this slice | no new GNU-only form; `stat -c` is the named fallback slice 9 extends |

## Positive Observations

- Every added tool call quotes `"$path"`, so the path with a quote and a
  space reaches `wc` and `stat` intact.
- The green step stayed minimal: there is no holder check, BSD `stat`
  attempt or character-device rule, so slices 4–9 keep their reds.
- The comment on the BSD `wc` padding names why the strip exists.
