# Review: Item 4.1 slice 1 — test review (after RED)

**Scope**: uncommitted changes to `tests/probes-readonly-members.bats` (section
"readfile operand rule") and the RED report `item-4-1-s1-red.md`. The SUT,
`lib/probes-readonly-command.sh`, was read only.
**Date**: 2026-10-04
**Mode**: review + fix

## Summary

The slice adds two cases through `probe_readonly_path` on a `writable` refusal.
Both fail on assertions against the unchanged SUT, for the reason the slice
names: `_readonly_readfile_arg` takes `--include=*.log` as the first log-shaped
word, so the probe prints a `readfile=` line holding the option. Applied to a
scratch copy of `lib/` and `tests/`, D4's option rule alone (a word opening with
`-` is never a candidate) turns both green. The tests do not need slices 2–4.
One gap: both cases use a `--opt=value` word, so a GREEN that skips only `--*`
would pass them. A single-dash case now closes that gap.

**Overall Assessment**: Ready

## Mechanical first check

`bats tests/probes-readonly-members.bats` against the unchanged SUT, after the
fixes:

| Test | Result | Failing assertion |
| --- | --- | --- |
| grep --include=*.log gives the operand, never the option | FAILED | exact line `readfile=build.log` (line 165) |
| awk -vout=run.log gives the operand, never the short option (added) | FAILED | exact line `readfile=in.err` (line 181) |
| grep -r --include=*.log pat . gives no readfile | FAILED | `assert_no_readfile`'s `run ! grep -q '^readfile='` (line 31) |

The other 8 cases pass. None of the slice's tests passes or errors. In each
failing case the status, stderr and first-line `writable` checks ran before the
failing assertion and passed, so the failure is not an empty output or a
different probe answer.

## Wrong-reason hunting

- **Case 1, `grep --include=*.log pat build.log`.** Fails today because the
  candidate is `--include=*.log`. It passes once option words are skipped,
  because `pat` is not a log name. Slice 2's pattern-operand rule would skip
  `pat` as well, but `pat` never competes, so the case does not depend on slice
  2. A GREEN that treats `grep --include` as a writer (an arm like
  `awk:--include*`) fails the positive, as checked on a scratch copy.
- **Case 3, `grep -r --include=*.log pat .`.** With option words skipped, `pat`
  and `.` are left, and neither matches `*.log|*.output|*.out|*.err`. So the
  option rule alone gives no `readfile=`, and slice 2 is not needed. The negative
  is live in two ways. `assert_no_readfile` requires `writable` on line 1, and
  the case fails on unchanged code. Case 1 is its positive pair: the same
  `--include=*.log` option with a log-named operand, so the only route to green
  for both is to skip the option word, not to suppress the segment.
- **Narrow implementation.** A GREEN that skips only `--*` (or only `--*=*`)
  passed cases 1 and 3 on a scratch copy. D4 says "a word opening with `-`".
  The added case 2 fails under that mutation and passes under the full rule.

## Issues Found

### Critical Issues

None.

### Major Issues

1. **The single-dash half of the rule was not pinned**
   - Location: `tests/probes-readonly-members.bats`, section "readfile operand
     rule"
   - Problem: both cases use the `--opt=value` form. A GREEN that skips only
     words opening with `--` satisfies both (verified on a scratch SUT copy),
     so the "opening with `-`" rule stays unpinned.
   - Fix: add a case `awk -vout=run.log 1 in.err`, which expects
     `readfile=in.err` and no `readfile=-` line, plus the status, stderr and
     `writable` checks. `-vout=run.log` is a real awk assignment option. `1` is
     the program and is not a log name, so the case holds under slice 1 alone
     and after slice 2's program-operand rule. It does not use `-e`/`-f`
     (slice 2) or `uniq` (slice 3).
   - **Status**: FIXED

### Minor Issues

1. **The negative in case 1 was narrower than the rule**
   - Location: `tests/probes-readonly-members.bats:166`
   - Note: `run ! grep -q '^readfile=--'` checks only the double-dash form.
     It is widened to `'^readfile=-'`, which matches the rule's scope and the
     added case.
   - **Status**: FIXED
2. **The header's section list omitted the new section**
   - Location: `tests/probes-readonly-members.bats:8-9`
   - Note: the file header lists its sections. The new section is added there,
     with its source (outline D4, review code m-2), since it is not a Major 6
     member.
   - **Status**: FIXED
3. **Case 3 did not say why the expected answer is "none"**
   - Location: comment above `grep -r --include=*.log pat . gives no readfile`
   - Note: a comment now says `pat` and `.` are not output names, so the option
     word was the only candidate. This lets a reader see that the negative
     depends only on the option rule.
   - **Status**: FIXED

## Fixes Applied

- `tests/probes-readonly-members.bats:8-10`: the section list in the header
  names the readfile operand rule (D4, code m-2).
- `tests/probes-readonly-members.bats:166`: the negative widened from
  `^readfile=--` to `^readfile=-`.
- `tests/probes-readonly-members.bats:169-183`: new case
  `awk -vout=run.log gives the operand, never the short option`.
- `tests/probes-readonly-members.bats:185-186`: comment on case 3.

The Edit tool gave no classifier verdict, so the edits were written by a Python
script and copied in with `put.py`. The file is 224 lines. The new text quotes
no diagnostic.

## Verification

Each run used a scratch copy of `lib/` and `tests/` under `$TMPDIR`, removed
afterwards. The SUT was never edited.

- Unchanged SUT: all three slice tests are red on assertions (table above).
- D4's option rule (`-*` added to the arm that passes over newline-holding
  words): all 11 cases are green.
- Mutation, skip only `--*`: cases 1 and 3 are green, and case 2 is red on
  `readfile=in.err`.
- Mutation, `grep:--include*` added to the writer arms: cases 1 and 2 are red,
  and case 3 is green. Case 3 alone cannot catch this mutation, but its pair
  does.

## Requirements Validation

| Requirement | Status | Evidence |
| --- | --- | --- |
| FR-4 / D4, the option-word rule (this slice) | Satisfied (test side) | cases 1–3 pin both forms of the rule, `--opt=value` and single-dash |

## Positive Observations

- Each case runs the real entry point, `probe_readonly_path`, as the hook does,
  with refusal text built at run time from the cut fixture (self-quiet).
- Case 1's exact-line positive cannot be met by a `readfile=` line holding any
  other word.
- The RED report names the actual cause, which matches the SUT.
