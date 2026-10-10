# Review: Items 4.1, 5.1, 5.2 (commits 13610c0, 3826e88, 2a8e750)

Mode: review + fix. Nothing committed. Scratch: `/tmp/claude/rev41`.

## Summary

All three items meet the outline. Output of the tokenizer is unchanged. Two
comment defects and one header-scope defect fixed; two test gaps reported as
survivors for a cheaper agent to pin. Assessment: Ready after fixes.

## 4.1 tokenizer

Join sites present: top-of-iteration (run >= 256), `#` test, `&` test,
separator emission, end. No other read of `word`.

Equivalence (old = `git show 13610c0^:`), harness `gen.py`/`drv.sh`/`cmp.sh`
comparing cut flag, token count, and per token length, first 20 bytes and
cksum:

- bash 5.2.37: 1204 inputs, 0 diffs. Inputs: a-runs of 255/256/257/511/512/513
  with 15 tails each (`#x`, ` #x`, `>&1`, `>&2`, `&z`, `&`, `;`, quotes,
  escaped quote, `\ `, `|`, heredoc `<<E`, line continuation), leading `>`,
  `>` before the tail, single- and double-quoted runs, `\q` and `\$` inside
  double quotes at the boundary, `\#`, 300 random strings over the special
  alphabet, and 255-513 repeats of each special character.
- bash 3.2.0: every 4th of the same set, 301 inputs, 0 diffs.
- Whitespace: tab, newline, NUL-free strings with spaces are in the set; all
  expansions in the new lines are quoted.
- bash 3.2 safe: only `${#run}`, `-lt`, string append; no new syntax.

Timing re-measured (`tm.sh`): one 16384-char word 1.23 s (5.2), 3.42 s (3.2.0),
31.70 s (3.2.0 old); 1600 eight-char words 1.03 s, 1.98 s. Matches the
report's 1.2/3.5/31.7/1.1/2.1.

Defects found and fixed in the header comment of
`lib/probes-readonly-command.sh`:

1. "at most 256 characters" is false: the check is at the top of the
   iteration, and a kept backslash pair in double quotes (`\q`) appends two
   characters at run length 255, giving 257. Reworded to "about 256 characters
   (257 after a kept backslash pair)". Status: FIXED.
2. "16384 characters took ... 1.1 s as 1600 words": the measured input is 1600
   x `abcdefgh ` = 14400 characters. Sentence rewritten to the measured
   inputs. Status: FIXED.

## Mutation proof (run-join sites)

Method: exact single-occurrence replacement by `/tmp/claude/rev41/mut.py`
(`: # MUT` in place of the join line), landed proven by `command grep -n MUT`,
each `tests/probes-readonly*.bats` run one at a time, restored by swapping the
strings, `command grep -c MUT` returned 0 after each, and `git diff --stat --
lib` was empty after the last restore.

| site | result |
| --- | --- |
| a: join before the `#` test | SURVIVED (all 7 files green) |
| b: join before the `&` test | RED: operands.bats 19/1, `uniq with a second operand is a writer, uniq in.log is not` (line 315); others green |
| c: join at separator | RED: facts 1/14, globs 0/13, members 0/12, operands 1/19, pins 0/15 |
| d: join at end | RED: facts 5/10, globs 0/13, members 1/11, operands 3/17, pins 5/10 |
| e: join at top of iteration | SURVIVED (all 7 files green) |

## Survivors

1. Site a. Replacement: `word="$word$run" run=''` removed after `'#')`.
   Equivalent mutant, no test can detect it: `run` is non-empty only after a
   branch that set `invalue=1` (the `&`-after-`>` append has a non-empty word),
   and the `#` test is `[ -z "$word" ] && [ "$invalue" -eq 0 ]`, so an
   un-joined `word` cannot change the outcome. The join is harmless and the
   outline requires it. No test shape; no action.
2. Site e. Replacement: the top-of-iteration `[ "${#run}" -lt 256 ] || {...}`
   line removed. Output is unchanged by construction (the bound is performance
   only), and the outline says timing is measured, not gated. Suggested
   shape if ever wanted: not a timing test (flaky); a structural test that
   sources the lib and tokenizes a 16384-char word under a `time` budget
   far above the 3.2 figure is the only option and is rejected by the outline.
   No action.
3. 5.2 fixtures exclusion. Replacement: `tests/fixtures/*) ;;` becomes
   `tests/fixtures/*) check_cap "$file" 400 ;;` in
   `scripts/check-line-limits.sh`. All 19 cases of `check-line-limits.bats`
   stay green. Suggested test shape: in a `make_fixture_root`, write a
   401-line `tests/fixtures/x.json` and a 401-line `tests/fixtures/y.awk`, `git
   add` both, run the script, expect status 0 and empty output; pair it with a
   401-line `lib/x.json` reported with `oversized-file: lib/x.json: 401 lines >
   400`, differing only in the path. Also unpinned: the `.toml`, `justfile`
   and `*/justfile` arms (one 401-line `justfile` at root and one under
   `sub/`).

## 5.1 probes.bats

- `utf8_locale` and `index_mtime` are both loaded (`load helpers/locale`,
  `load helpers/probes` at the top of `tests/probes.bats`). Both uses are
  behaviour-preserving: the locale is the first of C.UTF-8 / en_US.UTF-8 that
  counts an em dash as one character, and a failing `loc=$(utf8_locale)` fails
  the case rather than running under a byte locale; `index_mtime` is called
  before the `stat` stub goes on PATH.
- Defect: the case's header comment still said `LC_ALL=C.UTF-8` (line 55), a
  leftover literal. Reworded to refer to the locale `utf8_locale` finds.
  Status: FIXED. No other `C.UTF-8` or `stat -c` remains in the file.
- Report states "portable by construction, unverified on a Mac". Present.

## 5.2 line caps

- Arm `*.awk | *.toml | justfile | */justfile | *.json` sits after the
  `plans/* | plugin-dev/*` no-op arm and the script arms, so those two roots
  stay excluded for every type; the nested `case` skips `tests/fixtures/*`.
- Defect: the header sentence put "except under `tests/fixtures/`" after the
  script list as well, but the script arm caps fixtures. Header split so the
  exception attaches to the awk/TOML/JSON/justfile group only. Status: FIXED.
- Mutation: `check_cap "$file" 400` in the new arm's fallback replaced by 401
  (`# MUT`): RED, 18 passed / 1 failed (the new case). Restored by swapping,
  `command grep -c MUT` 0. Fixtures-exclusion mutation: SURVIVED (Survivors 3).
- Files in scope: the script run over the repo exits 0 with no output. Largest
  tracked in-scope file of the new types is `scripts/lib/strip-code.awk` at 68
  lines.

## Fixes Applied

- `lib/probes-readonly-command.sh` header: run-length claim and cost sentence.
- `tests/probes.bats` lines 53-57: leftover `C.UTF-8` comment.
- `scripts/check-line-limits.sh` header: fixtures exception scope.
- `just precommit` after fixes (before the final comment rewrap in
  `tests/probes.bats`): passed, 401 tests, 0 failed. No `# MUT` text remains
  (`rg` over lib, scripts, tests).
