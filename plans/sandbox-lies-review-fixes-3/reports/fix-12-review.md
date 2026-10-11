# Review of fix 12 (commit 9087e61)

Verdict: sound; one cosmetic defect fixed, one limitation noted.

- (a) No case lost or weakened. `git show 9087e61^:tests/check-line-limits.bats`
  (21 cases, 400 lines) against the union of the two files: every `@test`
  and every assertion line of the old file is present, byte for byte (sorted
  line diff shows only added lines: the new header comments, the new `load`
  and `SCRIPT` lines in the new file, and the one new case). `bats --count`
  15 + 7 = 22.
- (b) The fixtures case comment carries the three original lines
  (`Over the cap, under tests/fixtures/ ...`, `... under lib/ pin the cap,
  and an arm ...`, `fixture lines too.`) followed by the one line 4b80e0c
  added. The 4b80e0c cut is a substitution of those three lines by that one;
  the restore keeps both, nothing else shortened.
- (c) The new file loads `helpers/bsd-stubs`. `scripts/check-line-limits.sh`
  has no `wc` call (it counts with `awk 'END { print NR }'`); the only
  stubbed-tool call is `mktemp` in `scripts/lib/tracked.sh`. The case calls
  `make_bsd_stubs "$bsd" mktemp` and runs the script with `PATH="$bsd:$PATH"`,
  so the stub really is on PATH. Limitation: the script's template
  (`${TMPDIR:-/tmp}/check-line-limits.XXXXXX`) ends in X, which the stub
  hands to the real `mktemp`, so the case would not fail were the script to
  call a bare `mktemp` (the stub passes an empty template through). It would
  fail only on a non-trailing-X template whose file already exists. This is the same
  weakness the sibling markdown case documents; the new case states it is a
  smoke run, not mutation-proven. It duplicates the sibling's coverage on a
  script-type file rather than adding a distinct detection; accepted per the
  dispatch rule that one case is re-run with stubs.
- (d) 280 and 153 lines (the cap is 400).
- (e) `scripts/run-bats.sh` for each file, one at a time: 15 passed and 7
  passed, 0 failed. `shellcheck -x scripts/check-line-limits.sh` clean.
- Defect fixed: two consecutive blank lines before the new BSD case in
  `tests/check-line-limits-types.bats`; reduced to one.

## Precommit

`just precommit`, unsandboxed foreground: passed (plugin.json, hooks.json,
shellcheck, bash -n, rumdl, line limits, links, python compile, tests; 414 passed).
