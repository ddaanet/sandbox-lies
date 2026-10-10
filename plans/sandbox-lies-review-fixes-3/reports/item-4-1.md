# Item 4.1 report — tokenizer accumulates a bounded pending run

## Change

`lib/probes-readonly-command.sh`, `_readonly_tokenize`: every `word="$word$ch"`
append became `run="$run$ch"`. The run joins `word` when it reaches 256
characters (checked at the top of each iteration) and before each read of
`word`: the `#` test, the `&` duplication test, the emission at a separator,
and the end-of-input emission. Header cost sentence rewritten to the figures
below. Tests untouched; no `# MUT` text.

## Timing

Method: evidence.md records no harness, so a script under `/tmp/claude/item41`
sources the lib, calls `_readonly_tokenize` once on generated input and times
it with `date +%s.%N`. Inputs: one word of 16384 `a`; 1600 words of
`abcdefgh` joined by spaces (14399 characters, under the 16384 bound).
Single runs, same box.

| input | 5.2 before | 5.2 after | 3.2.0 before | 3.2.0 after |
| --- | --- | --- | --- | --- |
| one 16384-char word | 2.8 s | 1.2 s | 31.7 s | 3.5 s |
| 1600 short words | 0.8 s | 1.1 s | 1.7 s | 2.1 s |

(evidence.md's older figures: 4.2 / 1.3 s on 5.2, 38.7 / 2.5 s on 3.2.)
The many-words row is slightly slower, from the extra per-character length
test and the per-word join.

Target met: 3.5 s under 5 s on 3.2.0 for one 16384-character word.

## Equivalence

Old function (`git show HEAD:`) against new, on bash 5.2 and 3.2.0, on 11
inputs: single, double and backslash quoting; `#` comment and `x#y`; `|`,
`&&`, `;`, `&`, `>&2`, `2>&1`; words of exactly 255, 256, 257 and 512
characters; 256- and 512-character words followed by `#` and by `>&1` and
`2>&1`; a quoted 256-character run split by an escaped quote; a quoted
257-character word and a 512-character word followed by `&z`; line
continuation, tab, `<<` heredoc cut, empty and `''` input. Compared `cut`,
token count, and each token's length, prefix and cksum. Result: old and new
byte-identical on 5.2, byte-identical on 3.2.0, and 5.2 output equals 3.2.0
output.

## Guard and gate

`tests/probes-readonly*.bats` (7 files, one at a time): 17 + 15 + 13 + 12 +
20 + 15 + 9 passed, 0 failed.

`just precommit` exit 0. Recap: precommit passed: plugin.json, hooks.json,
shellcheck, bash -n, rumdl, line limits, links, python compile, tests (400
passed, 0 failed).
