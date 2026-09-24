# Review: Item 2.4 / slice 1 — test review

**Scope**: `tests/probes.bats` (slice 1 test), the RED report
`item-2-4-s1-red.md`; `lib/probes.sh` for stub completion only.
**Date**: 2026-09-24
**Mode**: review + fix (test review, TDD slice)

## Summary

The RED test failed on its own assertion. It had three wrong-reason gaps: the
`path=` check matched a substring, `$2` let the path be built from cwd, and the
exit/stderr contract was not asserted. All three are fixed in the test. The
stub needed no change. The test is still red on its line-1 assertion.

**Overall Assessment**: Ready

## Mechanical check

The RED report's run has 1 test, FAILED on an assertion (line-1 `= "mask"`).
None PASSED and none ERRORED. I re-ran it myself in the foreground before any
edit and got the same result:

```
not ok 1 absent lock, sandboxed, is mask
# (in test file tests/probes.bats, line 36)
#   `[ "$(printf '%s\n' "$output" | sed -n '1p')" = "mask" ]' failed
bats: 0 passed, 1 failed
```

Self-quiet: `bash lib/matchers.sh < tests/probes.bats` gives no output and
exit 1, both before and after the fixes. The same holds for `lib/probes.sh`.
The follow-on sentence is absent. The `Unable to create` line is built from
two fragments.

## Issues Found

### Critical Issues

None.

### Major Issues

1. **`path=` assertion was a substring match**
   - Location: tests/probes.bats (old line 37)
   - Problem: `grep -qF "path=$lock"` matches anywhere in a line.
     `path=$lock.bak`, `oldpath=$lock` and `path=$lock<anything>` all passed.
   - Fix: `grep -qxF "path=$lock"`, an exact whole-line match.
   - **Status**: FIXED

2. **`path=` could be built from `$2` instead of the error text**
   - Location: tests/probes.bats (old line 34, `probe_git_lock false "$repo"`)
   - Problem: `$2` was the repo directory. A probe that ignored stdin and
     printed `path=$2/.git/index.lock` passed. The item's rule is "Path from
     the error text".
   - Fix: `$2` is now an unrelated directory, `$BATS_TEST_TMPDIR/elsewhere`.
     This is realistic, since git prints the lock path absolute whatever the
     cwd. The only source of the path is now the error text. Slice 7 keeps
     the cwd-resolution case.
   - **Status**: FIXED

3. **Exit status and stderr were not asserted explicitly**
   - Location: tests/probes.bats (old line 34)
   - Problem: the interface says "exit 0". The old `output=$(…)` assignment
     enforced that only implicitly, through bats' errexit on the
     substitution's status. Nothing pinned the item's "guard the expected
     absence first" rule. A probe that runs `stat` on the absent lock prints
     a tool error on stderr, and the old test passed it.
   - Fix: added a `run_probe` helper (`run --separate-stderr`, text through a
     here-string) and the assertions `[ "$status" -eq 0 ]` and
     `[ -z "$stderr" ]`. Keeping stderr separate also stops stderr from
     shifting the token off line 1.
   - **Status**: FIXED

### Minor Issues

1. **The test assigned bats' own `output` variable**
   - Location: tests/probes.bats (old line 30, `local … output`)
   - Note: it was `local`, so harmless here. But it shadows the name `run`
     populates, and later slices will use `run`. The fix for Major 3 removes
     it: `$output` now comes from `run`.
   - **Status**: FIXED

2. **Line 1 was read with a `printf | sed` subshell**
   - Location: tests/probes.bats (old line 36)
   - Note: it was correct, but I replaced it with `${output%%$'\n'*}`, which
     is pure bash and bash 3.2-safe. The helper comment explains why
     `${lines[0]}` is avoided: bats drops empty lines from `lines`, so a
     blank first line followed by `mask` would pass.
   - **Status**: FIXED

## Wrong-reason hunt: answers to the dispatch's questions

- **`mask` for every input**: this passes slice 1 by construction and can't
  be ruled out within this slice. Slice 2 (flag `true` → `gone`, same text)
  and slice 3 (`orphan`) are the discriminators. I'm not raising it as a
  finding.
- **Line 1 exact**: yes. `= mask` compares the whole first line, so `masked`
  fails, and so does a blank line before `mask`.
- **Is the lock really absent?** Yes. `$BATS_TEST_TMPDIR` is fresh for each
  test, only `r/.git` is created, and nothing writes `index.lock`.
- **Bats pitfalls**: there is no bare `!` and no `${n:-default}` in the
  helper. `[ ]` lines that fail mid-body abort under bats' errexit. The
  final `printf | grep` pipeline gives grep's status, and there is no
  pipefail/SIGPIPE issue. BSD sed is no longer used.
- **Discrimination, checked empirically.** I ran the fixed test against fake
  `probe_git_lock` bodies in a scratch copy under `$TMPDIR`, using real
  `bats` and leaving the tracked stub untouched:

  | Variant | Result |
  |---|---|
  | extract path, print `mask` + `path=<path>` | PASS |
  | `path=<path>.bak` | FAIL |
  | `oldpath=<path>` | FAIL |
  | ignore stdin, `path=$2/.git/index.lock` | FAIL |
  | blank line, then `mask` | FAIL |
  | unguarded `stat` on the absent lock | FAIL (stderr) |
  | correct output, `return 3` | FAIL (status) |
  | line 1 `masked` | FAIL |

## Structure for slices 2–9

The structure fits the later slices without rework:

- `run_probe <probe> <flag> <cwd> <text>` covers both probes and both flags.
- `git_lock_error` builds the text for slices 2–7 and 9.
- Slice 8 adds a sibling helper for config-lock, built from fragments in the
  same way.
- Slice 4 adds a `teardown` for the background holder. Slice 6 sets `PATH`
  inside its own test.
- `setup` only sources the SUT.

## Fixes Applied

- tests/probes.bats: added `run_probe` helper (`run --separate-stderr` with
  here-string stdin) with a comment on stderr separation and why `lines` is
  avoided.
- tests/probes.bats: slice 1 test now uses an unrelated `$2`
  (`$BATS_TEST_TMPDIR/elsewhere`) and has a comment on why.
- tests/probes.bats: asserts `status` 0, empty `stderr`, line 1 exactly
  `mask`, and an exact-line `path=<lock>` (`grep -qxF`).
- lib/probes.sh: unchanged. The stub is importable and inert, and no ERROR
  showed.

## Requirements Validation

| Requirement | Status | Evidence |
|---|---|---|
| A-3 contract: line 1 token, `key=value` lines, exit 0 | Pinned by test | status, line-1 and `path=` assertions |
| Path from the error text | Pinned | unrelated `$2` |
| No stderr noise (guard absence first; no-stderr-suppression) | Pinned for the absent case | `[ -z "$stderr" ]` |
| FR-11 self-quiet | Holds | `lib/matchers.sh` gives no output, exit 1 |
| NFR-2 (test side) | Holds | no GNU sed, `-x`/`-F` are POSIX grep |

## Final red output

`cd /Users/david/code/sandbox-lies && scripts/run-bats.sh tests/probes.bats`

```
not ok 1 absent lock, sandboxed, is mask
# (in test file tests/probes.bats, line 50)
#   `[ "${output%%$'\n'*}" = mask ]' failed

bats: 0 passed, 1 failed
```

Red on the line-1 assertion: the stub prints nothing. `status` is 0 and
`stderr` is empty, so the earlier assertions pass and the failure is the
token itself. `shellcheck tests/probes.bats lib/probes.sh` is clean.

## Recommendations

- No slice covers a lock path containing whitespace. Extraction splits on
  `'`, not whitespace, but nothing pins that. This slice's path is fixed by
  the slice text, so I haven't changed it here. Consider adding a spaced
  directory to a later slice (for example, slice 3's fixture tree). This is
  for the orchestrator's slice list.
