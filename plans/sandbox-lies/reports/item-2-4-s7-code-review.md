# Review: Item 2.4 / slice 7 — code review (`relative path resolves against cwd`)

**Scope**: `lib/probes.sh` as changed by HEAD (`_probe_resolve_path` and its
call in `probe_git_lock`). Tests read only.
**Date**: 2026-09-25
**Mode**: review + fix (TDD code review)

## Summary

The join itself is correct and minimal: a relative path is joined onto `$2`
as given, and every later check reads the reassigned `path`. It has one
regression. For text with no lock line, the probe now joins the empty path
onto `$2` and reads the directory `$2/`. It reports that directory as `held`
with an unrelated pid, and it passes fuser's stderr through. Before this slice
the same text gave `mask`/`gone` with an empty `path=`. I restored that
behaviour, which leaves the pathless outcome as open as it was. I also rewrote
the comment. Both suites pass and precommit is green.

**Overall Assessment**: Ready

Held open as the dispatch requires, and not decided here: the outcome for a
missing or empty `$2`, and whether the base should be the worktree top-level.

## Issues Found

### Critical Issues

None.

### Major Issues

1. **An empty extracted path now resolves to `$2/` and reads `held`**
   - Location: `lib/probes.sh`, `_probe_resolve_path` (the `*)` arm took `''`)
   - Problem: for text with no lock line, the join produced `$2/` (or `/` when
     `$2` is empty). That path exists, so the probe ran fuser on the directory.
     fuser lists every process whose cwd is that directory. Observed output:
     - `$2` = the repo, cwd = the repo: `held`, `pid=2`,
       `path=<repo>/`. fuser's `<repo>:cccc` went to stderr, because the
       trailing `/` defeats the `"$path:"` match.
     - `$2` empty: `held`, `pid=2`, `path=/`, with `/:  rrrr` on stderr.
     - HEAD~1 on the same pathless text: `mask`, `path=`.

     Slice 1's review left the pathless outcome open ("until something calls a
     probe ungated"). This slice replaced that open-but-harmless answer with a
     confident wrong one, and it depends on the process cwd.
   - Fix: an empty path now takes the `/*` arm and prints unchanged.
     Re-checked: `mask path=` under flag `false` and `gone path=` under flag
     `true`, which matches HEAD~1. No outcome is chosen, so the question stays
     open.
   - **Status**: FIXED

### Minor Issues

1. **The comment named a future change and misread `$2`**
   - Location: `lib/probes.sh`, the comment above `_probe_resolve_path`
   - Problem: it said "<base> is $2 (the payload cwd)". Inside the function,
     `$2` *is* `<base>`, so the sentence meant the caller's `$2`. It also
     named a specific future change ("e.g. to the worktree top-level") that is
     an open design question, and it promised "a one-line edit at the call
     site below". Slice 8's lift may move or duplicate that call site.
   - Fix: the comment now says what the function prints for relative,
     absolute and empty paths, and that `<base>` is used as given. It says why
     an empty path is not joined, and that the probe passes its own `$2`, so a
     different base is an edit to that argument alone.
   - **Status**: FIXED

## Checked, no finding

- **Command substitution stripping trailing newlines.** The extractor's
  capture ends in `\.lock` and sed works line by line, so an extracted path
  never contains or ends in a newline. A path with an embedded newline splits
  git's line, so it never matches and reads as pathless. After the join, the
  output ends in `.lock`. After this review's fix, an empty path stays empty.
  In every case the only newline `$( )` strips is the `printf`'s own. A `$2`
  containing newlines keeps them, because they sit mid-string.
- **A path of `-` or a leading `-` reaching the tools.** `printf` takes the
  path only as a `%s` argument. `wc` reads it through a `<` redirect. The `[`
  tests take it as the operand of a unary primary. That leaves `stat`, `fuser`
  and `lsof`.
  - An extracted path always ends in `.lock`, so it is never exactly `-`.
  - After the join, a relative path starts with `$2`, and an absolute one
    starts with `/`. So a leading `-` reaches the tools only if `$2` itself
    starts with `-`, which an absolute payload cwd never does. This slice
    *removed* the pre-existing exposure: before it, a relative
    `-x/.git/index.lock` went straight to `fuser`.
  - Adding `--` is not portable. psmisc fuser 23.7 (this box) rejects
    `fuser -- file` with "No process specification given", and treats a bare
    `-` as its reset-options switch. lsof documents `--`. BSD/GNU `stat` take
    it through getopt. `lsof decides when present` pins lsof's exact argv
    (`-w -t <path>`), so `--` there would also break a test.
  - A `./` prefix would be the portable guard, but only for a non-absolute
    `$2`, and that belongs to the open `$2` question.
  - Residual: listed below for the list revision.
- **Slices 8–10 can still go red.**
  - Slice 8: `probe_config_lock` is still `cat >/dev/null` and prints nothing.
  - Slice 9: the probe calls only `stat -c %Y`. A BSD `stat` stub refusing
    `-c` puts the refusal on stderr and drops `age=`, and there is no `wc`
    padding stub yet.
  - Slice 10: an errored `fuser` with no pid still reads `orphan`.

  This slice touches none of those paths.
- **`${2-}`** keeps a missing `$2` from aborting under `set -u`. The outcome
  stays open, as the dispatch requires.
- **Helpers placed above their user.** This follows the file's existing
  pattern (`_probe_lock_path`, `_probe_holder_pids`), so it is not flagged.

## Mutated-SUT run

- Mutation: in `lib/probes.sh`, `"${2-}"` was changed to `"$PWD"` on the
  resolve call. This is the forbidden process-cwd base.
- Run: `scripts/run-bats.sh tests/probes.bats tests/probes-edges.bats` in the
  foreground.
- Result: 17 passed, 1 failed. `not ok 11 relative path resolves against cwd`
  failed at line 318 on `grep -qxF "bytes=7"`: it found the decoy.
- Restored by the inverse exact-string replacement. A `git diff` grep for
  `PWD` or `2-}` shows no change to the call line.

The fix to the empty path is not pinned by any test, because the pathless
outcome is deliberately unpinned. See item 1 below.

## Fixes Applied

- `lib/probes.sh` `_probe_resolve_path`: `/*)` became `/* | '')`, so an empty
  path is not joined onto `<base>`.
- `lib/probes.sh`: the comment above `_probe_resolve_path` is rewritten, as
  described in Minor 1.

Gate: `just precommit` (foreground). Final line:
`precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests`
(bats: 113 passed, 0 failed).

## For the list revision

1. **Pathless text does not read the base directory.** This is the regression
   fixed above, and it is proven only by a manual run.
   - Proposed test: text with no lock line, `$2` = an existing directory, the
     probe run with that directory as its cwd, flags `false` and `true`.
   - Expected: line 1 is not `held` or `orphan`, there is no `pid=` line, and
     stderr is empty. That pins "never names `$2` itself" and leaves the actual
     outcome open, as slice 1 left it.
   - Mutation to prove it: drop `| ''` from the case arm.
   - Once the design picks a pathless outcome, tighten the assertion to that
     outcome.
2. **Non-absolute `$2` with a leading `-`.** This belongs with the open `$2`
   question. If the design validates `$2` as absolute, or reads anything else
   as `unknown`, it is covered. Otherwise, add a guard (`./` prefix) and a
   test: a relative `-d` directory as `$2` holding a present lock, a `fuser`
   stub on the tools-only `PATH` recording its argv. Expected: `orphan`, and
   the stub's first operand does not start with `-`.
