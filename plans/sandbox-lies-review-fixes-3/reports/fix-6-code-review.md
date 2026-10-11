# Fix 6 code review (commit e501eb0)

Verdict: code correct; header and changelog wording defects fixed.

## 1. Differential (own generator, /tmp/claude/fix6r/gen.py)

Pre-change function (`git show e501eb0^:lib/probes-readonly-command.sh`) against
HEAD, comparing the token list and the cut flag for each input. The generator
mixes `#` after letters, quotes, escapes and `$(`; `>&` and `<&` after digits;
words of 254 to 514 characters straddling the 256 flush (with quotes, kept
backslash pairs, `#`, `&` right after it); a long `>`/`<` word then a separator
then `&`/`#` (the `wlast` reset); runs of empty quotes and `\<newline>`; and
multibyte characters. Result: byte-identical output in every config.

| bash | locale | inputs |
| --- | --- | --- |
| 5.2.37 | default | 1200 |
| 5.2.37 | C.UTF-8 | 3000 |
| 5.2.37 | C | 3000 |
| 3.2 | default | 2400 |
| 3.2 | C.UTF-8 | 2400 |
| 3.2 | C | 2400 |

Detector check: removing the `wlast=''` reset from a copy of HEAD makes the
generator report a difference within 600 inputs.

## 2. `invalue -eq 0` implies word and run empty

Every append to `run` sets `invalue=1`, except three paths that cannot run with
`invalue` 0: the single- and double-quote bodies and the `esc=2` pair (a quote
opened earlier, and the opening quote set `invalue=1`), and the `&` arm
appending after `>`/`<` (`last` is non-empty only if a `*)` arm already ran,
setting `invalue`). The flush moves run into word, so it preserves emptiness.
`invalue` returns to 0 only together with `word=''`, `run=''` and `wlast=''` at
a separator. `wlast` is set only at a flush (run non-empty then) and consulted
only when run is empty; run is empty with a non-empty word only right after a
flush or an escaped newline/quote-only stretch, where `wlast` still holds the
word's last character. So `last` equals the old `${word: -1}`, and the `#`
test equals the old `-z word && invalue -eq 0`.

## 3. Timing

`tests/probes-readonly-tokenize-time.bats`: 3 passed. Hand run, bash 3.2.0,
C.UTF-8, 16384-character command with a letter run then `#`: 3.6 s (reported
3.7 s).

## 4-5. Header and changelog (defects, fixed)

- The header's figures read "a letter then #: 5.5 s and 66.7 s before",
  mixing before and after numbers, and the `>&` case had no before figure; the
  paragraph also wrapped raggedly (one line 81 columns, a `> &` split by
  accident, a 4-line orphan "Residuals" block). Rewrote the figures from
  /tmp/claude/fix6/time32-before.txt and time32-after2.txt, stated that `wlast`
  is only read while the run is empty and that `invalue` 0 means word and run
  are empty, and reflowed the residuals.
- Changelog said "a 16384-character word of `#` or `>&`": a word of only `#`
  is a comment, not quadratic. Now "`#` after a letter, or of `>&`", with both
  before figures (66.7 s, 38.5 s) and both after (3.7 s, 4.6 s); rewrapped by
  `just format-docs`.
- The residual of the flush's `word="$word$run"` copy (at most 64 per word) is
  stated truthfully. No other stale comment found.

`just precommit` unsandboxed: exit 0, 421 bats passed.
