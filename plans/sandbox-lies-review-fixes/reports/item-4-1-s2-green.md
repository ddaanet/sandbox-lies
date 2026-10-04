# Item 4.1 slice 2 — GREEN report

## Change

`_readonly_readfile_arg` in `lib/probes-readonly-command.sh`: a per-segment
`pat` flag is set when the segment's command word is `grep`, `sed` or `awk`
and reset at each `|`. The first later word that is not an option (not
opening with `-`) and holds no `<` consumes the flag and is skipped as the
pattern or program, never a readfile candidate. A word holding `<` is a
redirection: it neither consumes the flag nor loses its candidate role. An
`is_cmd` local keeps the command word itself from consuming the flag.
Slice 1's option rule, the writer arms and the header comment are unchanged.

## Tests going green (in order, `bats tests/probes-readonly-members.bats`)

All of 12 (`grep x.log y.out`), 13 (`sed s/a/b/x.log in.out`), 14
(`awk x.log in.err`), 16 (`grep -i x.log y.out`), 17
(`grep x.log a.out b.err`) and 18 (`sed ... | grep x.log y.out`) went green
from the one rule; guard 15 and tests 1–11, 19 stayed green. 19/19 ok.

## Full suite and gate

`just precommit`: 288 passed, 0 failed; line
`precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests`.
No warnings reported.
