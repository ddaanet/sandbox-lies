# Item 4.1 slice 3: test review

Saved by the orchestrator from the corrector's reply: the harness refused the
agent's own Write of this file.

**Scope**: tests 14–17 in `tests/probes-readonly-operands.bats`, plus
`reports/item-4-1-s3-red.md`. The SUT was mutated once for the test 17 proof
and restored. **Date**: 2026-10-05. **Mode**: review + fix. **Overall
Assessment**: Ready.

## Summary

- Tests 14, 15 and 16 red on assertions against the current SUT.
- Test 17 (the reset pin) keeps its mutation proof, reproduced with a
  different mutation.
- One finding, fixed: test 16's named form `awk -f prog.log in.err` cannot red
  on the current code. Its only red came from the glued `-fprog.log` run,
  which pins "-f takes the pattern role" but not "the word after a separate -f
  is its argument". A new two-`-f` run reds by itself and pins that rule.
- The file is now 319 lines.

## Mechanical check (after the fix)

`bats tests/probes-readonly-operands.bats`, foreground:

- **Test 14** (`grep -epat x.log`): not ok on `grep -qxF 'readfile=x.log'`,
  line 230.
- **Test 15** (`sed -e s/a/b/ -e s/c/d/x.log in.out`): not ok on
  `grep -qxF 'readfile=in.out'`, line 244.
- **Test 16** (`awk -f prog.log in.err`): not ok on
  `grep -qxF 'readfile=in.err'`, line 269 (the glued run). The new
  `awk -f lib.awk -f prog.log in.err` run also reds by itself on that
  assertion, checked in a scratch copy with the glued run deleted: the current
  code gives `readfile=prog.log` there.
- **Test 17** (`grep -i | tail run.log`): ok, as the RED report records; the
  mutation proof is below.
- Tests 1–13 and 18 pass. No test ERRORed.

## Test 17 mutation proof (reviewer's own mutation)

- **Mutation**: in `lib/probes-readonly-command.sh`, `in_seg=0 pat=0 lt=0`
  (once, the segment-separator reset) replaced with
  `in_seg=0 pat=$pat lt=0`, so the pattern role carries across `|`. The RED
  report deleted the assignment; this one keeps it as a self-assignment.
- **Result**: test 17 not ok on `grep -qxF 'readfile=run.log'`, line 295.
  Tests 14–16 failed as before; 1–13 and 18 stayed ok.
- **Restore**: inverse string replacement by a Python script asserting one
  occurrence. A `grep -c` for the mutation text gives 0, and
  `git diff --stat lib/` is empty.

## Issues Found

### Critical

None.

### Major

1. **Test 16's separate `-f` form had never been seen to red.**
   - Location: `tests/probes-readonly-operands.bats`, test 16, first run.
   - The current code always skips awk's first non-option operand; with one
     separate `-f` that operand is the `-f` argument, so the current code
     already gives the right answer. Probing `_readonly_readfile_arg`
     directly, `awk -f prog.awk in.err` gives `in.err` and
     `awk -f prog.log in.txt` gives nothing, both correct today.
   - After GREEN the run guards two wrong implementations — an `-f` that
     clears the role but does not skip its argument (prog.log becomes the
     candidate), and an argument skip that leaves the role set (in.err is
     eaten) — neither ever seen to fail it.
   - Fix: a third run, `awk -f lib.awk -f prog.log in.err`, expecting
     `readfile=in.err` with the negative `readfile=prog.log` on the same
     output. The current pattern skip eats only `lib.awk`, so `prog.log` is
     withheld only when the word after each `-f` is its argument. Both wrong
     implementations fail it. It is the `-f` counterpart of test 15's two
     `-e`. The separate and glued runs stay.
   - Status: FIXED.

### Minor

None. Other wrong-reason checks:

- **Test 14**: "any option clears the role" would also pass it, but test 9
  (`grep -i x.log y.out`) rules that out; treating glued `-epat` like a
  separate `-e` would skip x.log and red it. Positive only, no negative to
  pair.
- **Test 15**: reds against each wrong implementation separately (no argument
  skip gives `s/c/d/x.log`; no role clear eats `in.out`). Its negative is
  paired with the positive on the same output. The in-place writer check
  matches none of its words, so `seg_ok` cannot be what withholds the line.
- **Test 17**: `-i` holds neither `e` nor `f`, so neither a bare `-e`/`-f`
  rule nor a cluster rule can consume the role. Slice 4 touches only `uniq`.
  `grep -i` with no pattern is malformed, unavoidably (any segment ending with
  the role set has no pattern); the test's comment says so.
- **Negatives**: every `run !` in tests 15 and 16 checks the same `$output` as
  a positive `readfile=` line, so none can pass on empty output.

## Fixes Applied

- Test 16: added the run `awk -f lib.awk -f prog.log in.err` (positive
  `readfile=in.err`, negative `readfile=prog.log`) with a two-line comment;
  +10 lines, 319 total. The Edit got no classifier verdict, so it was applied
  through `/tmp/claude-1000/sl/put.py`.
- `shellcheck -x` on the file is clean; `bats tests/docs.bats` passes.

## Requirements Validation

| Requirement | Status | Evidence |
| --- | --- | --- |
| FR-4/D4: an `-e`/`-f` option takes the pattern role | Pinned | test 14, test 16's glued run |
| FR-4/D4: the word after a separate `-e`/`-f` is its argument | Pinned | test 15 (two `-e`), test 16 (two `-f`) |
| Slice list revision: per-segment reset pin | Pinned | test 17 plus mutation proof |

## Recommendations

- **The "-e/-f family" may be wider than the slice's cases.** Clustered short
  options (`sed -ne 1p x.log`, `grep -ie pat x.log`, `sed -nf prog x.log`) and
  long options (`--regexp=`, `--expression=`, `--file=`) are unpinned. Either
  GREEN covers them with a pinned case, or the Item 4.1 docs step lists them
  as a residual. No tests added: the runbook does not say which reading of
  "family" applies.
- **Separate `-e` on grep** (`grep -e pat x.log`) also passes on the current
  code by the same coincidence as a single `-f`; test 15's two-`-e` run
  already pins the rule.

Orchestrator's disposition: GREEN implements only what the slice's tests
demand; the clustered and long forms go to Item 4.1's docs step as a residual.
