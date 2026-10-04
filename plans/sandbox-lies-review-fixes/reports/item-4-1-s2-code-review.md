# Review: Item 4.1 slice 2 — code review (after GREEN)

**Scope**: `git show 095260b -- lib/`, which is `_readonly_readfile_arg` in
`lib/probes-readonly-command.sh`. I read the whole function and
`_readonly_tokenize`, which feeds it. Tests were edited only to add cases for
the behaviour fixes below. **Date**: 2026-10-05. **Mode**: review + fix.

**Overall Assessment**: Ready

## Summary

The slice adds a per-segment `pat` flag. `grep`, `sed` and `awk` set it, and
the first later operand consumes it and is skipped. This is correct for the
slice's cases. However, the slice handled a word holding `<` with a single
rule ("a redirection, never the operand"), and it never treated a newline-only
word as an operand. That caused three regressions against the pre-slice code.
One gave a wrong `readfile=` value. The other two lost a correct one. All three
are fixed, with tests.

## Checks requested

- **Per-segment reset.** `_readonly_tokenize` emits a lone `|` for `|`, `;`,
  `&`, newline, and each character of `&&` and `||` (two `|` tokens). It does
  not emit one for an `&` glued to `>` or `<`, as in `2>&1`. `pat` resets on
  every `|`. I probed `grep pat a.log && cat b.log` and
  `grep x.log y.out & tail z.out`, and both give the correct value.
- **Mutated-SUT run (once).** I removed ` pat=0` from the `|` branch by exact
  replacement, ran `bats tests/probes-readonly-members.bats`, and restored by
  the inverse replacement (`git diff` was empty afterwards). All 19 tests
  **stayed green**. Every grep/sed/awk command word sets `pat=1` again, so the
  reset only matters when a segment ends with the flag unconsumed and the next
  segment is a non-pattern reader. `grep -epat | tail run.log` gives
  `run.log` with the reset and nothing without it. No test pins this; see
  Recommendations.
- **Path or prefix command names.** `/usr/bin/grep`, `env grep`,
  `LC_ALL=C grep` and `command grep` all leave `first` outside the reader
  list. So `seg_ok=0` and there is no `readfile=`, the same as before the slice
  (probed). This is no worse, and it is an existing documented residual.
- **Writer detection and `continue`.** The `first:word` in-place-edit case and
  the `>` check run before the pattern block. So the `continue` skips only the
  candidate test, and that is the intended effect for the pattern word.
  `seg_ok` and `all_ok` still see that word. `sed -i` segments are unaffected.
- **Slice 1's rules.** The `-`-option rule and `wc -l<build.log` are
  unchanged.
- **BSD / bash 3.2.** Only `case`, `[`, and `${var%%pat}` are used. There are
  no new arrays and no word splitting. `for tok in ${1+"$@"}` is unchanged.

## Issues Found

### Critical Issues

None.

### Major Issues

1. **The word after a lone `<` consumed the pattern flag (wrong value).**
   - Location: `lib/probes-readonly-command.sh`, `_readonly_readfile_arg`'s
     pattern block.
   - Problem: `grep < x.log y.out` gave `readfile=y.out`, which is grep's
     pattern. Before the slice it gave `x.log`, the stdin file. The slice's
     comment covered `<` held in a word, but not the name in the word after a
     separate `<`.
   - Fix: `lt` records that a word ends in `<` (`<`, `0<`, `<<<`). The next
     word's `not_op` is set from it, which keeps that word from consuming the
     flag. `not_op` also replaces `is_cmd` for the command word. Test:
     `grep < x.log y.out gives the redirected name, never the pattern`. It was
     red on the positive line before the fix and is green after.
   - **Status**: FIXED

### Minor Issues

1. **A pattern holding a newline did not consume the flag (lost value).**
   - Location: the same block. It sat under the `*"$nl"*) ;;` arm.
   - Problem: with `grep 'a<newline>b' y.out`, `y.out` was taken as the
     pattern, so there was no `readfile=`. Before the slice the value was
     `y.out`.
   - Fix: I moved the pattern block out of the candidate `case` into its own
     `if` ahead of it. A newline word is now an operand like any other, and the
     candidate `case` is back in its slice-1 form.
   - **Status**: FIXED
2. **A `<` past a word's first character blocked the flag (lost value).**
   - Problem: `grep 'a<b' y.out` and `grep x<in.txt y.out` gave no
     `readfile=`. Before the slice both gave `y.out`.
   - Fix: a word holding `<` consumes the flag when the text before its first
     `<` contains a non-digit (`x` in `x<in.log`). It does not when that text is
     empty or a descriptor number (`<in.log`, `0<in.log`). It also does not
     when the word opens with `-`. The word stays a candidate for the name after
     the `<`. Both cases are covered by
     `a pattern holding a newline or an inner < is still the pattern`. On HEAD
     the newline half fails, and I probed the `'a<b'` half separately against
     HEAD's function: it gave nothing.
   - **Status**: FIXED
3. **The comment did not state the quoted-`<` residual.** The tokenizer
   removes quotes, so `grep '<div' y.out` reads `<div` as a redirection and
   gives no `readfile=`. This is the safe side, like the quoted `>` the header
   already names. I stated it in the new block comment.
   - **Status**: FIXED
4. **Two `case "$first"` statements.** I merged them into one: `grep | sed |
   awk) pat=1`, then the other readers, then `*) seg_ok=0`. The behaviour is
   identical.
   - **Status**: FIXED

## Fixes Applied

- `lib/probes-readonly-command.sh`: `local … pat=0 lt=0 not_op`; `lt=0` in the
  `|` reset. `not_op=$lt lt=0`, then `lt=1` for a word ending in `<`, with a
  one-line comment. `not_op=1` on the command word. The merged `$first`
  `case`. A separate pattern block ahead of the slice-1 candidate `case`, with
  a comment covering the rule and the quoted-`<` residual. The candidate `case`
  is back in its slice-1 form. The file is now 263 lines.
- `tests/probes-readonly-members.bats`: two cases after
  `sed s/a/b/ in.txt | grep …`. The file is now 378 lines.
- `just precommit`: 290 passed, 0 failed. Result line:
  `precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests`.

## Requirements Validation

| Requirement | Status | Evidence |
| --- | --- | --- |
| FR-4 / D4 slice 2 | Satisfied | the pattern block; tests 12–20 |

## Positive Observations

- The flag is set on the command word and consumed by the first operand. This
  matches D4's "first non-option operand" without a positional count. Tests
  16, 17 and 18 rule out the narrow variants.
- Writer detection runs before the `continue`, so skipping the pattern word
  costs no exclusion.

## Recommendations

- **Test gap, not filled here (the code review does not author tests beyond
  its fixes).** No case pins the per-segment `pat=0` reset; the mutation above
  stays green. A candidate is `grep -epat | tail run.log` → `readfile=run.log`,
  which reds without the reset today. After slice 3, `-epat` clears the flag
  itself, so that case would no longer catch the fault. Pick a form slice 3
  leaves unconsumed, such as a long `--regexp=` if slice 3 does not cover it,
  or add the pin in slice 3's test review.
- **Line cap (flag for slices 3 and 4).** `tests/probes-readonly-members.bats`
  is at 378 of 400 lines. Slices 3 and 4 add about five cases of about 14 lines
  each and will not fit. Their cases need a new bats file that loads
  `helpers/bsd-stubs` (and `helpers/git-env`) with one `make_bsd_stubs` case.
  `REFACTOR-NEEDED: tests/probes-readonly-members.bats — operand-rule section
  outgrows the 400-line cap with slices 3–4`.
- **Slice 3 and 4 and the docs, noted only.** `-e`/`-f` and their attached and
  separate arguments are slice 3, `uniq` with an output operand is slice 4, and
  the header comment and the `readonly-path.md` row and residuals are the docs
  step. The docs step should carry over this report's residuals: a quoted `<`
  reads as a redirection, and a here-string's word is still a candidate (that
  one is pre-existing).
