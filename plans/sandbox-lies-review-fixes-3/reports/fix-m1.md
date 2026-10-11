# Fix M1 — silently case captures stderr

Change: in `tests/verdicts-readonly-path.bats`, the loop of the case
"_verdict_path_read decodes ... silently" moved the stderr join inside the
substitution (`out=$(exec 2>&1; . "$VERDICTS"; ...)`), replacing the trailing
`2>&1` that applied to the assignment and captured nothing. The equality
`rc=1 raw= shown=` now also asserts stderr empty. A comment states this.

State that fails it: `_verdict_path_read` writing any line to stderr on the
forged-escape path. Nothing else changes `$out` there.

## Mutation proof

1. Mutation in `lib/verdicts.sh`, exact replacement of the once-occurring
   `*) _verdict_path_raw=''; return 1 ;;` by
   `*) _verdict_path_raw=''; echo MUTANT-STDERR >&2; return 1 ;;`.
2. Landed: `command grep -n MUTANT-STDERR lib/verdicts.sh` found line 180.
3. Red on its own assertion: `not ok 13 _verdict_path_read decodes ... silently`,
   line 230 `[ "$out" = 'rc=1 raw= shown=' ]` failed, output
   `wire $'/x/ok\x41' gave: MUTANT-STDERR` / `rc=1 raw= shown=`;
   12 passed, 1 failed.
4. Restored by the swapped replacement.
5. Restore proved: `command grep -c MUTANT lib/verdicts.sh` gave 0; the file
   run was 13 passed, 0 failed. `git diff --stat lib/` is empty.

Baseline before mutation: 13 passed, 0 failed.

## Last precommit recap

`precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line
limits, links, python compile, tests` (bats: 413 passed, 0 failed; exit 0).
