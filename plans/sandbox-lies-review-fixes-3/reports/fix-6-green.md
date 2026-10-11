# Fix 6 GREEN — `_readonly_tokenize` no longer copies the run on `#` and `>&`

Changed: `lib/probes-readonly-command.sh`, `docs/changelog.md` (one entry).
`docs/design.md` untouched.

## Design

The `#` and `&` arms used to do `word="$word$run"; run=''` and then test
`word` (`[ -z "$word" ]`, `case "$word" in *'>'|*'<'`), copying and expanding
the whole word on every such character. Now neither arm touches `word`.

- `#` arm: the comment test is `[ "$invalue" -eq 0 ]` alone. Invariant: every
  character that reaches `run` or `word` sets `invalue`, except an unquoted
  `#` that already needed a non-empty word, and a `&` that needed a prior `>`
  or `<` (which set it). So `invalue` 0 means `word` and `run` are both empty,
  and the old `-z "$word"` test was redundant. A `flushed` flag, as the test
  review's stand-in used, turned out to be dead code (I added it first; a
  mutation of it was not caught by the differential, which showed it was
  redundant) and was removed.
- `&` arm: reads the last character of `run` (`${run: -1}`, `run` is at most
  257 characters); when `run` is empty it uses `wlast`, the last character of
  `run` saved at the 256-character flush and reset with `word=''` at a
  separator. `wlast` is empty when `word` is empty. A matching `>` or `<` keeps
  the `&` in the word, as before.
- The flush (`${#run}` >= 256) is the only join left mid-word: it stores
  `wlast` and joins `word`.

## Differential (`/tmp/claude/fix6/difftok.sh`, pre-change function vs current)

0 differences in every run on the final code:

| bash | locale | inputs / seed |
| ---- | ------ | ------------- |
| 5.2 | default (C.UTF-8) | 3000 / 6 (and 6000 / 17, on the first version) |
| 5.2 | LC_ALL=C | 3000 / 6; 6000 / 29 |
| 5.2 | LC_ALL=C.UTF-8 | 3000 / 6; 6000 / 17 |
| 3.2.0 | LC_ALL=C | 3000 / 6 |
| 3.2.0 | LC_ALL=C.UTF-8 | 3000 / 6 |

(3.2.0 default locale, and 3.2.0 with 6000 / 17 under C, were also 0 on the
first version, which kept a redundant `flushed` flag. The final code was
re-checked at the sizes in the table.)

## Suites

Final code, one process at a time: `probes-readonly-tokenize-time` 3 passed
(the RED, now green), `-facts` 15, `-globs` 14, `-members` 12, `-operands` 20,
`-pins` 15, `-resolve` 9, `probes-readonly` 17: 0 failures.

## Timings (`/tmp/claude/fix6/time32.sh`, 16384-character word, seconds)

| shell, locale | shape | before | after |
| ------------- | ----- | ------ | ----- |
| 3.2.0, C | plain | 2.0 | 2.1 |
| | `a` then `#` | 11.4 | 2.2 |
| | `a` then `#` (6001) | 2.0 | 0.8 |
| | `a#` | 6.4 | 2.1 |
| | `>&` | 6.7 | 2.3 |
| 3.2.0, C.UTF-8 | plain | 3.5 | 3.7 |
| | `a` then `#` | 66.7 | 3.7 |
| | `a` then `#` (6001) | 9.9 | 1.3 |
| | `a#` | 33.7 | 3.8 |
| | `>&` | 38.5 | 4.6 |
| system bash 5.2, C.UTF-8 | plain | 1.3 | 1.3 |
| | `a` then `#` | 5.5 | 1.3 |
| | `a` then `#` (6001) | 1.0 | 0.4 |
| | `a#` | 3.3 | 1.4 |
| | `>&` | 3.9 | 1.7 |

The `>&` word stays about 25 percent above plain on 3.2.0 C.UTF-8 (4.6 against
3.7): a constant per-`&` cost (the `${run: -1}` and `case`), not growth.

## Header decision

The sentence "no copy grows with the word" was not true as written: the
flush's `word="$word$run"` copies the whole word, once per 256 characters (at
most 64 times, under the 16384 cap, about 0.5 MB in all). The header now says
that is the one copy that grows, names `invalue` and `wlast` as the stand-ins
for `word` in the `#` and `&` arms, and quotes the after timings. Measured
effect: a plain word's t(4N)/t(N) stays near 4.4 (RED report), so the join is
not visible.

## Kill-check

Mutation of `wlast="${run: -1}"` to `wlast=""` at the flush, landed
(`command grep` showed it), `difftok.sh bash 400 6` gave `differences=1`: a
`>&` word of over 256 characters ending a flush on `>` then `&`, where the
pre function kept the `&` in the word and the mutant split it. Restored by the
swapped replacement; grep shows the mutant text gone and the original present.
(The earlier mutation of the since-removed `flushed` flag gave 0 differences
in 400 inputs, which exposed it as dead.)

## Precommit

`just precommit` (unsandboxed, foreground) on the code before the last
header and changelog wording edits: exit 0, "precommit passed: plugin.json,
hooks.json, shellcheck, bash -n, rumdl, line limits, links, python compile,
tests" (421 bats passed, 0 failed). Re-run after the wording edits: exit 0, same recap.
