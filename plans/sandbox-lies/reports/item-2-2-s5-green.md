# Item 2.2 slice 5 — GREEN

Executed in session by the orchestrator, not dispatched: the slice adds no
behaviour. Every one of its eight tests pins a fix an earlier code review
already shipped (slices 1, 3 and 4), and each is proven by mutation in
`item-2-2-s5-red.md`, reproduced with a different mutation in
`item-2-2-s5-test-review.md`. A GREEN dispatch would have had no
implementation to write.

## What this commit carries

- `tests/check-links.bats` — the slice's tests as the test review left them,
  minus the edge-input tests moved out (below).
- `tests/check-links-edges.bats` — new: this slice's edge-input tests; slice
  6's shared-walk tests and slice 7's BSD case join it.
- `tests/helpers/fixture-root.bash` — new: the fixture-root helper and
  `setup` the check suites duplicated, loaded by both link suites and by
  `tests/check-line-limits.bats`.
- `tests/check-line-limits.bats` — loads the helper instead of its own copy.

The split was forced by the gate this item's sibling ships:
`tests/check-links.bats` reached 409 lines, over the 400-line cap
`scripts/check-line-limits.sh` enforces on tracked `.bats` files.

## Runs

- `scripts/run-bats.sh tests/`: `bats: 60 passed, 0 failed`.
- `just precommit`: `precommit passed: plugin.json, shellcheck, bash -n,
  rumdl, line limits, tests`.
- `scripts/` unchanged from the slice-4 code-review commit.

## Code review

No implementation file changed in this slice, so the slice's code review has
an empty scope and was not dispatched. The test-side restructuring (the
helper extraction) was done and checked by the slice's test review, which
ran with the opus reviewer.
