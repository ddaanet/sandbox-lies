# Review: Item 4.1 slice 1 — code review (after GREEN)

Saved by the orchestrator from the corrector's reply: the harness refused the
corrector's own Write of this file.

**Overall assessment:** Ready. One regression found and fixed, with a new
test. `just precommit` passed (exit 0, 281 bats passed). Nothing committed.

**Scope:** the slice commit's change to `_readonly_readfile_arg` in
`lib/probes-readonly-command.sh` (the candidate `case` gaining `-*`). Read the
whole function, plus `_readonly_print_facts` in
`lib/probes-readonly-facts.sh`, which calls it, and `lib/verdicts.sh`, which
turns `readfile=` into the re-run act.

## Summary

The one-line change implements D4's first clause: an option word (short, or
`--opt=value`) is never a `readfile=` candidate. It sits only in the candidate
`case`, so none of the writer checks changed and all still fire: `sed -i`,
`sort -o`/`--output`, `awk -i`/`--include` and `>` words.

One regression: the tokenizer does not split on `<`. So an option glued to an
input redirection, like `wc -l<build.log`, reaches this function as one word
starting with `-`. The new `-*` arm dropped that redirected input name, which
the code before the slice had found.

## Shapes checked

Sourced the library and ran the tokenizer, then `_readonly_readfile_arg`, on
each command below.

| Command | Before fix | After fix |
| --- | --- | --- |
| `cat <x.log`, `cat < x.log`, `cat 0<x.log` | x.log | x.log |
| `cat -<x.log` | none | x.log |
| `wc -l<build.log` | none | build.log |
| `wc -l <-x.log` | -x.log | -x.log |
| `cat - x.log` (lone `-`) | x.log | x.log |
| `cat -- x.log` | x.log | x.log |
| `cat -- -x.log` | none | none |
| `grep --include=*.log pat build.log` | build.log | build.log |
| `grep -r --include=*.log pat .` | none | none |
| `sed -i s/a/b/ x.log`, `sort -o out.log in.log`, `grep pat x.log > y.txt` | none | none |

- **Lone `-` and `--`:** never candidates, since they have no output-name
  suffix.
- **`<-x.log`:** keeps `-x.log`. The word starts with `<`, and a redirection
  target is a file being read.
- **BSD / bash 3.2:** `[!-]*` and `*'<'*` are POSIX `case` patterns, and the
  file already uses `-[!-]*`. No new external command, array or expansion.
- **Whitespace:** no new word splitting.

## Issues

### Critical

None.

### Major

None.

### Minor

1. **An option word glued to an input redirection lost its candidate** —
   FIXED
   - Location: the candidate `case` in `_readonly_readfile_arg`.
   - Problem: the tokenizer splits only on blanks, `|`, `;`, `&` and newline,
     so `-l<build.log` stays one word. `-*` matched it before the `*.log` arm,
     so `wc -l<build.log` and `cat -<x.log` lost a `readfile=` they had before
     the slice. The safe side (the verdict falls back to the generic act), but
     a regression on an unquoted shell form.
   - Fix: the candidate arm is now `[!-]* | *'<'*`, with the old suffix `case`
     nested inside, and a two-line comment above it naming D4 and the
     `wc -l<x.log` exception.
   - New test: `wc -l<build.log gives the redirected name despite the leading
     option`, in the operand-rule section of
     `tests/probes-readonly-members.bats`. It failed against the slice commit's
     code on its `readfile=build.log` assertion and passes after the fix.
   - Trade-off: a quoted `<` inside an option's value (`-e'<x.log'`) now gives
     a candidate. A quoted `<` in a word that is not an option (`'<x.log'`)
     already did this before the slice, because the tokenizer does not track
     whether a `<` was quoted — consistent with the existing redirection
     handling, not new behaviour.
2. **Header comment does not mention the option rule** — DEFERRED. Nothing it
   says is false; the item's Docs step owns the function's header comment.
3. **A file whose name starts with `-`, passed after `--`, is never a
   candidate** — DEFERRED. `cat -- -x.log` gets no `readfile=`. D4 says a word
   starting with `-` is never input, so this follows the decision and stays on
   the safe side. It belongs in the `readfile=` residuals of
   `docs/references/readonly-path.md` in the Docs step.

## Fixes applied

- `lib/probes-readonly-command.sh` `_readonly_readfile_arg`: words containing
  a newline are still passed over; a word that does not start with `-`, or that
  contains `<`, is checked against the output-name suffixes and stripped
  through the last `<`. Comment added.
- `tests/probes-readonly-members.bats`: one new test for `wc -l<build.log` →
  `readfile=build.log`, also asserting status 0, empty stderr and `writable` as
  the first line.

## Mutated-SUT run

Replaced the arm `*"$nl"* | -*) ;;` with `*"$nl"* | --*) ;;` (long options
only), ran the slice's three tests, then reversed the replacement (`git diff`
empty afterwards):

- `grep --include=*.log gives the operand, never the option`: passed (long
  option only).
- `awk -vout=run.log gives the operand, never the short option`: failed on
  `readfile=in.err`.
- `grep -r --include=*.log pat . gives no readfile`: passed (long option only).

The short-option test is what catches a long-options-only version; the forms
are needed together.

## Requirements validation

- FR-4 / D4 clause 1 (an option word is never input): satisfied — the
  candidate `case` and the operand-rule tests in
  `tests/probes-readonly-members.bats`.
- Slices 2–4 not reviewed.

## Recommendations for the Docs step

The `readfile=` residuals should state that a file whose name starts with `-`,
passed after `--`, is not taken; and that a `<` anywhere in a word counts as an
input redirection, quoted or not.
