# Item 4.1 slice 3 — RED

Tests added to `tests/probes-readonly-operands.bats` (299 lines), before the
BSD section. SUT untouched except the mutation proof, restored (`git status`
shows no `lib/` change; grep for the mutated text finds nothing).

## Per-test result (`bats tests/probes-readonly-operands.bats`)

- 14 `grep -epat x.log gives the input, the -e word being the pattern` — RED:
  `grep -qxF 'readfile=x.log'` failed (line 230).
- 15 `sed -e s/a/b/ -e s/c/d/x.log in.out gives the input, never an -e
  argument` — RED: `grep -qxF 'readfile=in.out'` failed (line 244); current
  code gives `s/c/d/x.log`.
- 16 `awk -f prog.log in.err gives the input, never the program file` — RED on
  its second run, `awk -fprog.log in.err` -> `readfile=in.err` (line 269).
  The slice's own form `awk -f prog.log in.err` passes on current code (the
  pattern skip eats `prog.log` by coincidence, the -f argument being the first
  operand), so that run stays as the case's first run but cannot red it.
  The glued form leaves the skip nothing but the input, so it reds.
- 17 `grep -i | tail run.log leaves the pattern role behind in its segment` —
  passes on current code; mutation proof below.
- 18 BSD case — green, unchanged.
- 1-13 green, unchanged.

## Choice of the reset pin

`grep -i | tail run.log`. The `-i` is neither `-e` nor `-f`, so after the
slice the grep segment still ends with the role unconsumed whatever slice 3
does with `-e`/`-f`/`--regexp=`; the next segment's `run.log` is then the
candidate only if the reset runs. Slice 4 (`uniq`) does not affect it.

## Mutation proof

- Test 17: replaced `seg_first=1 seg_ok=1 in_seg=0 pat=0 lt=0` (once in the
  SUT) with `seg_first=1 seg_ok=1 in_seg=0 lt=0`. Re-run: test 17 red on
  `grep -qxF 'readfile=run.log'` (line 284); 14 and 15 red as before. Restored
  by the inverse replacement; `grep -c 'in_seg=0 lt=0'` on the SUT gives 0,
  `git status --short lib` is empty, and the re-run was back to the
  pre-mutation result (test 17 ok).

`shellcheck` on the bats file reports only SC1091 info on `source`, as for
the file's existing setup line.
