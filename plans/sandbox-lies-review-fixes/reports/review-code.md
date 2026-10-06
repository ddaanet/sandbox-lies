# Review: finishing gate, group "code" — sandbox-lies-review-fixes

**Scope**: `git diff a7ff5e5 -- lib hooks justfile tests`, as the tree now
stands. In scope: the code and test deliverables of runbook Items 2.1–2.5,
3.1–3.4, 4.1–4.3, 5.3's comment edits, 5.4 and 5.5, reviewed against outline
D1–D5 and the runbook. Out of scope: docs, `skills/`, the main session's
commits (`0bbb18c`, `161d958`, `11b96a4`/`533dca7`; this covers `justfile`'s
`tracked()` and `.bin/*` hunks and the deleted `tests/shim.bats`, which took
Item 3.1's deliverable with it), the outline's OUT list, and a `path=` encoding
that can carry newlines.
**Date**: 2026-10-06
**Mode**: review + fix

## Summary

The per-phase reviews checked each item on its own. This pass looked at what
they could not see:

- the A-3 seam: `lib/probes*.sh` producers against `lib/verdicts.sh` and the
  `hooks/annotate.sh` split;
- interactions between items: 4.1's operand rule against 2.4's pins, 4.2's
  absolute `match=` against 5.4's nopath branch, and 5.5's omitted `path=`
  against 3.4's `path=` pins;
- duplicated helpers;
- walk-up dependence in real-probe cases.

The contract holds across every surface. With `path=` omitted, `mask`/`gone`
reach the verdict through the hook's no-newline branch. `verdict_config_lock`
keeps *Re-run*, and `_verdict_lock_present` ignores `path=`.

`probe_readonly_path` resolves the path before it tests for emptiness. An empty
path still resolves to empty, so `nopath` is unchanged.

Item 3.4's `path=` pins still hold under 5.5's guard: an empty path has no
newline, so `path=` is still printed.

I probed the D4 operand rule on its own against every residual
`readonly-path.md` lists, and each output matches what the doc says.

I found one major issue and four minor ones, and fixed all five. `just
precommit` exits 0.

**Overall Assessment**: Ready

## Issues Found

### Critical Issues

None.

### Major Issues

1. **A real-probe hook case passes on any code when a `.git` sits above the
   test temp dir**
   - Location: `tests/hook-locks-pathless.bats`, "real config-lock probe: a
     newline-bearing cwd forges no settings path"
   - Problem: the fixture names the relative `.git/config`.
     `_probe_resolve_path` walks up from the newline-bearing cwd, and the
     first ancestor that holds a `.git` directory takes the join.
     - The walk passes through `$BATS_TEST_TMPDIR` and its ancestors. If any of
       them holds a `.git`, the resolved lock path contains no newline and the
       Item 5.5 guard is never exercised.
     - The probe then prints a real `path=`, which is not the settings path, so
       the case still passes.
     - Item 3.3's rule covers exactly this case: a real-probe case whose
       expected output depends on the walk-up finding nothing must call
       `assert_no_git_above` first. The case was added in Item 5.5, after Item
       3.3, and does not.
   - Fix: load `helpers/probes`, call `assert_no_git_above "$BATS_TEST_TMPDIR"`
     at the top of the case, and add a comment saying why. I re-ran the case
     with `TMPDIR` set inside a scratch directory that holds a `.git/`, and it
     now fails on that assertion.
   - **Status**: FIXED

### Minor Issues

1. **A mid-body `[[ ]]` assertion is a no-op on bash < 4.1**
   - Location: `tests/check-jq.bats` `assert_notice`, the raw-ESC check.
   - Note: bash 3.2, the macOS bash that NFR-2 targets, does not apply errexit
     to a failing `[[ ]]`. Mid-body, the check therefore asserts nothing there.
     It is the only mid-body `[[ ]]` in any suite.
   - Fix: replaced it with `[ "${output#*"$esc"}" = "$output" ]`, plus a
     comment. Checked both ways: the expression fails on a string with a raw
     ESC and passes on one with the `\u001b` escape.
   - **Status**: FIXED
2. **`assert_lacks` was duplicated across two hook suites**
   - Location: `tests/hook-locks.bats`, `tests/hook-locks-pathless.bats`
   - Note: Item 5.5's split copied the helper verbatim into the new file.
   - Fix: moved it to `tests/helpers/hook.bash`, which both files already load,
     with the same `SC2154` disable `helpers/verdicts.bash` uses for `$status`.
     Removed it from both suites. `hook-locks.bats` drops from 399 to 391
     lines.
   - **Status**: FIXED
3. **`hook-locks-pathless.bats` header misdescribed one of its cases**
   - Location: `tests/hook-locks-pathless.bats:2-6`
   - Note: the header said the probe output "has no newline". That holds for
     `mask`/`gone`, but the `held` case keeps its `pid=` line and takes the
     newline branch. The header also gave hook-locks.bats's line count as
     current, and it no longer is.
   - Fix: the header now says which outcomes take the no-newline branch, and
     gives the 399 count as the state at the split.
   - **Status**: FIXED
4. **`tests/corpus-eval.py` comment left unwrapped**
   - Location: `tests/corpus-eval.py:50-52`
   - Note: the citation edit in Item 1.1 left a 91-column line in a paragraph
     wrapped at 80.
   - Fix: re-wrapped. No change to the content.
   - **Status**: FIXED

## Fixes Applied

- `tests/hook-locks-pathless.bats`:
  - loads `helpers/probes`;
  - the real-probe case calls `assert_no_git_above "$BATS_TEST_TMPDIR"`, with a
    comment saying why;
  - header corrected;
  - local `assert_lacks` removed.
- `tests/helpers/hook.bash`: `assert_lacks` added. It is the shared copy, and
  it carries the `SC2154` disable.
- `tests/hook-locks.bats`: local `assert_lacks` removed.
- `tests/check-jq.bats`: the `[[ ]]` raw-ESC check is now `[ ]`, with a comment.
- `tests/corpus-eval.py`: comment re-wrapped.

Gate: `just precommit`, run in the foreground, exited 0. It reported
`bats: 309 passed, 0 failed` and listed every check as passed: plugin.json,
hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests.

## Requirements Validation

| Requirement | Status | Evidence |
| --- | --- | --- |
| FR-3 (2.1) | Satisfied | `tests/hook-malformed.bats` has three dying-after-output cases. Each is paired with `check_fires`, and two also check that the marker was reached. |
| NFR-4 (2.2) | Satisfied | `tests/hook-writes.bats` covers the readonly and git-lock real probes plus a BSD re-run. `tests/probes-edges.bats` adds "readonly-path probe writes nothing". |
| FR-7 (2.3) | Satisfied | `tests/matchers-edges.bats` adds a curly-quote fire/near-miss case and a tab-indented untracked block. |
| FR-4 (2.4, 3.4) | Satisfied | `tests/probes-readonly-members.bats` holds the members. `tests/probes-config.bats` adds positive `mask`/`gone` + `path=` assertions. |
| FR-5 (2.5) | Satisfied | `tests/hook-candidates.bats` has two sweeps over the fixtures, plus a case with the string `"true"`. |
| NFR-5 (3.2) | Satisfied | `check-line-limits.bats` and `check-links-edges.bats` cover the exit-2 paths. |
| NFR-2 (3.3) | Satisfied | `tests/helpers/git-env.bash` is loaded by every suite that runs git (checked by grep). The walk-up guard is now also in hook-locks-pathless (Major 1). |
| D-16 (3.1) | Out of scope | The shim and its suite were removed by `0bbb18c`. |
| FR-4 / D4 (4.1) | Satisfied | `_readonly_readfile_arg`, with `tests/probes-readonly-operands.bats`. Every documented residual was reproduced by a direct probe. |
| FR-4 / D3 (4.2) | Satisfied | `_readonly_repo_facts` prints `match=${repo}/…`, and `_readonly_git_dir` strips trailing slashes. Both are pinned by direct-probe and hook cases. |
| NFR-2, D-12, FR-1 / D2 (4.3) | Satisfied | `hooks/check-jq.sh` and the `SessionStart` registration, with `tests/check-jq.bats` and the extended case in `tests/hook.bats`. |
| hygiene (5.3) | Satisfied | Comments in `lib/matchers.sh`, `lib/probes.sh` and `hooks/annotate.sh`, and the `justfile` `[doc]` attribute. Each was checked against the code. |
| FR-4 (5.4) | Satisfied | `probe_readonly_path` reports a resolved path that holds a newline as `nopath`. `_readonly_repo_facts` has the root-newline guard. Pinned with the blank twin and an absolute-path control. |
| FR-4 (5.5) | Satisfied | `_probe_lock_at` has one guard read by all six print sites. `tests/probes-lock-newline.bats` covers five of them, and `tests/hook-locks-pathless.bats` covers the hook level. |

**Gaps:** none in scope.

## Positive Observations

- 5.5's `${pathline:+"path=$path"}` is safe for blanks: the quoted inner word is
  never split. The `r age=99999 x` blank twins test this directly.
- Every negative in the new suites is paired, in the same case, with a positive
  that differs only in the trigger, as in the `uniq`, `sort -o`, `awk -i` and
  newline-twin cases.
- The cross-file contract comments now agree. The `lib/probes.sh` header,
  `_probe_lock_at`'s comment, `verdict_config_lock`'s "or none" and the
  `probe_readonly_path` header each describe the same omitted-`path=` behaviour.
- Every new suite loads `helpers/bsd-stubs` and keeps one `make_bsd_stubs`
  re-run. Every lib, hook and bats file is at or under 400 lines.

## Recommendations

- `assert_no_git_above` lives in `helpers/probes`, but hook suites now need it
  too. If a third hook suite runs a real probe on a relative lock path, move it
  to a helper both families load.
