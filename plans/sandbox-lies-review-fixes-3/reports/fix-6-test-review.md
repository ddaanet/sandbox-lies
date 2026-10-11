# Fix 6 test review

Reviewed `tests/probes-readonly-tokenize-time.bats` (untracked). I redesigned
the assertion. `lib/` untouched; nothing committed. File is 95 lines.

## Verdict on the RED as delivered

The ratio-of-ratios (t(4N)/t(N) over the plain word's, bound 1.4) did
discriminate on 5.2 (defect 1.94 to 2.72 by my measurement, fixed about 0.95
to 1.07) but with thin margins: 1.4 against a defect floor of 1.94 (1.4x) and
a fixed ceiling near 1.07 (1.3x). It also needed six dense timings per case
(the 4000-character one adds nothing) and four noisy timed quantities. The
tenfold rule cannot hold in spirit at this cap: the scan stops at 16384
characters, so the dense t(4N)/t(N) on the unchanged code (7.4 to 10.3) sits
inside the linear 4 to quadratic 16 gap with no clean midpoint.

## Design adopted: dense over plain at the same size

Each case times a 16000-character dense word and compares it with the
16000-character plain word (letters only, same locale, shared control measured
once in `setup_file`). Bound 1.9. One quantity, fewer timings.

Measured (bash 5.2, C.UTF-8, min of 3, dense / plain at 16000):

| shape | unchanged code | stand-in fix |
| ----- | -------------- | ------------ |
| hash (letter then `#`) | 4.58 to 5.19 | 1.00 to 1.06 |
| mixed (`a#`) | 2.85 to 2.99 | 1.07 |
| redir (`>&`) | 3.25 to 3.49 | 1.21 |

1.9 is about the geometric mean of the fixed ceiling (1.21) and the defect
floor (2.85): 1.6x clear on each side, against 1.3 to 1.4x for the old design.
At N = 12000 the defect floor falls to 2.32 and the saving is about 30%, so
16000 stays. A fix with up to 1.9x per-character overhead on `#`/`&` would
still pass; a fix leaving the dense path 2x slower would not.

Min-of-3: adequate for the dense side (a spike must hit all three runs). The
plain control is measured once; a spike across its three runs would inflate it
and lower the ratio (false-pass risk, needs plain inflated about 1.5x or more).
Accepted.

Token outputs: every timed run's tokens are compared with `wcat`,
`w<word>`, `wx`; a mismatch exits non-zero, so empty or wrong output cannot
pass.

Runtime: 43.7 s on the unchanged code (was about 50), 15.3 s with a fix.

## Evidence

- Unchanged code, one foreground bats process: all three `not ok`, each on the
  ratio assertion (`assert_dense_near_plain`, line 81): hash ratio 4.58, mixed
  2.85, redir 3.25. No error from a missing function or file.
- Linear stand-in, in a `mktemp -d` copy of `lib/`, `tests/`, `scripts/` (real
  lib untouched): the `#` arm tests emptiness with a `flushed` flag (set at the
  256-character flush, reset where `word=''`) instead of expanding `word`, and
  the `&` arm tests the last character of `run` or `word` (`${run: -1}` /
  `${word: -1}`) without joining. Result: 3 of 3 `ok` in 15.3 s.

## Finding for GREEN

A partial fix stays red. My first stand-in removed only the two
`word="$word$run"` copies; `[ -z "$word" ]` in the `#` arm still expands the
whole word on every `#`, leaving hash at 3.2x and mixed at 2.1x over plain.
Emptiness must be tested without expanding `word`, and the `&` arm must read
the last character without `case "$word$run"`. `${#word}` is also O(n) in a
UTF-8 locale.

## State of the world that fails each test, and what else could

Failing state: the whole word copied or expanded on each unquoted `#` (hash,
mixed) or `&` after a `>` (redir). Other causes of red: a load spike across all
three dense runs; a fix that makes the dense path 1.9x slower per character.
Output mismatch fails the helper, not the ratio.

Note: the scratch directory from `mktemp -d` under `$TMPDIR` was not removed
(the removal was refused by the safety check); it holds only my copy.
