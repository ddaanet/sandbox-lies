# Minor batch D review

## Finding 10: BSD-stub case removal

Confirmed. A grep of lib/verdicts.sh for sed, grep, awk, tr, cut, wc, stat,
mktemp, cat, head, tail, date, od, basename, dirname, git, sort, find, ls and
the like, over non-comment lines, finds only words inside printf message text.
Every `$(...)` runs a library function (`_lock_rerun`, `_lock_retry`,
`_readonly_match_list`); the one process substitution is `printf` (builtin).
The file sources nothing. No stubbed tool is called, so a stubs-first re-run
could not fail for a BSD reason. The suite header says why and the suite still
loads helpers/bsd-stubs. No defect.

## Finding 11: assert_unescaped_dir

- Single place: tests/helpers/probes.bash; called from the `setup` of
  probes.bats, probes-config.bats, probes-readonly.bats (all load the helper).
  The two inline guards are gone.
- Literal count: the review brief says 16; actual
  `path=...$BATS_TEST_TMPDIR` literals are 18 (probes.bats 4, probes-config 1,
  probes-readonly 13), all inside the three guarded suites. The setup guard
  covers every case, so the count does not matter.
- Byte coverage: the test is the encoder's own, so it flags exactly what
  `printf %q` changes. Run by hand against `/x/<name>`: blank, single and
  double quote, backslash, dollar, newline, non-ASCII (under LC_ALL=C), tab,
  semicolon, star, comma, bang all fail; `~` mid-name, `=`, `:`, `%`, `+`,
  `@`, `#` pass because %q leaves them alone (so the literals stay correct).
- Removed probes-config assertions: each followed `[ "$output" = mask ]` or
  `= gone`. With that equality true the output is one line, neither `orphan`
  nor `held`, with no `path=` or `pid=` line, so none could fail alone; none
  weakened. The `-z "$stderr"` checks stay.

## Defect fixed

The helper's case covered four byte kinds; backslash, dollar, newline and
double quote were not exercised. Added them to the loop in tests/probes.bats
and updated its comment. Case green.

## Mutation proof

Mutation (one): in the helper, `"$dir"` in the test replaced by
`"${dir// /_}"` on both sides (blanks ignored). `command grep -c` found it
(1). Case "assert_unescaped_dir fails for a directory name holding a byte %q
escapes" went red on its own assertion: `[ "$status" -eq 1 ]`, "name a\ b
passed". Restored by the swapped replacement; `command grep -c 'dir// /_'`
gave 0; the case is green.
