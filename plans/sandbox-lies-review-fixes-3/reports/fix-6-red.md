# Fix 6 RED — `_readonly_tokenize` copies the word on every `#` and `>&`

Nothing committed. New file (untracked): `tests/probes-readonly-tokenize-time.bats`
(about 105 lines; loads `helpers/bsd-stubs` and `helpers/locale`). `lib/` untouched.
Run: `scripts/run-bats.sh tests/probes-readonly-tokenize-time.bats` (about 50 s).
No `make_bsd_stubs` re-run case: the code under test uses only bash builtins and
`printf`; the stubbed tools are not called. python3 is the clock only.

## Deviation from the prompt: bound on a ratio of ratios, not 9

A plain t(4N)/t(N) < 9 does not go red on bash 5.2. The scan stops at 16384
characters, so 4N tops out at 16000 (N = 4000), where the copy cost is only part
of the total. Measured on the unchanged code (min of 3, python3 timer):

| locale | shape | t(N) | t(4N) | t(4N)/t(N) |
| ------ | ----- | ---- | ----- | ---------- |
| C | plain | 0.229 | 1.014 | 4.44 |
| C | `a` then `#` | 0.485 | 4.015 | 8.27 |
| C | `a#` mixed | 0.349 | 2.617 | 7.50 |
| C | `>&` dense | 0.422 | 3.197 | 7.58 |
| C.UTF-8 | plain | 0.273 | 1.187 | 4.35 |
| C.UTF-8 | `a` then `#` | 0.601 | 5.588 | 9.30 |
| C.UTF-8 | `a#` mixed | 0.432 | 3.378 | 7.82 |
| C.UTF-8 | `>&` dense | 0.490 | 3.927 | 8.02 |

A bound of 9 passes the mixed and `>&` shapes (and the hash shape under C).
Each test therefore asserts `(t_dense(4N)/t_dense(N)) / (t_plain(4N)/t_plain(N)) < 1.4`.
The plain word (letters only, same length, same run, same locale) is the linear
control, measured once in `setup_file`. Unchanged code gives 1.7 to 2.3; a linear
scan gives about 1. If you want the literal bound of 9 as well, it is a one-line
addition but it cannot be the red assertion. Locale is `utf8_locale` (C.UTF-8
here), as fix 5.

## The three tests

Each times `_readonly_tokenize "cat <word> x"` in a fresh `bash -c` at N = 4000
and 4N = 16000 characters. The helper compares the tokens of every timed run
with `wcat`, `w<word>`, `wx` and exits non-zero on a mismatch, so a tokenizer
returning nothing quickly cannot pass.

1. hash: one letter then `#` characters.
2. mixed: `a#` repeated (a word dense in `#` and letters).
3. redir: `>&` repeated.

Observed on the unchanged code (all three `not ok`, on the final `python3`
ratio check, line `assert_linear_growth` — no error from a missing function):

- hash: t(N)=0.5692 t(4N)=5.3954; plain 0.2844 / 1.1876; ratio over plain 2.27
- mixed: t(N)=0.3989 t(4N)=3.2615; ratio over plain 1.96
- redir: t(N)=0.4926 t(4N)=4.1537; ratio over plain 2.02

State of the world that fails each: the pending `run` is joined into `word`
(`word="$word$run"`) on every unquoted `#` (and every `&`), so the copy of the
whole word recurs once per `#`/`&` character, giving a cost quadratic in word
length. A tokenizer that flushes only at 256 characters or at a separator is
about 1.0 over plain.

What else could fail it: heavy load on the box inflating one of the six
measurements (min of 3 each; the plain pair is shared by the three cases, so a
slow plain pair would lower the ratio and make a false pass, a slow dense
t(4N) raise it); a fix that makes the dense path slower per character than a
plain word by a constant factor does not change the ratio (it cancels), but one
that makes the dense path itself superlinear in a different way would fail;
an output mismatch fails the helper, not the ratio. The 1.4 bound sits between
about 1.0 (linear) and 1.7 to 2.3 (observed defect): a fixed tokenizer whose
plain control runs above its usual 4.35 to 4.44 ratio by 40 percent in one
direction would be a false fail; none seen.

## Differential tool

`/tmp/claude/fix6/difftok.sh [bash] [count=3000] [seed=6]`: runs the saved
pre-change function (`/tmp/claude/fix6/pre-tokenize.sh`, a copy of the lib
before any change) and the current lib (override with `DIFFTOK_CUR=<file>`)
under the given bash on the same seeded inputs (alphabet letters `#` `>` `&`
quotes backslash space `$` newline plus `<` `|` `;` tab; lengths 0-40, 0-300,
250-700, and dense `#`/`>&`/`a#` words up to about 400 chars), compares cut flag
and tokens byte-exactly, prints `DIFF` lines then `inputs=N differences=M`;
exit 1 on a difference. It proved it detects a change: a mutant pre copy with
the `*'>'` case arm removed gave 50 differences in 200 inputs.

Baseline (current lib equals pre, 3000 inputs each): 0 differences on bash 5.2
(default locale, which is C.UTF-8 here, and LC_ALL=C and LC_ALL=C.UTF-8) and on
`/tmp/claude/bash32/bash` (3.2.0; default, LC_ALL=C, LC_ALL=C.UTF-8).

## Before timings

`/tmp/claude/fix6/time32.sh [N=16384]` (output kept in
`/tmp/claude/fix6/time32-before.txt`). Command is `cat <word> x`, 16384
characters total; seconds, one run each:

| shell, locale | plain | `a` then `#` | `a` then `#` (6001) | `a#` mixed | `>&` dense |
| ------------- | ----- | ------------ | ------------------- | ---------- | ---------- |
| 3.2.0, C | 2.0 | 11.4 | 2.0 | 6.4 | 6.7 |
| 3.2.0, C.UTF-8 | 3.5 | 66.7 | 9.9 | 33.7 | 38.5 |
| system bash 5.2, C.UTF-8 | 1.3 | 5.5 | 1.0 | 3.3 | 3.9 |

The 66.7 s is the prompt's "68 s" case.

## Notes for GREEN

- After the fix, run the three cases (expect ratio over plain near 1) and
  `difftok.sh` under both bashes and locales (expect 0), then `time32.sh` for
  the after column.
- A GREEN that leaves the `#`/`&` branches flushing only `run`, not `word`,
  needs `case "$word"` at `&` to see the word's last character: the `*'>'`
  and `*'<'` tests read the end of `word$run`, which the differential tool
  covers.
