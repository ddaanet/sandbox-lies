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

# Claude Code runs two patterns in a SKILL.md as shell commands when the skill
# loads, so a SKILL.md that merely shows one as an example fails to load. The
# patterns are built from fragments: this file is swept by the matchers too.
# Prints "path:line:text" for each match under the git repo given as $1.
skill_expansions() {
  local bang='!' tick='`' inline fenced f
  inline="(^|[[:space:]])${bang}${tick}"
  fenced="${tick}${tick}${tick}${bang}"
  SKILL_COUNT=0
  while IFS= read -r -d '' f; do
    [ "${f##*/}" = SKILL.md ] || continue
    SKILL_COUNT=$((SKILL_COUNT + 1))
    grep -nHE -e "$inline" -e "$fenced" -- "$1/$f" || true
  done < <(git -C "$1" ls-files -z)
}

@test "no tracked SKILL.md matches a Claude Code expansion pattern" {
  skill_expansions "$ROOT" >"$BATS_TEST_TMPDIR/hits"
  # the function ran in the current shell via redirection, so SKILL_COUNT is set
  [ "$SKILL_COUNT" -gt 0 ]
  [ ! -s "$BATS_TEST_TMPDIR/hits" ] || {
    echo "SKILL.md lines Claude Code would run as commands:" >&2
    cat "$BATS_TEST_TMPDIR/hits" >&2
    return 1
  }
}
