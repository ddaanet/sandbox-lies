# Item 4.1 slices 7-8 (and the carried stdin test) — GREEN

Executed in session by the orchestrator, not dispatched: all three tests
(`every lock fixture yields its verdict`, `no probe without a verdict`,
`probe reads the result text on stdin`) pass against the implementation from
slices 1-6 and carry mutation proofs in `item-4-1-s7-red.md`, reproduced with
different mutations in `item-4-1-s7-test-review.md`. No implementation
change was needed, so GREEN is the gate run and the commit.

`direnv exec . just precommit`: `bats: 147 passed, 0 failed`;
`precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line
limits, links, tests`.

`tests/hook-locks.bats` is at 382 lines; slice 9 goes in
`tests/hook-cap.bats`.
