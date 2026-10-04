# Item 4.1 slice 1 - GREEN

Change: in `_readonly_readfile_arg` (`lib/probes-readonly-command.sh`) the
candidate case now skips a word opening with `-` (`*"$nl"* | -*) ;;`), so an
option or `--opt=value` is never a `readfile=` candidate. Writer arms untouched.

Tests made to pass, in order (all three failed before the one-line change):

1. `grep --include=*.log gives the operand, never the option` - ok
2. `awk -vout=run.log gives the operand, never the short option` - ok
3. `grep -r --include=*.log pat . gives no readfile` - ok

`bats tests/probes-readonly-members.bats`: 11/11 ok.

Full suite: 280 passed, 0 failed.
Gate: precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests
