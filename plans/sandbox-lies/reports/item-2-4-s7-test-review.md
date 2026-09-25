# Review: Item 2.4 / slice 7 — test review (`relative path resolves against cwd`)

**Scope**: the uncommitted `tests/probes.bats` change (one new `@test`) and
`plans/sandbox-lies/reports/item-2-4-s7-red.md`. `lib/probes.sh` read only,
since no stub completion was needed.
**Date**: 2026-09-25
**Mode**: review + fix (TDD test review)

## Summary

The RED test fails on an assertion against the current SUT, and the rest of
the suite passes. The dispatch named several wrong implementations. Three of
them survived the test as written, each confirmed by a mutation run: trying the
process cwd first and falling back to `$2`, preferring `$PWD` when the relative
path exists there, and canonicalising `$2`. I changed the test so that all
three now fail. It still fails against the current SUT on an assertion, and a
plausible correct implementation passes it. Nothing is committed.

**Overall Assessment**: Ready

## Mechanical check

`cd /Users/david/code/sandbox-lies && scripts/run-bats.sh tests/probes.bats tests/probes-edges.bats`,
run in the foreground.

- **Before the fixes:** 17 passed, 1 failed. `not ok 11 relative path resolves
  against cwd` failed on `[ "${output%%$'\n'*}" = orphan ]`. This matches the
  RED report.
- **After the fixes:** 17 passed, 1 failed. `not ok 11` fails at line 318 on
  `grep -qxF "bytes=7"`. The current SUT now resolves `.git/index.lock` against
  the process cwd and finds the decoy there, so it reads `orphan` with
  `bytes=3`. The failure is still on an assertion; it just happens one line
  later.
- **Self-quiet:** `bash lib/matchers.sh < tests/probes.bats; echo rc=$?`
  printed nothing and `rc=1`, both before and after the fixes.
- **shellcheck `tests/probes.bats`:** the only output is the existing SC1091
  info notice on line 16. The `SC2016` disable is no longer needed and has been
  removed.
- **Line count:** `tests/probes.bats` is 320 lines, down from 324.

## Mutation runs (wrong-reason hunting)

Method: I copied `lib/` and `tests/` to a scratch directory under `$TMPDIR`,
keeping the same relative layout so `$ROOT` still binds correctly. I inserted
each mutant line directly after the `_probe_lock_path` extraction in
`probe_git_lock`, then ran both suites. The scratch copies have been deleted.

| Mutant | Original test | Revised test | Other cases that red |
|---|---|---|---|
| Correct: `case $path in /*) ;; *) path="$2/$path";; esac` | green | green | none |
| Current SUT (process cwd) | red (outcome `mask`) | red (`bytes=3`) | none |
| Resolves correctly, prints `path=` relative | red (path=) | red (path=) | none |
| Joins `$2$path`, no separator | red (outcome `mask`) | red (outcome) | none |
| Joins `$2/$path` always, absolute paths included | green | green | 1–10 (below) |
| Tries process cwd first, `$2` only when absent | **green** | red (`bytes=7`) | none |
| `$PWD/$path` when it exists there, else `$2` | **green** | red (`bytes=7`) | none |
| `$(cd "$2" && pwd -P)/$path` (canonicalised) | **green** | red (path=) | none |

**Absolute path joined onto `$2`:** slice 7 cannot catch this mutant, since its
text is relative. Slices 1–6 catch it because each passes an unrelated
`elsewhere` directory as `$2`:
- `absent lock, sandboxed, is mask` (slice 1) catches it on the path line: it
  prints `path=<elsewhere>/<abs lock>`, not the lock.
- `present unheld lock is orphan` (slice 3) catches it on the outcome: the
  joined path does not exist, so it reads `mask`, not `orphan`.

Every case in `probes.bats` from 1 to 10 went red under this mutant, so the
pin does not depend on any single test.

## Issues Found

### Critical Issues

None.

### Major Issues

1. **A fallback from the process cwd to `$2` passes**
   - Location: `tests/probes.bats`, new test (fixture)
   - Problem: the unrelated directory had no `.git` at all. A probe that tries
     the process cwd first and falls back to `$2` never found anything there,
     so it reached `$2` and passed. The same held for a probe that absolutises
     against `$PWD` when the path exists there. This is the "fallback supplies
     the rule's answer" shape. Resolving against the process cwd first is also
     the real risk slice 2's code review named: the bats cwd, the repo root,
     can hold a real `.git/index.lock` when the suite runs inside a git hook.
   - Fix: added a 3-byte decoy lock at `<unrelated>/.git/index.lock` and
     asserted `bytes=7`. Any read of the cwd path now reads `bytes=3`, and if
     that path is also printed, `path=` fails as well.
   - **Status**: FIXED

### Minor Issues

1. **The comment claimed `$2` was used "as given", but on Linux the test did
   not check it**
   - Location: `tests/probes.bats`, new test (comment and assertion)
   - Problem: the comment said `path=` is asserted against the literal repo
     path, not its realpath. That only holds where `$BATS_TEST_TMPDIR` sits
     under a symlink (macOS `/var/folders`). On this box a `pwd -P`
     implementation passed. So the test enforced the contract on one platform
     and not the other.
   - Fix: `$2` now reaches the repo through the symlink
     `$BATS_TEST_TMPDIR/link`, and the test expects
     `path=$link/.git/index.lock`. That enforces "as given" on every platform.
     "As given" matches every other case in the file, which print the path
     exactly as the error text gave it. If the orchestrator prefers to leave
     canonicalisation open, revert the `link` lines and cut the comment's last
     sentence.
   - **Status**: FIXED

2. **Nested `bash -c` instead of the shared `run_probe` helper**
   - Location: `tests/probes.bats`, new test (the `run` call)
   - Problem: every other case uses `run_probe`. This test re-sourced
     `lib/probes.sh` inside a `bash -c` and needed an `SC2016` disable with a
     three-line justification. Bats runs each test in its own process, so a
     `cd` in the test body cannot leak into another test.
   - Fix: replaced it with `cd "$unrelated"` followed by
     `run_probe probe_git_lock false "$link" "$(git_lock_error .git/index.lock)"`.
   - **Status**: FIXED

## Fixes Applied

- `tests/probes.bats` (the `relative path resolves against cwd` block):
  - added a decoy `abc` lock in the unrelated directory, plus a `bytes=7`
    assertion;
  - `$2` is now a symlink to the repo, and the test expects
    `path=$link/.git/index.lock`;
  - the `bash -c` wrapper and its `SC2016` disable are replaced by `cd` plus
    `run_probe`;
  - the comment is rewritten to describe the decoy and the as-given rule
    without quoting a diagnostic.

## For the list revision (not added to this slice)

1. **Relative config-lock paths are relative to the worktree top-level, not
   the payload cwd.** Verified with git 2.47.3 in a scratch repo.
   - `git add` prints `index.lock` absolute, whether run from the top-level,
     from a subdirectory or with `-C`. That matches the design's "git prints it
     absolute".
   - `git config` prints `.git/config` relative, and prints it the same way
     from a subdirectory (`sub/`). Git chdirs to the top-level first.
   - So in practice the relative case is config-lock (slice 8). Resolving
     against `$2` gives `<repo>/sub/.git/config.lock`, which is absent, so the
     probe reads a false `mask` whenever the payload cwd is a subdirectory.
   - `docs/design.md` ("Paths") and the item text both say "resolves against
     the payload cwd", so the fix is a design and runbook decision, not a
     test-review one. One option is to resolve against
     `git -C "$2" rev-parse --show-toplevel`, or to walk up to the nearest
     `.git`.
   - Proposed test for slice 8 or a new slice: config-lock text naming
     `.git/config`, `$2` = `<repo>/sub` with the lock present at
     `<repo>/.git/config.lock` → `orphan`, `path=<repo>/.git/config.lock`.
2. **`$2` missing.** A correct implementation that reads `$2` under the file's
   `set -u` aborts with `$2: unbound variable` (rc 127 in a `bash -c` run).
   Inside the hook that kills the whole hook process. A payload without `cwd`
   is possible. Proposed test: `probe_git_lock false` with one argument and a
   relative text → exit 0, with a stated outcome.
3. **`$2` empty.** A correct join resolves against `/` and prints `mask` with
   `path=/.git/index.lock`, which is a confident wrong answer. Proposed test:
   `probe_git_lock false ""` with a relative text → `unknown` (or whichever
   outcome the design picks), never `mask`/`gone` naming `/.git/...`. Items 2
   and 3 need the design to choose the outcome for an unresolvable path;
   `unknown` is the natural candidate.
4. **`$2` with a trailing slash** prints `path=<repo>//.git/index.lock`. The
   lookup still works, so this is cosmetic. Proposed test (low value): `$2`
   ending in `/` → `path=` with a single separator. Leave it unpinned unless
   the verdict text displays `path=`.
5. **`./` or `../` segments** — git does not print them for either lock (see
   1), and a join keeps them literally, which the filesystem resolves. Leave
   unpinned.

## Requirements Validation

| Requirement | Status | Evidence |
|---|---|---|
| Item 2.4: "a relative path resolves against `$2`" | Pinned by this slice's test | The decoy in the process cwd rules out cwd resolution, including a cwd-first fallback; `bytes=7` and the absolute `path=` come only from `$2` |
| Slice 7: `orphan`, `path=` absolute | Pinned | outcome, `bytes=7` and `path=$link/.git/index.lock` assertions |
| Slice 2 code review: the probe runs from a cwd unrelated to `$2` | Pinned | `cd "$unrelated"` with a decoy lock |
| FR-11 self-quiet | Satisfied | `matchers.sh < tests/probes.bats` → no output, rc=1 |

## Positive Observations

- The RED run was genuine: the test failed on its own outcome assertion, not
  on a setup error, and the report showed what the SUT actually printed.
- It reuses the `git_lock_error` fragment builder, so self-quiet holds.
- The `path=` assertion is an exact-line `grep -qxF`, so a separator-less join
  and a relative print both fail on it.
