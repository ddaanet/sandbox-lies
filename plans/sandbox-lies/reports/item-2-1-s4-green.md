# Item 2.1 slice 4: GREEN

Scope: make the six slice-4 tests in `tests/check-line-limits.bats` pass —
the root-anchored `plans/`/`plugin-dev/` exclusion and the script arm for
`.sh`/`.bash`/`.bats`/`.py` at cap 400 in `scripts/check-line-limits.sh`, plus
the header Scope comment and a position comment on the exclusion arm.

## Change

`scripts/check-line-limits.sh`:

- Header Scope comment: added the script scope (`.sh`, `.bash`, `.bats`,
  `.py`, cap 400, except under a root-level `plans/` or `plugin-dev/`).
- New first `case` arm: `plans/* | plugin-dev/*) ;;`, with a comment stating
  it must precede the script arm (`case` takes the first match) and that an
  unadorned `plans/*` is root-anchored — it matches only a path that starts
  with it, so `tools/plans/x.sh` still reaches the script arm and gets
  counted, per `oversized script is reported`'s fixture.
- New last `case` arm: `*.sh | *.bash | *.bats | *.py) check_cap "$file" 400
  ;;`. Position among the markdown arms is not load-bearing (slice 3's code
  review and the test review both confirm this), so it was appended after
  `*.md`; only its position relative to the new exclusion arm is commented.

## Verification

- `scripts/run-bats.sh tests/` (foreground): `bats: 39 passed, 0 failed`.
- `direnv exec . just precommit` (foreground): `precommit passed:
  plugin.json, shellcheck, bash -n, rumdl, tests`.
- `scripts/check-line-limits.sh .` on the real tree (foreground): exit 0, no
  output — no tracked script or markdown file is over its cap.

## Files changed

- `scripts/check-line-limits.sh` (exclusion arm, script arm, header comment).
- `tests/check-line-limits.bats` (slice-4 tests, already present from RED/test-review).
- `plans/sandbox-lies/reports/item-2-1-s4-red.md`,
  `plans/sandbox-lies/reports/item-2-1-s4-test-review.md` (carried from
  earlier stages, committed alongside).

## Done

GREEN complete. All six slice-4 tests pass; full suite, precommit and the
real-tree gate are clean.
