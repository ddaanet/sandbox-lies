# Item 4.1 slice 3 — GREEN

## Change

`lib/probes-readonly-command.sh`, `_readonly_readfile_arg` (277 lines): a new
`arg` flag (reset per segment). For grep, sed and awk, a separate `-e`/`-f`
clears the pattern role and sets `arg`, so the next word is skipped as its
argument; a glued `-eX`/`-fX` clears the role. Clustered (`-ne`) and long
forms are untouched, and the in-code comment says so. No test edited.

## Tests

Fixes were one rule in one edit, so tests 14, 15 and 16 went green together
rather than one at a time (14 needs the glued rule, 15 the argument skip,
16 both). `bats tests/probes-readonly-operands.bats`: 1-18 ok, including 17
(reset pin) staying green.

## Full suite

`just precommit`: `bats: 295 passed, 0 failed`; `precommit passed:
plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links,
tests`. No complexity or line-limit warnings.
