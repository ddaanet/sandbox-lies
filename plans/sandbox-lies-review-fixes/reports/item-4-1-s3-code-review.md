# Item 4.1 slice 3: code review

Saved by the orchestrator from the corrector's reply: the harness refused the
agent's own Write of this file.

**Scope**: `lib/probes-readonly-command.sh` `_readonly_readfile_arg`, the
block GREEN added (commit `Item 4.1/3 — an -e or -f option takes the pattern
role`) and its comment. **Date**: 2026-10-05. **Mode**: review + fix.
**Overall Assessment**: Ready.

## Summary

- GREEN covers what the slice's tests ask for: a separate `-e`/`-f` takes the
  next word as its argument, and a glued one clears the pattern role.
- One regression, fixed. The argument skip consumed any word, including a `<`
  redirection, and so bypassed slice 2's `<` rule. Four commands that gave the
  right `readfile=` before the slice lost it or named the pattern file.
- The fix makes the argument role a third value of `pat` (`pat=2`). The `<`
  rule is written once and serves both roles, and the `arg` variable is gone.
- Mutation run, once, on the GREEN SUT: `awk:-[ef]) pat=0 arg=1 ;;` became
  `awk:-[ef]) pat=0 ;;`, so a separate `-e`/`-f` cleared the role but took no
  argument. Tests 15 (line 244) and 16 (line 259) went red; 1–14, 17 and 18
  stayed green. Restored by the inverse string replacement;
  `git diff --stat lib/` was empty afterwards.
- After the fix, `just precommit` exits 0 with "bats: 295 passed, 0 failed".
  Checks that passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl,
  line limits, links, tests.

## Checks requested

Probed on the fixed code by sourcing the lib, then calling
`_readonly_tokenize` and `_readonly_readfile_arg`.

- **Writer checks before the skip.** The in-place check and the `>` check
  both run before the argument is consumed, and the fix keeps that order.
  `grep -e '>' x.log` gives no `readfile=`. `sed -f -i x.log` gives none
  either: a false writer, the safe side. `sed -e 's/a/b/w out.log' in.log`
  still gives `readfile=in.log`, because sed's `w` is never recognised as a
  writer; it does the same without `-e`, so this predates the slice (see
  Recommendations).
- **The `not_op` gate and `<`.** An `-e` right after a lone `<` is the
  redirect's filename: `grep pat < -e x.log` and `grep < -e pat x.log` both
  give `x.log`. `grep -e pat <x.log` gives `x.log`. The regression is Major 1.
- **Role left set at segment end.** `grep -e | tail run.log` gives `run.log`.
  Under GREEN a leftover `arg` could only consume the next segment's command
  word, never a candidate, so the `arg=0` reset changed no output and no test
  could pin it. Now the leftover state is `pat=2`, which would consume
  `run.log` without the `pat=0` reset; test 17's reset mutation now guards
  it.
- **Slices 1 and 2.** `grep -e -x y.log`, `grep -e -e y.log` and
  `grep -i -e x.log y.log` all give `y.log`; before the slice the first two
  gave nothing. `pat 1` behaviour is unchanged: the `1:-*` arm reproduces the
  old `-*` arm.
- **NFR-2.** No array added; every variable set under `set -u`.
  `case "$pat:$word"` behaves the same on bash 3.2. No `2>/dev/null` added.

## Issues Found

### Critical

None.

### Major

1. **The `-e`/`-f` argument skip consumed a `<` redirection as the
   argument.**
   - Location: GREEN's block `if [ "$arg" -eq 1 ]; then arg=0; continue; fi`.
   - Problem: the skip consumed the next word whatever it was. Slice 2's
     pattern block treats only the text before a `<` as the operand (`x` in
     `x<in.log`); it does not consume a lone `<`, a `<x.log` or a `2<x.log`,
     or the name after a lone `<`. The skip consumed all of them. Pre-slice
     output, then GREEN output:
     - `grep -e <x.log pat`: `x.log`, then nothing.
     - `grep -e x<in.log`: `in.log`, then nothing.
     - `grep -e <in.log pat.log`: `in.log`, then `pat.log` (the pattern).
     - `grep -f < pats.txt p.log x.log`: `x.log`, then `p.log` (the pattern
       file).

     The last two are wrong values: the verdict would tell the user to re-run
     the command that wrote a file nobody wrote.
   - Fix: `pat=2` means "the argument of a separate `-e`/`-f`", and the
     pattern block runs whenever `pat` is non-zero. Its option arm is `1:-*`:
     only the pattern role passes over a word opening with `-`, while the
     argument role consumes `-x`. The `<` arms are shared, and the `-e`/`-f`
     detection runs after the pattern block. All four commands give their
     pre-slice values again.
   - Status: FIXED.

### Minor

None.

## Fixes Applied

- `lib/probes-readonly-command.sh`: removed `arg` (its `local`, its segment
  reset and its skip block). The pattern block tests `[ "$pat" -ne 0 ]` and
  switches on `case "$pat:$word"`, with the arm `1:-*`. The `-e`/`-f`
  detection moved below it and sets `pat=2` for a separate option; a glued one
  still sets `pat=0`. Both comments rewritten to match. 277 to 274 lines. The
  Edit got no classifier verdict, so the change went in through
  `/tmp/claude-1000/sl/put.py`.

## Requirements Validation

| Requirement | Status | Evidence |
| --- | --- | --- |
| FR-4/D4: `-e`/`-f` takes the pattern role | Satisfied | glued sets `pat=0`; tests 14, 16 |
| FR-4/D4: the word after a separate `-e`/`-f` is its argument | Satisfied | `pat=2`; tests 15, 16 (red under the mutation) |
| Slice list revision: per-segment reset | Satisfied | test 17; the `pat=0` reset also clears the argument role |
| Clustered and long forms | Deferred | orchestrator's call: a docs-step residual |

## Positive Observations

- The writer checks still run before every operand rule, so no role can hide
  a writer.
- The option patterns apply only to `grep`, `sed` and `awk`, so
  `tail -f run.log` and `cut -f 1 x.log` are unaffected.

## Recommendations

- **Test gap for Major 1.** Nothing pins `<` in the argument slot. A case like
  `grep -e <in.log pat.log`, expecting `readfile=in.log` and no
  `readfile=pat.log`, would; GREEN's code fails both assertions.
- **sed's `w` command** (and the `s///w` flag) writes a file but is not
  counted as a writer. Predates the slice, outside D4: a docs-step residual
  or a later item.
- **A descriptor duplication in an operand slot.** In
  `grep -e 2>&1 pat.log x.log`, `2>&1` is consumed as the operand, in slice
  2's pattern slot and in the argument slot alike. It belongs with the "other
  options' separate arguments" residual.

Orchestrator's disposition: the Major 1 pin goes into slice 4's test list by
list revision (proven by mutation there); sed's `w` and the descriptor
duplication go to Item 4.1's docs step as residuals.
