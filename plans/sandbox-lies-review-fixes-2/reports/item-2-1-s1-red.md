# Item 2.1 / slice 1 — RED report

New file `tests/probes-readonly-globs.bats` (operands suite is at 373 lines, so
the six cases sit apart). It loads `helpers/bsd-stubs`, `git-env`, `probes` and
uses `assert_no_readfile`. `lib/` untouched (`git status --short lib` empty).
Run: `scripts/run-bats.sh tests/probes-readonly-globs.bats` -> 1 passed,
5 failed.

Each negative sits in the same case as a positive over the same command shape
minus the metacharacter. `assert_no_readfile` also requires status 0, empty
stderr and first line `writable`, so an empty probe or a command rejected
before the scan cannot pass the negative.

Case 5 check: `grep pat *.log x.err` — `pat` is grep's pattern, `*.log` is
the first input and the candidate today, `x.err` the second. After the skip
`x.err` is the expected candidate, so the command was kept as given.

## Per-test results

1. `grep -l pat *.log gives no readfile for the glob` — RED.
   Failing line: `assert_no_readfile' failed, expected nonzero exit code!`
   (tests/helpers/probes.bash:248, from test line 35). Positive half
   (`grep -l pat x.log` -> `readfile=x.log`) passes.
   - Fails when: the probe prints `readfile=*.log` (today).
   - Else could produce the observable: nothing for the red. For a green:
     probe printing nothing or rejecting the command (excluded by the
     `writable` first-line check and by the positive half over the same shape).
2. `cat $OUT.log gives no readfile for the expansion` — RED, same assertion
   (test line 44). Fails when `readfile=$OUT.log` is printed. Pair: `cat
   OUT.log`.
3. `cat run?.log gives no readfile for the ? glob` — RED (test line 53). Pair:
   `cat run1.log`.
4. `cat run[12].log gives no readfile for the [ glob` — RED (test line 62).
   Pair: `cat run1.log`.
5. `cat x.log still gives readfile=x.log` — GREEN on unchanged code (guard
   against an over-broad skip). Fails when the skip catches plain names or the
   scan yields no candidate. Mutation-proven below.
6. `a skipped glob does not hide a later literal candidate` — RED at test line
   84, `printf ... | grep -qxF 'readfile=x.err'` failed (today the first
   candidate `*.log` wins). Positive pair `grep pat a.log x.err` ->
   `readfile=a.log` passes. Fails when the glob is kept as candidate or the
   skip aborts the scan; the final `run ! grep -qxF 'readfile=*.log'` rules
   out the glob as the printed value.

## Mutation proof

One mutation for all, applied per test and restored after each. String pair:
`candidate="${word##*<}"` <-> `candidate=""` in
`lib/probes-readonly-command.sh` (occurs once). After each application
`command grep -c 'candidate=""'` gave 1; after each restore it gave 0, and the
test file's state returned to its pre-mutation result (case 5 green again, the
red cases red on their negative line).

- Test 5 (`cat x.log still ...`): red at test line 70 on
  `grep -qxF 'readfile=x.log'`. Restored: 1 passed.
- Test 1 positive half: red at line 32 (`readfile=x.log`).
- Test 2 positive half: red at line 41 (`readfile=OUT.log`).
- Test 3 positive half: red at line 50 (`readfile=run1.log`).
- Test 4 positive half: red at line 59 (`readfile=run1.log`).
- Test 6 positive half: red at line 78 (`readfile=a.log`).

Tests 1-4 and 6 are red on unchanged code for their negative half; the
mutation shows their positive halves discriminate on their own line, distinct
from the negative line. (A `-f 'cat run?'` filter matched tests 3 and 4 both
in one run; both went red at their own positive line.) Final run after all
restores: 1 passed, 5 failed, `lib` clean.
