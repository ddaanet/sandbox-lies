# Item 5.2 pin: line-cap survivors (review survivor 3)

Mode: GREEN (mutation-killing). Scope: `tests/check-line-limits.bats` only.
The script and the reviewer's uncommitted fixes in
`scripts/check-line-limits.sh`, `lib/probes-readonly-command.sh` and
`tests/probes.bats` are not altered by this dispatch; they ride the commit.

## Tests added

The suite had 19 cases; it has 21 now, all green on the unchanged script.

1. `fixtures are out of the awk, TOML and JSON cap`. Fixture: 401-line
   `tests/fixtures/x.json`, 401-line `tests/fixtures/y.awk`, 401-line
   `lib/x.json`, all `git add`ed. Assertion: status 1 and exact output
   `oversized-file: lib/x.json: 401 lines > 400`. The status-0 empty-output
   form asked for in the outline cannot hold beside a reported `lib/x.json`,
   so the fixture-only exclusion is pinned by the exact single-line output:
   any fixture line added to the output fails it. The state that fails it: the
   fixtures arm caps `tests/fixtures/*`. Nothing else can produce an output of
   exactly the `lib/x.json` line while the fixtures are excluded, and nothing
   else in the walk reports a `.json` or `.awk` file at this depth.
2. `justfile and TOML are capped at any depth`. Fixture: 401-line
   `config.toml`, `justfile` at root, `sub/justfile`, all `git add`ed.
   Assertion: status 1 and exact three-line output in `ls-files` order. The
   state that fails it: any of the three arm pieces (`*.toml`, root `justfile`,
   `*/justfile`) is missing, which drops that file's line; the markdown
   fallback is out of scope for all three, so no other arm can supply the line.

## Mutation proof

Each mutation is one exact `Edit` replacement of a string occurring once in
`scripts/check-line-limits.sh`. Each landed, shown by `command grep`. Each
was run as the single full `tests/check-line-limits.bats` run, then restored
by the swapped replacement, then the restore proven.

### M-a: fixtures arm caps (kills test 1)

- Replacement: `tests/fixtures/*) ;;` to `tests/fixtures/*) check_cap "$file" 400 ;;`
- Landed: line 73 reads `tests/fixtures/*) check_cap "$file" 400 ;;`.
- Red: `not ok 9 fixtures are out of the awk, TOML and JSON cap`, line 181,
  `[ "$output" = "oversized-file: lib/x.json: 401 lines > 400" ]' failed`.
  Suite: 20 passed, 1 failed.
- Restore: swapped replacement. `command grep -c 'tests/fixtures/\*) check_cap'`
  returned 0; the suite was 21 passed, 0 failed.

### M-b1: root `justfile` dropped (kills test 2)

- Replacement: `| justfile | */justfile |` to `| */justfile |`
- Landed: line 71 reads `*.awk | *.toml | */justfile | *.json)`.
- Red: `not ok 10 justfile and TOML are capped at any depth`, line 197,
  output assertion failed. Suite: 20 passed, 1 failed.
- Restore: swapped replacement, `command grep -c '| justfile | \*/justfile |'`
  returned 1; the suite was 21 passed, 0 failed.

### M-b2: `*/justfile` dropped (kills test 2)

- Replacement: `| */justfile | *.json)` to `| *.json)`
- Landed: line 71 reads `*.awk | *.toml | justfile | *.json)`.
- Red: `not ok 10 justfile and TOML are capped at any depth`, line 197,
  output assertion failed. Suite: 20 passed, 1 failed.
- Restore: swapped replacement, `command grep -c '\*/justfile | \*\.json)'`
  returned 1; the suite was 21 passed, 0 failed.

### M-b3: `*.toml` dropped (kills test 2)

- Replacement: `*.awk | *.toml | justfile` to `*.awk | justfile`
- Landed: line 71 reads `*.awk | justfile | */justfile | *.json)`.
- Red: `not ok 10 justfile and TOML are capped at any depth`, line 197,
  output assertion failed. Suite: 20 passed, 1 failed.
- Restore: swapped replacement, `command grep -c '\*\.awk | justfile |'`
  returned 0 after restore; the arm line is again
  `*.awk | *.toml | justfile | */justfile | *.json)` (line 71), and the suite
  was 21 passed, 0 failed.

Restore proof, for the whole script, after the last restore:
`command grep -c MUT scripts/check-line-limits.sh tests/check-line-limits.bats`
returned 0 for both. The fixtures arm reads `tests/fixtures/*) ;;` (line 73).

Caveat on M-b1 through M-b3: the assertion that reds is the single exact
output comparison of test 2, so the failure line is the same for all three
(line 197). Each mutation removes a different one of the three lines from the
output, which the `oversized-file:` output above shows only as the missing
line. The three are not separately diagnosable from the line number alone.

## Fixtures tried and rejected

None. The first draft used the outline's shape unchanged; the only edit before
the baseline run was folding the outline's two-part fixtures case into one
case, since the status-0 form cannot hold beside the reported `lib/x.json`.

## Gate

- `bats` for this file, unchanged script: 21 passed, 0 failed.
- `just precommit`, run with `dangerouslyDisableSandbox: true`, foreground:
  exit 0. Recap line: `precommit passed: plugin.json, hooks.json, shellcheck,
  bash -n, rumdl, line limits, links, python compile, tests`. The bats run
  inside it: 403 passed, 0 failed.
- `tmp/.test-sentinel`: absent. No file of that name exists in the tree and no
  script or test in this repo writes it, so there is no sentinel hash to
  record.
- `tests/check-line-limits.bats` is 400 lines after this change, at the 400
  cap; the line-limit check passed inside precommit.

## Warnings

No warnings in the precommit recap. Only the recap line above was printed.
