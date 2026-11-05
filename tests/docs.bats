#!/usr/bin/env bats
# FR-11: no live file in this repository fires a detector when read back.
#
# This is the docs half of the sweep: every tracked regular file outside the
# code dirs (tests/helpers/sweep.bash decides which those are) is piped through
# lib/matchers.sh. tests/sweep-code.bats sweeps the code half. The exemptions
# are dated pilot evidence that quotes live diagnostics whole and is frozen. The
# root TASK.md and TODO.md are skipped: `just task-files` runs the matchers over
# them, so an edit to either does not discard the cached gate-docs pass.

ROOT="${BATS_TEST_DIRNAME}/.."
MATCHERS="$ROOT/lib/matchers.sh"

load helpers/bsd-stubs
load helpers/git-env
load helpers/sweep

@test "no tracked file outside the fixtures fires a detector" {
  local e
  for e in "${EXEMPT[@]}"; do
    [ -n "$(bash "$MATCHERS" <"$ROOT/$e")" ] || {
      echo "exempt file no longer fires: $e" >&2
      return 1
    }
  done
  sweep_side docs
  [ "$SWEPT" -gt 0 ]
  [ -z "$FIRING" ] || {
    echo "files firing a detector or failing the matchers:$FIRING" >&2
    return 1
  }
}
