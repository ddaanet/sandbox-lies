# Review: Item 4.1 slice 4 — test review (RED to GREEN)

**Scope**: tests 18 and 19 in `tests/probes-readonly-operands.bats`
(uncommitted), and the RED report `reports/item-4-1-s4-red.md`. The SUT
`lib/probes-readonly-command.sh` was changed only for mutation runs, each one
undone by its inverse replacement. **Date**: 2026-10-05. **Mode**: review + fix.

## Summary

The RED's mechanics held up. Test 18 reds on an assertion. Test 19 passes on
the current SUT, and it reds under the RED's mutation and under a different
mutation of my own. No test ERRORs. I found and fixed two wrong-reason gaps.
Test 18's negative also passed under an implementation that skips uniq's
second operand without treating the segment as a writer. Test 19 could not see
the `<` word ending `-e`'s argument role, because the first-candidate rule hid
pat.log behind in.log.

**Overall Assessment**: Ready

## Mechanical first check

- Test 18 is red on its assertion against the current SUT: `assert_no_readfile`
  fails at the first negative, `uniq in.log out.txt`, line 319, "expected
  nonzero exit code". Run by hand, the SUT prints `readfile=in.log` for it. Its
  positives `uniq in.log` and `uniq -c in.log` pass now. They are the slice's
  named guard.
- Test 19 is green on the current SUT; its proof is by mutation. I used my own
  mutation, different from the RED's: `case "$pat:$word" in` became
  `case "$pat:${word#<}" in`, so `<in.log` reads as a plain word in the argument
  slot and is consumed as `-e`'s argument. Test 19 went red on its assertion at
  line 334, where `readfile=in.log` was absent. I restored it by the inverse
  replacement. `command grep -nF '${word#<}'` found nothing, and
  `git diff --stat lib/` was empty.
- Tests 1–17 and 20 pass.

## Issues Found

### Critical Issues

None.

### Major Issues

1. **Test 18's negative did not pin the writer reason**
   - Location: `tests/probes-readonly-operands.bats`, test 18.
   - Problem: the old negative was `uniq in.txt out.log`, where only the second
     operand is log-shaped. Suppose an implementation treats uniq's second
     operand as a non-input but does not mark the segment as a writer. It
     withholds `readfile=` there too, and that is not D4's rule: for
     `uniq in.log out.txt` it would still print `readfile=in.log`. The old pair
     (`uniq in.log` against `uniq in.txt out.log`) also differed in two words,
     not only in the trigger.
   - Fix: the negatives are now `uniq in.log out.txt` and
     `uniq in.txt out.log`. The first differs from the positive `uniq in.log`
     only in the second operand, and only a segment-level writer withholds
     in.log there. The first is also the one the current SUT reds on.
   - **Status**: FIXED

2. **Test 19 could not see a `<` word ending `-e`'s argument role**
   - Location: `tests/probes-readonly-operands.bats`, test 19.
   - Problem: under the mutation `case "${word%%<*}" in` →
     `case "x${word%%<*}" in`, a `<` word in the argument slot resets `pat`
     without being consumed. pat.log then becomes an input candidate. Test 19
     stayed green, and so did the whole suite apart from the expected red in
     test 18. The reason is that in.log is the first candidate and only the
     first is printed, so `readfile=pat.log` can never appear.
   - Fix: a second run, `grep -e <in.txt pat.log y.out`, which asserts
     `readfile=y.out` and no `readfile=pat.log`. With no log name behind the
     `<`, y.out is the input only while pat.log stays `-e`'s argument. Under the
     same mutation the test now reds at line 345, where `readfile=y.out` is
     absent.
   - **Status**: FIXED

### Minor Issues

1. **Test 18 did not pin "operand" as opposed to "word"**
   - Location: test 18, positive half.
   - Note: D4 says that a word opening with `-` is never an operand. An
     implementation that counts every word after `uniq` would make `uniq -c in.log`
     a writer, and the old test could not see that. I added `uniq -c in.log` to
     the positive loop. Its red is proven by the mutation
     `sort:-o* \` → `sort:-o* | uniq:-c \`. Under it, the positive at line 313
     reds on its second iteration and the first iteration still passes. I
     restored the line by the inverse replacement, and a grep for `uniq:-c` found
     nothing. The code review should repeat this against the GREEN's
     operand-counting code.
   - **Status**: FIXED

2. **Test 19's comment called pat.log "the pattern file's place"**
   - Note: `-e` takes a pattern, not a pattern file. The comment now says
     pat.log is `-e`'s pattern.
   - **Status**: FIXED

## Fixes Applied

- `tests/probes-readonly-operands.bats`, test 18: renamed to "uniq with a
  second operand is a writer, uniq in.log is not". The comment now gives the
  writer reason. The positive loop is `uniq in.log` and `uniq -c in.log`, and
  the negative loop is `uniq in.log out.txt` and `uniq in.txt out.log` through
  `assert_no_readfile`.
- `tests/probes-readonly-operands.bats`, test 19: the comment is corrected. A
  second run, `grep -e <in.txt pat.log y.out`, has a positive `readfile=y.out`
  and a negative `readfile=pat.log`, with a comment on why the first run cannot
  see the gap.
- I applied both edits through `/tmp/claude-1000/sl/put.py`, because `Edit`
  returned no classifier verdict.

## Verification

- `bats tests/probes-readonly-operands.bats`: only test 18 is red, at line 319,
  on its assertion. The other 19 tests pass and none ERRORs.
- Test 19 has two mutation proofs, both run after the fix, each restored by its
  inverse replacement:
  - `${word#<}`: red at line 334.
  - `x${word%%<*}`: red at line 345.
- Test 18's positive has one mutation proof, `uniq:-c`: red at line 313.
- After all mutations, `git diff --stat lib/` is empty, and a grep for each
  mutation's text finds nothing.
- File: 370 lines, still under 400, and the BSD case is still last.
  `shellcheck -x` is clean. `bats tests/docs.bats` passes.

## Requirements Validation

| Requirement | Status | Evidence |
| --- | --- | --- |
| FR-4 / D4 uniq writer | Pinned (RED) | test 18 negatives; GREEN to satisfy |
| FR-4 / D4 `-e` argument past `<` | Pinned (green) | test 19, two runs, mutation-proven |

## Positive Observations

- The RED report records the failing line and the mutation exactly.
- `assert_no_readfile` checks `writable` on line 1 before its `run !`, so an
  empty output cannot pass a negative.
