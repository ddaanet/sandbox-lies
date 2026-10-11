# Review of 34c5573 (pin 1.1/3)

Verdict: no defects. No library or test change; this report is the only commit.

## Mutation re-run (mine)

- Mutant: line 85 of `lib/probes-readonly.sh`, `_probe_path_line "$path"`
  (occurs once) replaced by the `[ "$outcome" = readonly ] && [ newline in
  path ] || _probe_path_line "$path"` form from the phase-1 review finding 3.
  Landed: `command grep -n 'path#\*'` found line 85.
- Red: `bats -f 'under a read-only directory'` gives `not ok 1 ...`, failing at
  `[ "$output" = "$expected" ]` (members.bats line 194), the output assertion.
- Other cases: `scripts/run-bats.sh tests/probes-readonly-members.bats` gave
  12 passed, 1 failed (only the new case). The other readonly probe suites
  (facts, pins, operands, resolve, globs, probes-readonly, verdicts-readonly,
  verdicts-readonly-path) passed, 30 + 89 cases, 0 failed.
- Restore: swapped replacement via python (assert the mutant occurs once).
  `command grep -c 'path#\*'` prints 0; `git diff --stat -- lib` is empty;
  members suite `bats: 13 passed, 0 failed`.

## Case checks

- Exercises readonly: dir is chmod 555 and owned by the suite uid, so `-w` is
  false for a non-root uid; the case skips when `id -u` is 0 (root-dependence
  handled, not a silent pass). Skip is not triggered here (uid 1000).
- Not host-state-dependent: tree is under `$BATS_TEST_TMPDIR`; no
  CLAUDE_CONFIG_DIR/HOME use, so those rules do not apply.
- Asserts status 0, empty stderr, and the whole output: `readonly` then the
  single `path=$'...\n...'` line. chmod 755 restores right after the probe, so
  cleanup survives assertion failure.
- Loads `helpers/bsd-stubs` (file-level); the file is 306 lines, under 400.
- Caveat (as in the implementer report): the case does not by itself prove
  the facts block stays withheld under readonly; the exact-output comparison
  does, since any extra facts line would fail it.
