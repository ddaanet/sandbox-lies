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
# of root (default $ROOT) through $MATCHERS, one process per file, SWEEP_JOBS
# at a time. Sets SWEPT to how many it read and FIRING to a report line per
# file that fired or failed the matchers, in index order. Called bare, not
# through `run`, since the results are variables.
sweep_side() {
  local side="$1" root="${2:-$ROOT}" index meta path mode verdicts status
  local saved_trap out n i
  local paths=()
  SWEPT=0
  FIRING=""
  index="$BATS_TEST_TMPDIR/sweep-index"
  out="$BATS_TEST_TMPDIR/sweep-out"
  git -C "$root" ls-files -z -s >"$index"
  [ -s "$index" ]
  rm -rf "$out"
  mkdir "$out"
  # bats' DEBUG trap fires on every command of the loops below; run them
  # untrapped and put the trap back for the caller's assertions.
  saved_trap=$(trap -p DEBUG)
  trap - DEBUG
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
    paths+=("$path")
  done <"$index"
  n=${#paths[@]}
  # Waves of SWEEP_JOBS: each job leaves its stdout in $out/<i>.out and its
  # status in $out/<i>.st, so the report below does not depend on the order
  # the jobs finish in. Closing fd 3 keeps a job from holding bats' pipe open.
  for ((i = 0; i < n; i++)); do
    sweep_one "$root/${paths[i]}" "$out/$i" 3>&- &
    if (((i + 1) % SWEEP_JOBS == 0)); then wait; fi
  done
  wait
  for ((i = 0; i < n; i++)); do
    path=${paths[i]}
    SWEPT=$((SWEPT + 1))
    verdicts=$(<"$out/$i.out")
    status=$(<"$out/$i.st")
    [ -z "$verdicts" ] ||
      FIRING="$FIRING"$'\n'"  $path: ${verdicts//$'\n'/, }"
    # `detect` exits 1 when quiet; above that bash itself failed on this
    # file (126, 127), which must not read as quiet.
    [ "$status" -le 1 ] ||
      FIRING="$FIRING"$'\n'"  $path: matchers exited $status"
  done
  eval "$saved_trap"
}

# Matcher processes sweep_side runs at once; the box has 4 cores.
SWEEP_JOBS=4

# sweep_one <file> <prefix>: run $MATCHERS over the file, its stdout into
# <prefix>.out and its exit status into <prefix>.st.
sweep_one() {
  local status=0
  bash "$MATCHERS" >"$2.out" <"$1" || status=$?
  printf '%s\n' "$status" >"$2.st"
}

# A line that fires the phantom-chardev detector, built from fragments so the
# file calling it stays quiet under the sweep.
firing_line() {
  printf '%s%s  1 root root 1, 3 Jan  1 00:00 %s\n' c rw-rw-rw- .bashrc
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
