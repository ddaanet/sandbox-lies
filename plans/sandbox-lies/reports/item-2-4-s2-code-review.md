# Review: Item 2.4 / slice 2 — code review

**Scope**: `lib/probes.sh` at HEAD (the slice-2 `gone` branch and how it
interacts with slice 1's absent-lock guard and `_probe_lock_path`). Tests are
out of scope and were not edited.
**Date**: 2026-09-25
**Mode**: review + fix (code review, TDD slice)

## Summary

The slice adds a `gone` branch beside `mask` under the absent-lock guard and
keeps `path=` common to both. The change is minimal and portable, and it
writes nothing to stderr. One real issue: the branch test was `= false →
mask, else gone`, so any value other than the literal `false` gave `gone`.
That includes an empty flag and `TRUE`. I inverted it to `= true → gone, else
mask`, which matches FR-5's "absent means false" and degrades better. No test
pins the new default. The proposed test is under "For the list revision".

**Overall Assessment**: Ready

## Issues Found

### Critical Issues

None.

### Major Issues

1. **An unexpected flag value produced `gone`, not the sandboxed default**
   - Location: lib/probes.sh `probe_git_lock`, absent-lock branch
   - Problem: `if [ "$flag" = false ]; then mask; else gone` sends `""`,
     `TRUE`, `1` or any other stray value to `gone`. I measured this before
     the fix: `[]`, `[TRUE]` and `[""]` all printed `gone`. Every source that
     speaks to the default says an unknown sandbox state reads as sandboxed:
     - FR-5: `dangerouslyDisableSandbox` absent means false.
     - D-8: an `excludedCommands`-unsandboxed call carries flag false and is
       accepted as indistinguishable from a sandboxed one.
     - Item 4.1's interface: `true`/`false`, absent meaning `false`.

     The verdict texts in detectors.md also say which misread costs less:
     - **A wrong `mask`** on a call that was really unsandboxed tells the
       agent to re-run unsandboxed, which is harmless. Its repeat-failure
       clause (A-4) then names the `GIT_INDEX_FILE` hook leak, which is the
       correct diagnosis for an absent lock on an unsandboxed call.
     - **A wrong `gone`** on a sandboxed call says "git cleaned it, retry
       once". The retry is sandboxed and hits the same mask, and the repeat
       clause then blames the hook leak instead of the sandbox.

     So `mask` is the safer default.
   - Fix: the test is now `[ "$flag" = true ]` → `gone`, else `mask`, with a
     four-line comment giving the reason. It behaves the same for the two
     contract values. After the fix, `false`, `TRUE`, `""` and `1` give
     `mask`, and `true` gives `gone`.
   - **Status**: FIXED. The behaviour is unpinned; see the list revision.

### Minor Issues

None.

## Questions from the dispatch

- **`set -u` with a missing `$1`.** `local flag="$1"` with no arguments
  prints `lib/probes.sh: line 27: $1: unbound variable` on stderr. The shell
  or subshell exits non-zero (127 for a direct `bash -c`, 1 inside `$(…)`)
  and prints no outcome. No change made:
  - The file header states that `set -u` is kept so that an unset variable
    stays an error.
  - A missing flag is a caller bug against a two-argument contract.
  - Item 4.1's hook always passes `$1`, per its interface.

  `${1-}` would turn that bug into a silent `mask`. Item 4.1 runs the probe
  inside `$(…) || exit 0`, so the failure costs the hook one silent verdict
  and never kills the hook.
- **Portability.** `[ ! -e ] && [ ! -L ]`, `local` and `printf` are all bash
  3.2 and BSD safe. No GNU-only flags were added. `path` is quoted throughout.
- **stderr.** The slice adds no tool calls, and the only redirection in the
  file is slice 1's `cat >/dev/null` stub. `[ -z "$stderr" ]` holds in all
  three tests.
- **Can slices 3–9 still go red?** Yes. Each falls through the absent-lock
  guard or hits a stub, so each gets an empty or wrong line 1:
  - A present lock (slices 3, 4, 6, 9, and 8's present case) fails `! -e`,
    so nothing is printed and line 1 is empty.
  - A `/dev/null` symlink (slice 5) exists, so it gets the same fall-through
    under both flags.
  - A relative path (slice 7) is tested against the process CWD. It prints
    `mask` or `gone`, or nothing, never `orphan`.
  - `probe_config_lock` (slice 8) is still the `cat >/dev/null` stub.

## Mutated-SUT run

I ran it once, on the committed SUT before the fix. The forbidden
implementation ignores the flag, so an absent lock is always `mask`.

- Exact-string replacement: `printf 'gone\n'` → `printf 'mask\n'`. It occurs
  once, per `grep -c`.
- `scripts/run-bats.sh tests/probes.bats` (foreground) gave:

  ```text
  not ok 2 absent lock, unsandboxed, is gone
  #   `[ "${output%%$'\n'*}" = gone ]' failed
  bats: 2 passed, 1 failed
  ```

  The slice's `gone` test went red on its line-1 assertion. Slice 1 and the
  non-UTF-8 test stayed green, as expected, since neither is flag-`true`.
- Restored by the inverse replacement at the `else` branch.
  `git diff --quiet lib/probes.sh` succeeded, and `cmp` against the
  pre-mutation copy matched.

Limit: this mutation shows the test catches a flag-blind probe. It does not
detect a reversion of the Major-1 fix to `= false → mask, else gone`: all
three tests stay green under that. That is why a list-revision test is needed.

## Fixes Applied

- lib/probes.sh `probe_git_lock`: the absent-lock branch now tests
  `"$flag" = true` for `gone`, with `mask` as the else, and carries a comment
  giving the reason (FR-5 default, and which misread degrades better).

## Verification

- `scripts/run-bats.sh tests/probes.bats`: `bats: 3 passed, 0 failed`.
- Self-quiet: `bash lib/matchers.sh < lib/probes.sh` gave no output, rc=1.
  The new comment quotes no diagnostic.
- `just precommit` final line: `precommit passed: plugin.json, hooks.json,
  shellcheck, bash -n, rumdl, line limits, links, tests` (98 passed,
  0 failed).
- Nothing committed.

## For the list revision

1. **`unexpected flag reads as sandboxed`**: slice 1's text and absent lock,
   with the flag `""` and then `TRUE`. Expect `mask` both times, plus the
   `path=` line. This pins Major 1 and is the only test that goes red if the
   test reverts to `= false`. It pairs with slice 2: the same fixture, and
   the only difference is whether the flag is the literal `true`.
2. **Present lock under flag `true`** (carried from the test review, and
   still open): slice 3 run under both flags, expecting `orphan` both times.
   Without it, "flag `true` and not a character device → `gone`" passes the
   whole list.
3. **Slice 7's CWD must differ from `$2`.** A probe that resolves the
   relative path against the process CWD instead of `$2` passes slice 7 if
   the test runs from `$2`. It also misfires if the bats CWD (the repo root)
   holds a real `.git/index.lock`, for example when the suite runs inside a
   git hook. Have the test `cd` to an unrelated directory before
   `run_probe`, so only `$2` can supply the lock.

## Requirements Validation

| Requirement | Status | Evidence |
|---|---|---|
| detectors.md `gone`: flag true, path absent | Satisfied | lib/probes.sh `= true` branch; test 2 green, reds under the flag-blind mutation |
| FR-5 absent flag = false | Satisfied (unpinned) | `else mask`; list revision 1 |
| A-3: exit 0, `path=` line, no stderr | Satisfied | `path=` common to both outcomes; `[ -z "$stderr" ]` holds |
| NFR-2 portability | Satisfied | POSIX `test` forms only |
| FR-11 self-quiet | Holds | matchers.sh gave no output, rc=1 |

## Positive Observations

- `path=` is printed once, after the outcome, and is shared by both absent
  outcomes, so the two cannot drift apart.
- Slice 1's `! -L` guard still sends a dangling symlink to the present-lock
  path, which is correct.
- The GREEN change was held to the one branch, with no work taken from
  slices 3–9.
