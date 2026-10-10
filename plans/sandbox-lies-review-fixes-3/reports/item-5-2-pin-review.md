# Item 5.2 pin review

Scope: the two cases the last commit added to `tests/check-line-limits.bats`
(fixtures exclusion; justfile/TOML at any depth), the pin report, and
survivor 3 of `item-4-1-review.md`. Assessment: pin sound; one weakness fixed.

## Mutation proof (my own mutations, distinct from the pin report's)

Each by exact `Edit` replacement in `scripts/check-line-limits.sh`, landed
proven with `command grep`, one foreground `scripts/run-bats.sh` run, restored
by swapped replacement.

1. `tests/fixtures/*) ;;` to `tests/fixtures/x*) ;;` (line 73). Red:
   `not ok 9 fixtures are out of the awk, TOML and JSON cap`, line 181, the
   output assertion (`y.awk` now reported). 20 passed, 1 failed.
2. Inner fallback `check_cap "$file" 400` to `401` (line 74). Red: tests 8
   (existing awk case), 9 and 10 on `[ "$status" -eq 1 ]` (lines 163, 180,
   196): assertions, not errors. 18 passed, 3 failed.
3. `*/justfile | *.json)` to `*/justfile | *.jsn)` (line 71). Red: test 9,
   `[ "$status" -eq 1 ]` line 180 (`lib/x.json` no longer reported). 20 passed,
   1 failed.
4. After the test fix below: `tests/fixtures/*) ;;` to `tests/*) ;;`. Red:
   test 9, output assertion line 180. 20 passed, 1 failed.

Restore proven after each: `command grep` found no mutation text,
`git diff --stat` shows only the bats file changed (script identical to
HEAD), final run 21 passed, 0 failed. `command grep '# MUT'` over scripts,
tests, lib: no hits.

## Wrong-reason hunt

- File lists: both cases use explicit `git add` of exactly the fixture paths;
  the walk is `git ls-files -z` in the fixture root, so nothing else is
  listed. Output order is `ls-files` byte order (config.toml, justfile,
  sub/justfile): deterministic.
- 400/401 boundary: the exact output embeds `> 400`, so a cap of 399 or 401
  changes the line or drops it (mutation 2 confirms 401). The 400-line-wrongly-
  reported case is covered by the exact-output comparison: a lowered cap
  changes the text. The 400-line non-report for these arms is not pinned
  separately (markdown boundary is, in the clean-tree case); a `>=` mutation
  in the shared `check_cap` is killed by that existing case.
- Newline/blank-named paths: not relevant to these cases; the walk is
  NUL-delimited and covered elsewhere.
- Test 9 weakness (FIXED): an over-broad exclusion (`tests/*`) survived,
  because nothing under `tests/` outside `fixtures/` was capped. Added a
  401-line `tests/o.json` expected in the output as the second line; comment
  condensed so the file stays at 400 lines. Mutation 4 proves the new
  assertion is red on the over-broad exclusion.
- Test 10: each arm piece is the only source of its line (markdown fallback
  rejects all three), so a dropped piece drops its line; pin report's M-b1..b3
  cover that. No other reason to pass or fail found.

## Fixes applied

- `tests/check-line-limits.bats` case "fixtures are out of the awk, TOML and
  JSON cap": added `tests/o.json` (401 lines, tracked) and its expected
  output line; comment shortened. File remains 400 lines. Final run:
  21 passed, 0 failed.

Nothing committed.
