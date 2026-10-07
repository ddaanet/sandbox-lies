# Review: Item 2.1 / slice 1 tests (m-11 glob and `$` skip)

**Scope**: `tests/probes-readonly-globs.bats` and the RED report
`reports/item-2-1-s1-red.md`. The SUT (`lib/`) was OUT and is unchanged
(`git status --short lib` and `git diff --stat -- lib` both empty after the last
restore). **Date**: 2026-10-07 **Mode**: review + fix (TDD test review, dispatch
`item-2-1-s1-test-review`)

## Summary

The RED suite had six cases. Its five negatives were genuine reds on assertions,
and its over-broad-skip guard (case 5) was reproduced with a different mutation.
A plausible misplaced skip, one that also covers the grep pattern, survived all
six cases. So did a `$` rule that rejects the whole command. Each survivor now
has its own case, shown red under that mutation. The file was also missing the
BSD re-run that `CLAUDE.md` requires, and the "quoted or not" clause had no
case. The suite now has ten cases: eight red on their assertions against the
unchanged code, and two (5 and 8) green by design, each mutation-proven. With a
contract-shaped skip applied to the code, all ten pass, and
`tests/probes-readonly-operands.bats` still passes (20/20).

**Overall Assessment**: Ready

## Mechanical check (unchanged code, as received)

Run with `scripts/run-bats.sh tests/probes-readonly-globs.bats`: 1 passed and 5
failed, which matches the RED report.

- Cases 1-4 fail in `assert_no_readfile` at its `run ! grep -q '^readfile='`
  line (`tests/helpers/probes.bash:248`). Each fails at its own negative line:
  35, 44, 53, 62.
- Case 6 fails at line 84 (`readfile=x.err` absent).
- Nothing errored.
- Case 5 passed. It is listed under the RED report's `Mutation proof`, so it was
  reproduced with a different mutation (M1 below). The positive halves of cases
  1-4 and 6 are listed there too, and the same run reproduces each of them.

`$` reaches the scan. The commands are single-quoted in the test source. Calling
`_readonly_tokenize 'cat $OUT.log'` gives the tokens `wcat` and `w$OUT.log`, and
today's readfile value is `$OUT.log`. Neither the test shell nor the tokenizer
expands or drops the `$`.

## Issues Found

### Critical Issues

None.

### Major Issues

1. **A skip placed ahead of the pattern rule passes every case**
   - Location: `tests/probes-readonly-globs.bats` (no case had a metacharacter
     outside the candidate)
   - Problem: suppose the skip is a `continue` on any word holding a
     metacharacter, before the pattern handling (mutation M2). Then
     `grep 'err.*$' x.log` skips the pattern, and `x.log` takes the pattern
     role, so no readfile= is printed. That breaks the most common grep shape,
     yet all six RED cases still passed: under M2, the RED cases 1-6 gave 6/6
     green. Case 5 cannot catch it, because `cat x.log` has no metacharacter
     anywhere.
   - Fix: a new case 8,
     `a metacharacter in grep's pattern leaves readfile=x.log`, with an exact
     readfile-line assertion.
   - **Status**: FIXED. Under M2, case 8 reds at line 110 and the other nine
     cases pass, so case 8 alone pins the placement.

2. **A `$` rule that rejects the whole command passes case 2**
   - Location: case 2 (`cat $OUT.log`)
   - Problem: the contract says a candidate holding `$` is skipped and a later
     literal is still taken. Suppose an implementation instead sets `all_ok=0`
     for a `$` word, the reasoning being that an expansion may hide a writer
     (M3). That also prints no readfile=, so case 2 passes. Case 6 tests the
     later-literal half only for `*`.
   - Fix: a new case 7,
     `a skipped $ expansion does not hide a later literal candidate`. It pairs
     `cat OUT.log x.err` (gives `readfile=OUT.log`) with `cat $OUT.log x.err`,
     whose readfile lines must be exactly `readfile=x.err`.
   - **Status**: FIXED. Case 7 is red on the unchanged code at line 100. Under
     M3, case 2 passes and case 7 reds at line 100.

3. **No BSD re-run case**
   - Location: whole file
   - Problem: `CLAUDE.md` asks for one case re-run with `make_bsd_stubs` on
     `PATH`. Q5's narrowed rule still applies, since `probe_readonly_path` calls
     `sed` (`lib/probes-readonly.sh:134`). The file loaded `helpers/bsd-stubs`
     but never called `make_bsd_stubs`.
   - Fix: a new case 10, `the glob skip survives BSD grep, sed, stat and wc`. It
     runs case 6's pair through the stubs, the same way
     `probes-readonly-operands.bats` does for its own rule.
   - **Status**: FIXED. Case 10 is red on the unchanged code at line 142, on its
     assertion.

### Minor Issues

1. **The "quoted or not" clause was unpinned**
   - Location: whole file
   - Note: Q4's rule skips a quoted `*.log` too, and Item 5.3 documents that as
     the safe-side residual. No case held a quoted candidate, so a later
     quote-aware scan could change this documented behaviour silently.
   - Fix: a new case 9, `a quoted '*.log' is skipped too`. It pairs
     `grep -l pat 'x.log'` (gives readfile=) with `grep -l pat '*.log'` (gives
     none).
   - **Status**: FIXED. Case 9 is red on the unchanged code at line 121, in
     `assert_no_readfile`.

2. **Case 6's trailing negative restated its positive**
   - Location: case 6, `run ! grep -qxF 'readfile=*.log'`
   - Note: the probe prints at most one readfile= line. Once `readfile=x.err` is
     present, the `*.log` negative cannot fail on its own.
   - Fix: both lines are replaced with one exact assertion, that the readfile=
     lines are exactly `readfile=x.err`.
   - **Status**: FIXED. Still red on the unchanged code, at line 85 (the new
     assertion).

3. **Intentional single-quoted `$` flagged by shellcheck SC2016**
   - Location: the `cat $OUT.log` lines in cases 2 and 7
   - Note: the shellcheck hook reported both.
   - **Status**: FIXED, with an inline
     `# shellcheck disable=SC2016 # the literal $OUT is the command's text`,
     following the existing style in `tests/check-jq.bats`.

### Checked, no finding

- **Pairing.** Each negative shares its case with a positive of the same command
  shape, differing only in the metacharacter: `x.log`/`*.log`,
  `OUT.log`/`$OUT.log`, `run1.log`/`run?.log`, `run1.log`/`run[12].log`,
  `a.log`/`*.log`. `assert_no_readfile` also requires status 0, empty stderr and
  a first line of `writable`, so an empty or rejected probe cannot pass a
  negative.
- **Each metacharacter pins its own case.** M5 drops `?` from an otherwise
  correct skip class, and only case 3 reds.
- **Skipping every candidate after a glob, or aborting the scan at one (M4),**
  reds cases 6, 7 and 10.
- **Skipping any word with a metacharacter anywhere in the command** reds cases
  6, 7 and 8 (see M2).
- **Generic-wording fallback.** With no readfile= line, `lib/verdicts.sh:174`
  takes the else branch. `tests/verdicts-readonly.bats` already pins that branch
  ("readonly-path with no facts states the plain re-run act"), so a probe-level
  absence is the right observable here.
- **`helpers/bsd-stubs`** is loaded.
- **Test names.** Every name states what its case asserts. Case 5's name is
  accurate: it guards against a skip that catches plain names (M1). The
  pattern-side over-skip guard is case 8.
- **Fixture.** It is the cut `fire-readonly-path-cp-tmp`, unchanged and shared
  with the operands suite.

## Per-test evidence (after fixes)

Final run on the unchanged code: 2 passed, 8 failed, no errors.

| # | Case | Unchanged code | Fails when | Else could produce the observable |
| --- | --- | --- | --- | --- |
| 1 | `grep -l pat *.log` | red, line 35 | `readfile=*.log` printed | none: positive half over the same shape, `writable` check |
| 2 | `cat $OUT.log` | red, line 45 | `readfile=$OUT.log` printed | whole-command rejection (M3), now caught by case 7 |
| 3 | `cat run?.log` | red, line 54 | `readfile=run?.log` printed | none (M5 shows it owns `?`) |
| 4 | `cat run[12].log` | red, line 63 | `readfile=run[12].log` printed | none |
| 5 | `cat x.log` | green (guard) | skip catches plain names | M1 reds it |
| 6 | `grep pat *.log x.err` | red, line 85 | glob kept, or scan aborted | none: exact readfile lines |
| 7 | `cat $OUT.log x.err` | red, line 100 | `$` kept, or command rejected | none |
| 8 | `grep 'err.*$' x.log` | green (guard) | skip reaches the pattern | M2 reds it |
| 9 | `grep -l pat '*.log'` | red, line 121 | quoted glob kept | none |
| 10 | BSD re-run of case 6 | red, line 142 | as case 6, under BSD tools | none |

## Mutation testing

Every mutation was an exact replacement of a string occurring once in
`lib/probes-readonly-command.sh`. Each was proven landed with `command grep -cF`
(count 1), then restored by the swapped replacement and proven with the same
grep (count 0). `git status --short lib` was empty after the last restore. Only
`tests/probes-readonly-globs.bats` was run per mutation, plus
`tests/probes-readonly-operands.bats` for the reference run. One process ran at
a time, in the foreground.

Mutation sites:

- **Candidate site:** the line `[ -n "$candidate" ] || candidate="${word##*<}"`
  (line 234).
- **Loop head:** the comment line `# not_op: the command word, …` (line 152).

Mutations:

- **M1** (candidate site): wrap the line in
  `case "$word" in *[*$]* | *?*) ;; *) … ;; esac`. The unquoted `?` matches
  every word, which is the plausible over-broad bug.
- **M2** (loop head): replace with
  `case "$word" in *[*?[\$]*) continue ;; esac`, a skip placed ahead of the
  pattern rule.
- **M3** (loop head): replace with `case "$word" in *[\$]*) all_ok=0 ;; esac`.
- **M4** (loop head): replace with a `break` on a `.log`/`.err` word holding a
  metacharacter.
- **M5** (candidate site): wrap with the class `*[*[\$]*`, which is missing `?`.
- **REF** (candidate site): wrap with the contract class `*[*?[\$]*`. This is a
  reference run, not a mutation: it shows the tests can all be satisfied at
  once.

| behaviour | mutation | red or survived (and fixed) |
| --- | --- | --- |
| plain name still a candidate (case 5) | M1 | red: case 5 at line 70, and the positive halves of cases 1-4 and 6 at lines 32, 41, 50, 59, 78 (RED-report lines, before the edits) |
| skip limited to the candidate, pattern untouched | M2 | survived the RED suite (1-6 all green). Fixed by case 8, which reds at line 110 while 9/10 others pass |
| `$` candidate skipped, not whole-command rejection | M3 | survived case 2. Fixed by case 7, which reds at line 100 |
| later literal still taken after a skip | M4 | red: cases 6 (line 85), 7 (line 100), 10 (line 142) |
| `?` in the skip class | M5 | red: case 3 only (line 54) |
| contract-shaped skip satisfies all | REF | globs 10/10 green, operands 20/20 green |

## Fixes Applied

- `tests/probes-readonly-globs.bats` case 6: replaced the positive grep and the
  restating negative with one exact readfile-lines assertion.
- `tests/probes-readonly-globs.bats`: added case 7 (`$` and a later literal),
  case 8 (metacharacter in grep's pattern), case 9 (quoted `*.log`) and case 10
  (BSD re-run).
- `tests/probes-readonly-globs.bats` cases 2 and 7: an SC2016 inline disable,
  with its reason.

## Requirements Validation

| Requirement | Status | Evidence |
| --- | --- | --- |
| Q4: `*`, `?`, `[`, `$` candidate skipped | Satisfied (red) | cases 1-4, M5 |
| Q4: quoted or not | Satisfied (red) | case 9 |
| Q4: later literal still taken | Satisfied (red) | cases 6, 7, 10; M4 |
| Q4: no candidate, generic wording | Covered elsewhere | `verdicts-readonly.bats` no-facts case |
| Slice 3: no over-broad skip | Satisfied (guard) | case 5 (M1), case 8 (M2) |
| `CLAUDE.md` BSD re-run | Satisfied (red) | case 10 |

## Positive Observations

- The RED file paired every negative with a same-shape positive in one case, and
  used `assert_no_readfile`'s `writable` check, so neither an empty probe nor a
  rejected command could pass a negative.
- Every command was single-quoted, so `$` reached the scan intact.

## Recommendations

- GREEN should place the skip at the candidate site (line 234), not at the loop
  head. Case 8 now enforces this.
