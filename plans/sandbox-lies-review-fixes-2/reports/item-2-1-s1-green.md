# Item 2.1 / slice 1 — GREEN report

Change in `lib/probes-readonly-command.sh`: at the candidate site (inside the
`*.log | *.output | *.out | *.err` arm) a word holding `*`, `?`, `[` or `$` is
skipped, so the next literal candidate is still taken. The comment above the
option/candidate `case` states the skip and the quoted-literal over-skip.

## Order made green

The skip is one `case` guard, so the ten cases of
`tests/probes-readonly-globs.bats` turned green together on that one edit;
they were not grown separately. Before the edit, 2 passed and 8 failed (per the
test review). After it (`scripts/run-bats.sh tests/probes-readonly-globs.bats`):
10 passed, 0 failed:

1. `grep -l pat *.log` gives no readfile
2. `cat $OUT.log` gives no readfile
3. `cat run?.log` gives no readfile
4. `cat run[12].log` gives no readfile
5. `cat x.log` still gives readfile=x.log (guard)
6. skipped glob does not hide a later literal
7. skipped `$` does not hide a later literal
8. metacharacter in grep's pattern leaves readfile=x.log (guard)
9. quoted `'*.log'` skipped too
10. BSD re-run of case 6

## Full suite and precommit

`just precommit` (unsandboxed, foreground): bats 346 passed, 0 failed;
"precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line
limits, links, tests"; exit status 0. No warnings printed.
