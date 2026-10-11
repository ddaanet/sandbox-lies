# Review of 595bf60 (fix M1)

Verdict: no defect.

- The diff of the test file is one comment and one line. `exec 2>&1` inside
  the substitution sends the sourced code's stderr into `$out`, which the
  equality `rc=1 raw= shown=` then compares. The old trailing `2>&1` applied
  to the assignment and captured nothing. Only that loop line changed; the
  `rc=0` assertion above it and the failure-message `>&2` are untouched, so
  no other assertion was weakened.

## Mutation proof

1. Replaced the once-occurring `*) _verdict_path_raw=''; return 1 ;;` in
   `lib/verdicts.sh` with the same text plus `echo MUTANT-STDERR >&2;` before
   `return 1`.
2. Landed: `command grep -n MUTANT lib/verdicts.sh` found line 180.
3. `scripts/run-bats.sh tests/verdicts-readonly-path.bats`, one foreground
   process: 12 passed, 1 failed. Case 13 ("... silently") failed at line 230,
   the `[ "$out" = 'rc=1 raw= shown=' ]` assertion, printing
   `wire $'/x/ok\x41' gave: MUTANT-STDERR`. No other case failed.
4. Restored by the swapped replacement.
5. `command grep -c MUTANT lib/verdicts.sh` gave 0; the file run was 13
   passed, 0 failed; `git diff --stat lib/` empty.

Only the report is committed.
