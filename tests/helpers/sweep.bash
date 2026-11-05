#!/usr/bin/env bash
# Loaded by tests/docs.bats and tests/sweep-code.bats, the two halves of the
# FR-11 sweep: no live file fires a detector. One predicate, `is_code_path`,
# decides which half a tracked path belongs to, so no path falls between the
# suites or is swept twice. The list below is the code dirs of the justfile's
# `code_dirs`, which gate-code hashes; a case in tests/sweep-code.bats pins the
# two to each other.
#
# The loading suite sets ROOT and MATCHERS (the lib/matchers.sh to run) first.

SWEEP_CODE_DIRS=(lib hooks scripts bin tests plugin-dev)

# Dated pilot evidence that quotes live diagnostics whole, frozen. Each must
# still fire, or a sweep passing over them could be passing because the
# matchers never ran.
EXEMPT=(
  plans/2026-09-02-sandbox-detector-replay.py
  plans/2026-09-02-sandbox-detector-hits.jsonl
  plans/2026-09-03-sandbox-matcher-corpus-eval.md
)

# sweep_side <code|docs> [root]: pipe every tracked regular file of that side
# of root (default $ROOT) through $MATCHERS. Sets SWEPT to how many it read and
# FIRING to a report line per file that fired or failed the matchers. Called
# bare, not through `run`, since the results are variables.
sweep_side() {
  local side="$1" root="${2:-$ROOT}" index meta path mode verdicts status
  SWEPT=0
  FIRING=""
  index="$BATS_TEST_TMPDIR/sweep-index"
  git -C "$root" ls-files -z -s >"$index"
  [ -s "$index" ]
  # `-s` prefixes each path with `<mode> <object> <stage>` and a tab;
  # 120000 is a symlink and 160000 a gitlink, neither of them a file to read.
  while IFS= read -r -d '' meta; do
    path=${meta#*$'\t'}
    mode=${meta%% *}
    case "$mode" in 120000|160000) continue ;; esac
    if is_code_path "$path"; then
      [ "$side" = code ] || continue
    else
      [ "$side" = docs ] || continue
    fi
    # Fixtures are recorded tool results and fire by design. The root TASK.md
    # and TODO.md are covered by `just task-files`, so an edit to either does
    # not discard a cached pass.
    case "$path" in tests/fixtures/* | TASK.md | TODO.md) continue ;; esac
    is_exempt "$path" && continue
    status=0
    verdicts=$(bash "$MATCHERS" <"$root/$path") || status=$?
    SWEPT=$((SWEPT + 1))
    [ -z "$verdicts" ] ||
      FIRING="$FIRING"$'\n'"  $path: ${verdicts//$'\n'/, }"
    # `detect` exits 1 when quiet; above that bash itself failed on this
    # file (126, 127), which must not read as quiet.
    [ "$status" -le 1 ] ||
      FIRING="$FIRING"$'\n'"  $path: matchers exited $status"
  done <"$index"
}

# True (0) when the root-relative path $1 is under a code dir.
is_code_path() {
  local d
  for d in "${SWEEP_CODE_DIRS[@]}"; do
    case "$1" in "$d"/*) return 0 ;; esac
  done
  return 1
}

is_exempt() {
  local e
  for e in "${EXEMPT[@]}"; do [ "$1" = "$e" ] && return 0; done
  return 1
}
