# Code review: Item 2.4 / slice 8 (closing): config-lock probe and walk-up resolution

**Scope**: `lib/probes.sh`. This covers slice 8's change at HEAD: the
config-lock extraction, the `_probe_lock_at` helper shared by both probes,
the walk-up resolution and the `$2` fallback. As the item's closing review,
it also covers the whole file against the item text and its Interfaces
block. The tests are out of scope and were not edited.
**Item text**: the current runbook's Item 2.4. A relative lock path resolves
against the nearest ancestor of `$2` that holds `.git`, `$2` itself included,
and falls back to `$2`. A missing or empty `$2` falls back to the probe's
working directory, never `/`. The brief's copy of this text is stale.
**Date**: 2026-09-25
**Mode**: review + fix (TDD code review)

## Summary

The helper lift is behaviour-preserving, and the config-lock extractor is
correct. The walk-up had one critical defect: a relative `$2` never
terminates, which hangs the probe. It also had one major defect: it stopped
at a `.git` file, and git never prints a relative lock path from a directory
whose `.git` is a file. Both are fixed, along with a doubled `/` in `path=`
and two inaccurate comments. All suites stay green. None of the new
behaviours is pinned by a test yet; the four proposed follow-up cases are
listed below.

**Overall Assessment**: Ready. It needs follow-up tests, which are listed
under "For the list revision".

## Issues Found

### Critical Issues

1. **A relative `$2` makes the walk-up loop forever**
   - Location: `lib/probes.sh` `_probe_resolve_path` at HEAD, lines 188-198.
   - Problem: `${dir%/*}` leaves a value with no `/` in it unchanged. For
     `$2` = `rel`, `rel/x` or `.`, `dir` either stops shrinking at a
     slash-free value or never shrinks at all. It never equals `/`, and the
     loop never exits unless some `.git` turns up. I reproduced this on the
     HEAD SUT: `timeout 3` on `_probe_resolve_path .git/config.lock rel`
     (also `rel/x` and `.`) returned `rc=124` in a directory with no `.git`
     above it. The hook calls this probe, so the hang would last until the
     hook times out.
   - Fix: a relative base is anchored on `$PWD`
     (`case "$dir" in /*) ;; *) dir="$PWD/$dir" ;; esac`). From there each
     step strictly shortens an absolute path, reaches the empty string, which
     becomes `/`, and breaks. After the fix, `rel`, `rel/x` and `.` resolve
     to `$PWD/rel/.git/…`, `$PWD/rel/x/.git/…` and `$PWD/./.git/…`, each with
     `rc=0`. Anchoring on the working directory is the only reading of
     "ancestor of `$2`" that makes sense for a relative `$2`. It also matches
     the item's rule that the working directory is the fallback.
   - **Status**: FIXED.

### Major Issues

1. **The walk stopped at a `.git` file, where git never prints a relative
   path**
   - Location: `_probe_resolve_path`, `[ -e "$dir/.git" ]`, and its comment,
     "`-e`, not `-d`: a linked worktree's `.git` is a file".
   - Problem: the comment's premise is empirically false. I ran git 2.47.3
     in scratch repos:
     - From `main/sub`, config-lock printed the relative `.git/config`.
     - From a linked worktree's subdirectory, both the common config and
       `config --worktree` printed an absolute path
       (`…/main/.git/config` and `…/main/.git/worktrees/wt/config.worktree`).
     - From a submodule, whose `.git` is a file, it printed
       `…/sup/.git/modules/sm/config`, absolute.
     - A `--separate-git-dir` repo printed absolute too.

     A relative lock path therefore only ever means "relative to the
     top-level of a `.git` directory". Stopping at a `.git` file always
     produces a path through a regular file. That path reads as absent, so
     the probe answers `mask` or `gone` even when an enclosing repo's lock is
     present.
   - Fix: `-e` became `-d`, and the comment now states the actual rule and
     why a `.git` file is walked past. I checked `$2` = `<r>/sm/d` with
     `<r>/sm/.git` a file and `<r>/.git` a directory: it resolves to
     `<r>/.git/config.lock`.
   - **Status**: FIXED. It is unpinned; mutation evidence is below.

### Minor Issues

1. **`path=` doubled the `/` for a trailing-slash or root base**
   - Location: `printf '%s/%s\n' "$base" "$1"`.
   - Problem: `$2` = `/a/b/` printed `/a/b//.git/config.lock`, and `$2` =
     `/` printed `//.git/config.lock`. `path=` is user-facing through the
     verdicts in Item 4.1.
   - Fix: the join now uses `"${base%/}"`. The two examples now print
     `/a/b/.git/…` and `/.git/…`. A base of `//` still gives `//.git/…`. That
     base is absurd, so this is not a finding.
   - **Status**: FIXED.
2. **Inaccurate comment in `probe_config_lock`**
   - Location: `lib/probes.sh:25-27` at HEAD.
   - Problem: the comment said that `"<base>/.lock"` would "resolve to a
     real, holdable directory entry". It names a file that normally does not
     exist. The real harm is that it names a file no error named.
   - **Status**: FIXED. The comment was rewritten.
3. **Inaccurate phrasing in the `_probe_resolve_path` comment**
   - Problem: "no tool call other than the walk itself" implied that the
     walk makes a tool call, which it does not. The comment also did not
     state the termination argument or the lexical-walk residuals.
   - **Status**: FIXED. The comment now says "one `[ -d ]` per ancestor and
     no process". It gives the termination argument and records two
     residuals: a symlinked base, and a base inside a gitdir.

### Out of scope (tests, not edited here)

- **Build-progress narration in `tests/probes-config.bats` comments**:
  "(Item 2.4 slice 8)", "tests/probes.bats already stands at 325 lines",
  "Already fixed (Item 2.4 slice 7's code review)", and "the same result the
  plain (pre-walk-up) join onto $2 already gave". These are test comments,
  and a code review never edits tests. **Status**: OUT-OF-SCOPE. The
  orchestrator may fold a comment cleanup into the follow-up test dispatch
  below.

## Whole-file checks against the item text and Interfaces

- **Contract.** Both probes take `<flag> <cwd>` and read stdin whole
  (`text=$(cat)`, so a writing caller never takes SIGPIPE). Every
  `_probe_lock_at` path prints the token on line 1, then `key=value` lines,
  and returns 0.
  - Only the literal `true` reads as unsandboxed.
  - `pid=` is singular.
  - `bytes=` and `age=` are omitted when unknown, and `path=` is always
    printed.
- **No file writes.** There is no `mktemp` and no redirect to a file. The
  holder tool's stdout goes out through fd 3.
- **`2>/dev/null`.** There is exactly one, at line 102: the BSD `stat -f %m`
  attempt, commented as exception 1 of 2. The item describes exception 2 as
  "`fuser`'s stderr captured and matched". It is handled that way, with no
  redirect to `/dev/null`: `err=$(fuser … 2>&1 >&3 3>&-)`, then `<path>:`
  followed by access letters only is dropped, and anything else passes
  through. The inline comment labels it exception 2 of 2. The two
  `>/dev/null` on `command -v` discard stdout only.
- **bash 3.2 and BSD.** The walk uses only `${2:-$PWD}`, `case`, `${dir%/*}`
  and `[ -d ]`. No `dirname` process is spawned. `${base%/}` is POSIX. There
  are no arrays, no `mapfile` and no `${x,,}`.
- **Loop termination.** It is now guaranteed. `dir` is absolute on entry,
  each `${dir%/*}` removes at least the last `/` and what follows it, an
  empty result maps to `/`, and `/` breaks.
- **Cost bound (NFR-3).** The walk does one `[ -d ]` stat per path
  component of the base and never recurses into trees.
- **Corner cases I checked by running them:**
  - `/` gives `/.git/…`
  - `/a/b/` gives `/a/b/.git/…`
  - `rel`, `rel/x`, `.` and `''` terminate and resolve under `$PWD`
  - a trailing-slash base whose ancestor holds a `.git` file walks past it
- **Symlinked base.** The walk is lexical. It is a residual, now recorded
  in the comment.
- **Whitespace and quotes.** Every expansion is quoted. I ran the extractor
  on the config path `…/a: File exists b/config` under `LC_ALL=C` and
  `LC_ALL=C.UTF-8`. Both gave `orphan`, `path=…/a: File exists b/config.lock`
  byte-exact, so the capture runs to the last `: File exists`.
- **Self-quiet.** `bash lib/matchers.sh < lib/probes.sh` printed nothing and
  returned rc=1.
- **Narration.** There are no Item or slice references in `lib/probes.sh`.
- **Length.** The file was 257 lines at HEAD and is 269 now, under the 400
  cap. The comment growth carries the empirical rule and the residuals.

## Mutated-SUT run (once)

- **Mutation**: an exact-string replacement of
  `if [ -d "$dir/.git" ]; then` with `if [ -e "$dir/.git" ]; then`.
  Afterwards `grep -c` found the `-e` form once.
- **Run**:
  `scripts/run-bats.sh tests/probes.bats tests/probes-edges.bats tests/probes-tools.bats tests/probes-config.bats`,
  in the foreground. Result: **32 passed, 0 failed**. No test detects the
  wrong walk.
- **Restore**: the inverse exact-string replacement. `grep -c` found the
  `-d` form once and the `-e` form zero times, and `bash -n` passed.

The relative-base anchoring and the `${base%/}` join are unpinned too. No
test passes a relative or trailing-slash `$2`, and none uses a colon in a
config path (`grep` over `config_lock_error` call sites found 0 hits).

## For the list revision

All four cases fit in `tests/probes-config.bats` (228 lines).

1. **`relative cwd terminates at the working directory`**
   - Setup: run from `$BATS_TEST_TMPDIR/w`, with no `.git` in `w` or any
     ancestor (assert this first, as `no .git above cwd keeps cwd` does).
     Use relative git-lock text, `$2` = `rel` (no slash), then `rel/x`, the
     lock absent, flag `false`.
   - Expected: `mask`, `path=$BATS_TEST_TMPDIR/w/rel/.git/index.lock`.
   - Run it as a background job with a bounded wait and `kill`, not GNU
     `timeout`, as slice 5's FIFO case does, so that a regression fails the
     test instead of hanging the suite.
   - Mutation to prove it: remove the anchoring `case`.
   - **Land now.** The defect it guards is a hang.
2. **`a .git file is walked past`**
   - Setup: `<r>/.git` a directory, `<r>/sm/.git` a file
     (`gitdir: x`), `$2` = `<r>/sm/d`, config-lock text naming `.git/config`,
     the lock present at `<r>/.git/config.lock`.
   - Expected: `orphan`, `path=<r>/.git/config.lock`.
   - Mutation to prove it: the `-d` → `-e` replacement above, which leaves
     all 32 tests green today.
   - **Land now.**
3. **`trailing slash on cwd`**
   - Setup: `$2` = `<repo>/` with `<repo>/.git` present, and relative
     git-lock text.
   - Expected: `path=<repo>/.git/index.lock` exactly, with no `//`.
   - Mutation to prove it: `"${base%/}"` → `"$base"`.
   - **Land now.** It is cheap and can share case 2's fixture style.
4. **`config path holding ": File exists" and a non-UTF-8 byte`**
   - Setup: an absolute config path under a directory named
     `a: File exists b\351`, the lock present, run under
     `LC_ALL=C.UTF-8`.
   - Expected: `orphan`, `path=` byte-exact.
   - Mutations to prove it: `\(.*\): File exists` → `\([^:]*\): File exists`
     for the last-occurrence capture, and dropping the extractor's
     `LC_ALL=C`. This pins both claims in `_probe_config_lock_path`'s
     comment, as slice 2's case does for git-lock.
   - **Land now.** It is cheap. If the list must close, record it as a
     residual instead: the git-lock twin already pins the shared technique.

Residuals to record, not test:

- **Symlinked base.** The walk follows the link's lexical parents. Git
  discovers the top-level physically, so a `$2` like `/x/link` →
  `/y/repo/sub` misses `/y/repo/.git`. Fixing it needs `pwd -P` in a
  subshell, which is a design call.
- **Base inside a gitdir.** In a bare repo or inside `.git`, git prints
  `config` relative to the gitdir. I verified this for `cd b.git` and
  `cd m/.git`. The walk joins onto the base when no worktree encloses it,
  which is correct at the gitdir's top. When a worktree does enclose it, the
  walk joins onto that worktree instead, which is wrong. Rare for a Claude
  session.

## Fixes Applied

- `lib/probes.sh` `_probe_resolve_path`:
  - A relative base is anchored on `$PWD`, which guarantees the walk
    terminates.
  - `[ -e "$dir/.git" ]` became `[ -d "$dir/.git" ]`.
  - The join uses `"${base%/}"`.
  - The header comment was rewritten: the empirical rule, the termination
    argument, the cost bound and the two residuals.
- `lib/probes.sh` `probe_config_lock`: the comment on the empty-extraction
  guard was corrected.

## Gate

- The four probe suites ran in the foreground and gave 32 passed, 0 failed,
  both after the fixes and after the mutation restore.
- `just precommit` ran in the foreground after the last edit. Its final line
  was `precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests`,
  with bats at 127 passed, 0 failed.
- Nothing was committed.

## Requirements Validation

| Requirement | Status | Evidence |
|---|---|---|
| FR-4 (config-lock probe to A-3) | Satisfied | `probe_config_lock`, `_probe_config_lock_path`, `_probe_lock_at` |
| Item 2.4 path-base rule | Satisfied | `_probe_resolve_path`: nearest `.git` directory, then `$2`, then `$PWD`, never `/` |
| NFR-2 (bash 3.2, BSD, whitespace) | Satisfied | builtins-only walk, all expansions quoted, `LC_ALL=C` extractor |
| NFR-3 (bounded cost) | Satisfied | one `[ -d ]` per base component, no recursion |

## Positive Observations

- The helper lift is behaviour-preserving, and both probes now differ only
  in extraction.
- The empty-extraction guard in `probe_config_lock` keeps the pathless case
  pathless.
- The config extractor's greedy capture handles `: File exists` inside the
  path, which I verified by running it.
