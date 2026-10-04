# Review: Item 4.1 slice 2 — test review (after RED)

Saved by the orchestrator from the corrector's reply: the harness refused the
corrector's own Write of this file. Content as returned, lightly condensed.

**Scope**: uncommitted slice 2 test changes in
`tests/probes-readonly-members.bats`, and the RED report
`reports/item-4-1-s2-red.md`. SUT `lib/probes-readonly-command.sh` read, not
edited. **Date**: 2026-10-05. **Mode**: review + fix.

**Overall Assessment**: Ready

## Summary

The four slice cases from the RED step are sound: the three red cases
(`grep x.log y.out`, `sed s/a/b/x.log in.out`, `awk x.log in.err`) fail on
their positive `readfile=` line, for the right reason (the current code takes
the log-shaped pattern or program word as input); the guard `sed s/a/b/ in.log`
passes as intended. Gap: three narrow GREEN implementations would pass the
whole suite while missing D4's rule. One case added for each; all three are
red.

## Mechanical first check

Before any fix: tests 12, 13, 14 `not ok`, each on its positive
`printf … | grep -qxF 'readfile=…'` line (222, 237, 251); the guard (15) and
every pre-existing test passed; none errored, none passed vacuously.

## Issues Found

### Critical Issues

None.

### Major Issues

1. **Skipping the word after the command name passes the slice** — FIXED.
   In every existing case the pattern comes straight after the command name,
   or that word is not log-shaped. Added
   `grep -i x.log y.out gives the input, never the pattern after an option`
   (expects `readfile=y.out`, negative on `x.log`).
2. **Taking the last log-shaped word passes the slice** — FIXED. No case had
   two log-shaped inputs. Added
   `grep x.log a.out b.err gives the first input after the pattern` (expects
   `readfile=a.out`, negative on `b.err`).
3. **Skipping the pattern once per command, not per segment, passes the
   slice** — FIXED. No case had grep/sed/awk in a later segment with a
   log-shaped pattern. Added
   `sed s/a/b/ in.txt | grep x.log y.out gives grep's input` (expects
   `readfile=y.out`, negative on `x.log`).

### Minor Issues

None. Each existing negative sits beside a positive on the right input;
comments match; the RED step's swap of `awk /x.log/ in.err` for
`awk x.log in.err` is correct.

## Fixes Applied

- `tests/probes-readonly-members.bats`: the three cases above, inserted after
  the guard. File now 342 lines.

## Wrong-reason hunt: scratch SUT variants

`lib/` and `tests/` copied to a scratch tree; `_readonly_readfile_arg`
replaced there with each variant (checkout SUT never touched; scratch restored
and `cmp`-identical afterwards). Against the fixed suite:

| Variant | Failing tests |
| --- | --- |
| unchanged SUT | 12, 13, 14, 16, 17, 18 (guard 15 passes) |
| correct rule (grep/sed/awk skip first non-option operand, reset per segment) | none |
| grep only | 13, 14 |
| every reader skips its first operand | 3, 4, 5, 19 (`cat build.out`, `tail run.err`, `sort in.log` catch it) |
| skip the word after the command name | 16 (new) |
| take the last log-shaped word, no skip | 17 (new) |
| skip the first log-shaped word | 6, 7, 8, 9, 15 |
| skip the pattern once per command, not per segment | 18 (new) |

The correct rule passes all 19 tests (no case needs slice 3 or 4); every
narrow variant fails at least one; each new case is the only test that catches
its variant.

## Post-fix run

Tests 12, 13, 14, 16, 17, 18 `not ok`, each on its positive `readfile=` line
(222, 237, 251, 280, 295, 310); 1–11, guard 15 and 19 pass.

## Requirements Validation

| Requirement | Status | Evidence |
| --- | --- | --- |
| FR-4 (D4 slice 2) | Satisfied, as tests | cases 12–18 |
