# Review: Item 5.4 slice 1, test review

**Scope**: `tests/probes-readonly-members.bats` case "a resolved refused path
holding a newline gives nopath, not path=" (uncommitted), and
`reports/item-5-4-s1-red.md`. `lib/probes-readonly.sh` was read, not edited.
**Date**: 2026-10-05
**Mode**: review + fix

## Summary

The case is sound evidence for the defect. It fails on its final assertion
against the unchanged SUT, and a correct GREEN would pass it. One gap is
fixed: the guard's trigger was not pinned to the resolved path. A GREEN keyed on
the cwd holding a newline, rather than the joined path, would have passed. A
third half now closes that.

**Overall Assessment**: Ready

## Mechanical check

The suite ran in the foreground, before and after the fix. Both times case 6
was `not ok`, failing on
`[ "$output" = $'nopath\nreadfile=build.out' ]`. That assertion is now at
line 163; before the fix it was at line 153. The failure is an assertion, not
an error and not a pass. Cases 1-5 and 7-12 are `ok`. The RED report's
forged output (`writable`, `path=<tmp>/r`, `readfile=x/a`,
`readfile=build.out`) matches the defect in `item-4-2-s1-code-review.md`
Recommendations 1.

## Wrong-reason analysis

- **Is the newline half's expected output what the nopath branch prints?**
  Yes. The nopath branch, `probe_readonly_path` lines 51-54, prints `nopath` and
  then runs `_readonly_print_facts "$text" "$command" "" "$cwd"`. For
  `cat build.out`, `_readonly_readfile_arg` reads only the command tokens, so it
  yields `readfile=build.out`. There is no merge segment and no
  partial-checkout text, so it returns before `_readonly_git_dir`. A GREEN that
  routes a newline-bearing resolved path to that branch therefore prints exactly
  `nopath⏎readfile=build.out`.
- **Would a wrong GREEN fail it?** Yes, for each of these:
  - Deleting only the `path=` line leaves `writable` on line 1.
  - Stripping or replacing the newline keeps `writable` and changes `path=`.
  - Keeping the first line of the path still prints `writable` and `path=`.
  - Printing `nopath` with no facts tail drops `readfile=build.out`.

  Because the whole output is compared, every forged line is ruled out at once.
- **Runbook wording.** The slice says "no `path=` or `readfile=` line". The test
  expects the legitimate `readfile=build.out`. The runbook's phrase means the
  forged `readfile=x/a`, and its own "whole-output equality against the nopath
  facts the command yields" governs. Choosing `cat build.out` makes the test
  stronger, since it also proves that the nopath facts tail runs. No change.
- **Blank half.** It compares the whole output (`writable`,
  `path=<tmp>/r readfile=x/a`, `readfile=build.out`). An over-broad guard such
  as `*[[:space:]]*` makes the output nopath and fails it.
- **Production reach.** `hooks/annotate.sh` encodes a cwd newline as `\n` in
  jq (line 51) and decodes it with `printf '%b'` (line 70). It then calls
  `"$probe_fn" "$flag" "$cwd" "$command"` with the text on stdin (line 114).
  `run_probe_command probe_readonly_path false <cwd> <command> <text>` makes
  the same call, so a newline-bearing cwd does reach the probe in production.
- **Portability.** `mkdir` of a name with a newline in it already has a
  precedent in case 5, which does it under `make_scratch_repo`. The case calls
  no external tools of its own beyond `mkdir` and `sed`, the latter via
  `readonly_path_text`. Locale is not involved. The file's BSD-stub case is
  case 12, so CLAUDE.md's re-run rule is already met. No issue.

## Issues Found

### Critical Issues

None.

### Major Issues

1. **The guard's trigger was not pinned to the resolved path**
   - Location: `tests/probes-readonly-members.bats`, case 6
   - Problem: Both halves differed only in the cwd, and the refused path was
     always relative. A GREEN of the form "cwd holds a newline → nopath"
     passed. That guard is wrong: an absolute refused path under a
     newline-bearing cwd resolves to a path with no newline, so it must stay
     `writable` with its `path=`. This was confirmed outside the tree: a
     cwd-keyed wrapper prints `nopath⏎readfile=build.out` where the real probe
     prints `writable`, `path=<tmp>/r readfile=x/a`, `readfile=build.out`.
   - Fix: I added a middle half. It uses the absolute refused path `$good/a`
     under the newline cwd `$bad` and expects the same whole output as the blank
     half. That is now held in a shared `expected` variable. The half sits
     before the red assertion, so the RED run proves it passes on the current
     SUT.
   - **Status**: FIXED

### Minor Issues

1. **Comment wording and coverage**
   - Location: the comment above case 6
   - Note: The phrase "put a second line in the path= line" was unclear. "the
     sibling ... resolves" did not say what the blank half guards against.
     The comment now says "split the path= line … after the newline", in
     case 5's wording. It names the over-broad blank guard and the cwd-keyed
     guard that each positive half rules out.
   - **Status**: FIXED

## Fixes Applied

- `tests/probes-readonly-members.bats`, case 6:
  - Added `expected` for the shared positive output.
  - Added the absolute-path half under the newline cwd, before the red
    assertion.
  - Reworded the comment.
- Verification:
  - The suite was re-run in the foreground: case 6 is still red at line 163 on
    `[ "$output" = $'nopath\nreadfile=build.out' ]`, and the other 11 cases are
    `ok`.
  - shellcheck reports only the file's existing SC1091 info at line 22.
  - The only line over 80 columns is the existing line 47.

## Requirements Validation

| Requirement | Status | Evidence |
|-------------|--------|----------|
| Slice 1: newline cwd gives `nopath` line 1, no `path=`, whole-output equality | Satisfied | Case 6 final assertion (line 163) |
| Slice 1: blank twin gives `writable` and `path=<tmp>/r readfile=x/a` | Satisfied | Case 6 first half, whole output |
| FR-4 (A-3 contract: no forged key line) | Satisfied (test side) | Whole-output comparisons in all three halves |

## Positive Observations

- Each half compares the whole output, so no forged line can slip through a
  `grep -qx`.
- The newline name and the blank name differ in exactly one byte.
- The RED report records the actual forged output, which grounds the defect.

## Recommendations

- For code review, which is out of scope here: check that the GREEN guard
  tests the resolved `$path` after `_probe_readonly_resolve`, not `$cwd`. The
  runbook's lock-probe question about `_probe_resolve_path` also stands.
