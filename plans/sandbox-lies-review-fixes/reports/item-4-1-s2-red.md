# Item 4.1 slice 2 — RED report

Saved by the orchestrator from the test-driver's reply: the harness refused the
agent's own Write of this file.

Tests added to `tests/probes-readonly-members.bats`, section "readfile operand
rule", after the `wc -l<build.log` case, uncommitted. Each runs through
`probe_readonly_path` on a `writable` refusal with the command given, and
asserts status 0, empty stderr, first line `writable` and the exact
`readfile=` line. Where a pattern or program word is shaped like a log name,
each also asserts a negative `run ! grep -qxF`. SUT untouched; no mutation
needed.

## Per-test output (`bats tests/probes-readonly-members.bats`)

    not ok 12 grep x.log y.out gives the input, never the pattern
    # (in test file tests/probes-readonly-members.bats, line 222)
    #   `printf '%s\n' "$output" | grep -qxF 'readfile=y.out'' failed
    not ok 13 sed s/a/b/x.log in.out gives the input, never the program
    # (in test file tests/probes-readonly-members.bats, line 237)
    #   `printf '%s\n' "$output" | grep -qxF 'readfile=in.out'' failed
    not ok 14 awk x.log in.err gives the input, never the program
    # (in test file tests/probes-readonly-members.bats, line 251)
    #   `printf '%s\n' "$output" | grep -qxF 'readfile=in.err'' failed
    ok 15 sed s/a/b/ in.log still gives the input
    ok 16 the member facts survive BSD grep, sed, stat and wc

Tests 1–11 and 16 (pre-existing) still pass. The three new red tests fail on
the wrong-value assertion: the current code takes the first log-shaped word
(`x.log`, `s/a/b/x.log`) as the candidate.

## Guard

`sed s/a/b/ in.log still gives the input` passes on current code by design
(the slice says "still"): `s/a/b/` is not log-shaped, so `in.log` is the
candidate with or without the operand rule. A guard; no red or mutation proof
needed.

## Note on the awk case

The suggested `awk /x.log/ in.err` already passes on current code, because
`/x.log/` does not end in `.log`, so it would be vacuous. The case uses
`awk x.log in.err` instead, which reds.

## Mutation proof

None required: every new test other than the named guard reds without one.
