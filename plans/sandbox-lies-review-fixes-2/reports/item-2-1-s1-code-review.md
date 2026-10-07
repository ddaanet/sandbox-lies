# Review: Item 2.1 / slice 1 code (m-11 glob and `$` skip)

**Scope**: `git show HEAD -- lib/probes-readonly-command.sh` (commit subject
`Item 2.1/1 — skip glob and $ readfile candidates`), read in the context of the
whole `_readonly_readfile_arg`. Tests read for mutation testing:
`tests/probes-readonly-globs.bats`, `tests/probes-readonly-operands.bats`.
**Date**: 2026-10-07 **Mode**: review + fix (TDD code review, dispatch
`item-2-1-s1-code-review`)

## Summary

The bracket expression is correct under bash 5.2 and bash 3.2, and the skip sits
at the candidate site, so a glob in grep's pattern slot does not shift which
word is the input. One defect: the skip tested the whole word, while the
candidate is the text after the last `<`. A glob or `$` ahead of a glued `<`
therefore withheld a literal redirected name: `grep 'err.*'<x.log` and
`grep "$p"<x.log` printed no `readfile=x.log`. That is the safe side, but it
contradicts Q4's rule ("a candidate holding …"). Fixed behind a test shown red
first. The comment was reworded and moved into the function header, beside the
parallel newline rule. All eight mutations went red, and none survived.

**Overall Assessment**: Ready

## Issues Found

### Critical Issues

None.

### Major Issues

1. **The skip tested the whole word, not the candidate after the last `<`**
   - Location: `lib/probes-readonly-command.sh:236` (`case "$word" in` inside
     the `*.log | *.output | *.out | *.err)` arm)
   - Problem: the candidate is `${word##*<}`, but the metacharacter test read
     `$word`. In `grep 'err.*'<x.log` the tokenizer yields one word,
     `err.*<x.log`. The pattern-slot logic correctly treats `err.*` as the
     pattern and `x.log` as input, but the `*` ahead of the `<` skipped the word
     and no readfile= line was printed. The same applied to `grep "$p"<x.log`.
     Checked directly on the green code: both gave an empty readfile value.
   - Fix: test `${word##*<}`, the same text the candidate takes.
   - **Status**: FIXED. The test came first: new case 10,
     `a glob or $ ahead of a glued < keeps the redirected name`, was red on the
     green code at line 132
     (`[ "$(grep '^readfile=' <<<"$output")" = readfile=x.log ]`). It is green
     after the fix. Mutations M7 and M8 below show it red again.

### Minor Issues

1. **The comment was inaccurate after the fix, and not in the contract**
   - Location: `lib/probes-readonly-command.sh:229-230` (green), and the
     function header (`:122-139`)
   - Note: "A word holding … is no name" names the word, not the candidate. "No
     quote state is kept" understates the mechanism: the tokenizer has already
     removed the quotes. The function header states the rule's contract,
     including the parallel newline rule ("A name holding a newline … is passed
     over"), but not the new skip.
   - **Status**: FIXED. Two site lines were removed. The header's newline
     sentence now continues: "and so is one holding *, ?, [ or $, a glob or an
     expansion: quoted too, since the tokenizer has removed the quotes."
     Rewrapped at 80 columns. The file stays at 304 lines.

2. **The `<` forms of the skip were unpinned**
   - Location: `tests/probes-readonly-globs.bats`
   - Note: `cat <*.log` (a lone `<`, which the tokenizer keeps glued as
     `<*.log`) and `wc -l<$x.log` were skipped correctly, but no case held a
     `<`. A skip that tested the text ahead of the `<` would have passed every
     case.
   - **Status**: FIXED. New case 11,
     `a glob or $ after < is skipped, lone or glued`, pairs each form with its
     literal (`cat <x.log`, `wc -l<x.log`, each giving `readfile=x.log`). It is
     green on the fixed code by design, and M8 shows it red.

### Checked, no finding

- **Bracket `*[*?[\$]*`, bash 5.2.37 and bash 3.2.** Bash 3.2.0 was built from
  GNU source; its `lib/glob` is byte-identical to 3.2.57's (`diff -rq`), which
  is what macOS ships. Under both shells, the words `*.log`, `run?.log`,
  `run[12].log` and `$OUT.log` are skipped, and `x.log`, `a\b.log`, `a]b.log`,
  `a-b.log` and `run1].log` are kept. So the class is exactly `* ? [ $`: the
  `\$` adds no backslash, and the inner `[` opens no nested class. The fixed
  function gives the same readfile values under both shells for ten commands,
  including all the `<` forms below. Bats itself does not run under bash 3.2.0
  (bats line 207 fails to parse), so that check ran the function directly.
- **`<` forms on the fixed code.** `wc -l<$x.log` and `cat <*.log` (tokenized
  `<*.log`): no candidate. `cat 2<*.log`: no candidate. `wc -l<x.log` and
  `cat <x.log`: `x.log`. `grep 'err.*'<x.log` and `grep "$p"<x.log`: `x.log`.
- **Pattern slot.** The skip only withholds a candidate. It never `continue`s,
  and it runs after the pat 1 and pat 2 logic, so a glob in the pattern still
  consumes the pattern slot (case 8, M6).
- **uniq operand counting and `>` detection** run before the skip and are
  unaffected by it.
- **Shellcheck** is clean on the library.

## Mutation testing

Per `delegate-status.md` §Mutation testing. Every mutation was an exact string
replacement in `lib/probes-readonly-command.sh`, made by a Python driver that
refuses unless the source string occurs exactly once. Each mutation was proven
landed with `command grep` (`-cF` count 1, or `-n -A1` on the arm line for the
two-line M7 and M8), then restored by the swapped replacement and proven with
the same grep (count 0, or the arm line back to `case "${word##*<}" in`). Each
mutation ran `tests/probes-readonly-globs.bats`, then
`tests/probes-readonly-operands.bats`, one process at a time in the foreground.
Operands stayed 20/20 under every mutation.

Restore incident: M8's first form replaced `case "${word##*<}" in` with
`case "${word%%<*}" in`, a string that already occurs twice in the file (lines
181 and 208). The driver's swapped replacement refused, because it would not
have been unique. The edit was reversed instead through its unique two-line
context (`*.out | *.err)` plus the next line). The restore was proven: the arm
line read `case "${word##*<}" in`, and the `%%<*` count was back to its
pre-existing 2. M8 was then re-run in its two-line form (the table row).

| behaviour | mutation | red or survived (and fixed) |
| --- | --- | --- |
| `*` in the skip class | M1: drop `*` (`*[?[\$]*`) | red: cases 1 (l.35), 6 (l.85), 9 (l.121), 11 (l.146), 12 (l.175) |
| `?` in the skip class | M2: drop `?` (`*[*[\$]*`) | red: case 3 (l.54) |
| `[` in the skip class | M3: drop `[` (`*[*?\$]*`) | red: case 4 (l.63) |
| `$` in the skip class | M4: drop `$` (`*[*?[]*`) | red: cases 2 (l.45), 7 (l.100), 11 (l.154) |
| skip, not stop | M5: `*[*?[\$]*) break ;;` | red: cases 6 (l.85), 7 (l.100), 12 (l.175) |
| skip at the candidate site, not the loop head | M6: `case "$word" in *[*?[\$]*) continue ;; esac` replacing the `# not_op:` comment line | red: cases 8 (l.110), 10 (l.132) |
| skip tests the name after the last `<` (this review's fix) | M7: arm reverts to `case "$word" in` | red: case 10 (l.132) |
| skip tests the redirected side of `<`, not the text ahead of it | M8: arm becomes `case "${word%%<*}" in` | red: cases 10 (l.132), 11 (l.146) |

No mutation survived, so no further test or fixture fix was needed. Under M7,
case 10 stops at its first half (`grep 'err.*'<x.log`). Its second half,
`grep "$p"<x.log`, gave an empty readfile value on the green (pre-fix) code when
run directly, so it reds on its own as well.

Final state: `tests/probes-readonly-globs.bats` 12/12 and
`tests/probes-readonly-operands.bats` 20/20 green. `git diff` shows only the
intended changes in `lib/probes-readonly-command.sh` and
`tests/probes-readonly-globs.bats`. `plans/…/delegate-status.md` was already
modified before this dispatch and was not touched.

## Fixes Applied

- `lib/probes-readonly-command.sh:236`: `case "$word" in` became
  `case "${word##*<}" in`, so the skip tests the candidate itself.
- `lib/probes-readonly-command.sh:135-141`: the skip rule moved into the header,
  beside the newline rule. The two site comment lines were removed.
- `tests/probes-readonly-globs.bats`: case 10 (a glob or `$` ahead of a glued
  `<`), written first and red on the green code. Case 11 (a glob or `$` after a
  lone or glued `<`), a guard proven by M8. Each `$` line carries the file's
  existing SC2016 inline disable, with its reason.

## Files changed

- `lib/probes-readonly-command.sh`
- `tests/probes-readonly-globs.bats`
- `plans/sandbox-lies-review-fixes-2/reports/item-2-1-s1-code-review.md` (this
  report)

## Gate

`just precommit` (unsandboxed, foreground): exit status 0. Bats: 348 passed, 0
failed. Recap line: "precommit passed: plugin.json, hooks.json, shellcheck, bash
-n, rumdl, line limits, links, tests". The run exceeded the Bash tool's 600 s
limit and the harness moved it to the background. It was not restarted. Its exit
status and output were read from the completed task. Nothing was committed.

## Requirements Validation

| Requirement | Status | Evidence |
| --- | --- | --- |
| Q4: a candidate holding `*`, `?`, `[` or `$` is skipped | Satisfied | M1 to M4. The candidate, not the whole word, after this fix (M7, M8) |
| Q4: quoted or not | Satisfied | case 9; the header states it |
| Later literal still taken | Satisfied | M5 |
| Slice 3: no over-broad skip | Satisfied | cases 5, 8 and 10; M6, M7 |
| NFR-2 (macOS bash 3.2) | Satisfied | bracket and function checked under bash 3.2 (same `lib/glob` as 3.2.57) |

## Positive Observations

- The skip sits at the candidate site, so the pattern-slot logic is untouched.
  M6 confirms that the test review's recommendation was followed.
- The class `*[*?[\$]*` is minimal and portable: no extglob and no `[[ ]]`.
