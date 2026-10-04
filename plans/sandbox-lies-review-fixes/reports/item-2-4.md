# Item 2.4 report

New file `tests/probes-readonly-members.bats` (loads `helpers/bsd-stubs` and
`helpers/probes`), 8 cases, sections per member group. On unchanged code
`git switch feat` with refused path `<repo>/a` gives `match=a` (no deviation).

## Cases

1. git switch, rebase and cherry-pick each give merge=1
2. git switch feat in a scratch repo gives target=feat and match=a
3. cat build.out and tail run.err give readfile
4. sort -o out.log withholds readfile, plain sort gives it
5. sort --output=out.log withholds readfile, plain sort gives it
6. awk -i inplace withholds readfile, plain awk gives it
7. awk --include withholds readfile, plain awk gives it
8. the member facts survive BSD grep, sed, stat and wc (stubs for grep sed
   stat wc)

## Faults (scratch copy under /tmp/claude-1000/sl/scratch-2-4, one at a time, deleted afterwards)

- subcommand case cut to `merge | pull | checkout`: red 1 (merge=1 line
  absent for switch), 2 (merge=1/target=feat), 8.
- `*.out | *.err` removed from the readfile name case: red 3 (readfile=build.out
  absent), 8.
- `sort:-o*` arm removed: red 4 (no-readfile assertion: readfile=out.log
  appears), 8. The `sort:-[!-]*o*` arm does not catch `-o`, so the fault is
  live.
- `sort:--output*` arm removed: red 5.
- `awk:-i*` arm removed: red 6.
- `awk:--include*` arm removed: red 7.

Each negative assertion is paired in its case with the tool's plain reader
form giving `readfile=`.

## Gate

precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests
(bats: 268 passed, 0 failed)
