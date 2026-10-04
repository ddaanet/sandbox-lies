# Item 4.1 slice 4: RED report

Tests added to `tests/probes-readonly-operands.bats` (353 lines, BSD case still
last; `shellcheck -x` clean). SUT untouched (`git diff --stat lib/` empty).

## Per-test output

- 18 `uniq in.txt out.log is a writer, uniq in.log is not`: RED on its
  assertion. `assert_no_readfile` failed at line 314 ("expected nonzero exit
  code"): the writer rule is absent, so `readfile=out.log` is printed. Its
  positive run `uniq in.log` (`readfile=in.log`) passes on current code: that
  part is the guard the slice names, needing no red, and it is paired in the
  same case with the negative.
- 19 `grep -e <in.log pat.log gives the redirected name, never the pattern`:
  passes on current code (the slice-3 code-review fix already holds it);
  proven by mutation below. Positive assertion `readfile=in.log` plus the
  negative `readfile=pat.log`.
- 1-17, 20: pass, unchanged.

## Mutation proof

Test 19 (`grep -e <in.log pat.log`): in `_readonly_readfile_arg`, replaced the
once-occurring line `                1:-*) ;;` with
`                2:*'<'*) pat=0; continue ;;` followed by that same line,
so a `<` word in the argument role (`pat=2`) is consumed as the argument.
Result: test 19 red on its own assertion (line 328, `readfile=in.log` absent);
test 18 stayed red as before; others green. Restored by the inverse
replacement. `command grep -n "2:\*'<'"` on the SUT: no hit; `git diff --stat
lib/`: empty; suite afterwards: only test 18 red (the expected RED).

## Choices

- The `uniq` negative uses `in.txt out.log` (only `out.log` is log-shaped), and
  is paired with `uniq in.log` inside the same case.
- Both new cases sit before the BSD section, which stays last.
