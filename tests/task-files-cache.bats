#!/usr/bin/env bats
# Editing TASK.md or TODO.md leaves the main gate's cached pass standing, and
# `precommit` still refuses a firing one through `task-files`. The real
# `precommit` runs in a scratch clone of this repository, with the working
# tree's gate code copied over it so uncommitted work is what is tested. The
# script and recipe cases are in tests/task-files.bats.

ROOT="${BATS_TEST_DIRNAME}/.."

load helpers/bsd-stubs
load helpers/git-env

# A line that fires the phantom-chardev detector, built from fragments so this
# file stays quiet under the tests/docs.bats sweep.
firing_line() {
  printf '%s%s  1 root root 1, 3 Jan  1 00:00 %s\n' c rw-rw-rw- .bashrc
}

# A clone of this repository, with the working tree's gate code and these
# suites copied over it so uncommitted work is what runs. shellcheck and rumdl
# are stubs and the clone's bats runner a spy appending a line to $SPY_LOG: the
# cases are about whether the gate runs, and the slow checks are not what they
# assert.
make_gate_clone() {
  CLONE="$BATS_TEST_TMPDIR/clone"
  STUBS="$BATS_TEST_TMPDIR/stubs"
  SPY_LOG="$BATS_TEST_TMPDIR/bats-runs"
  git clone -q "$ROOT" "$CLONE"
  cp "$ROOT/justfile" "$CLONE/"
  cp -R "$ROOT/scripts/." "$CLONE/scripts/"
  cp -R "$ROOT/lib/." "$CLONE/lib/"
  cp "$ROOT/tests/docs.bats" "$ROOT"/tests/task-files*.bats "$CLONE/tests/"
  mkdir -p "$STUBS"
  printf '#!/bin/sh\nexit 0\n' >"$STUBS/shellcheck"
  cp "$STUBS/shellcheck" "$STUBS/rumdl"
  chmod 755 "$STUBS/shellcheck" "$STUBS/rumdl"
  printf '#!/bin/sh\necho run >>"%s"\nexit 0\n' "$SPY_LOG" \
    >"$CLONE/plugin-dev/run-bats.sh"
  : >"$SPY_LOG"
}

# The real `just precommit` in the clone, on a PATH with the stubs first and
# a sentinel directory of its own.
run_gate() {
  cd "$CLONE" && PATH="$STUBS:$PATH" run env -u PLUGIN_DEV_GATE_FORCE \
    -u PLUGIN_DEV_GATE_DIR just precommit
}

spy_runs() {
  wc -l <"$SPY_LOG" | tr -d ' '
}

@test "editing TODO.md or TASK.md leaves the main gate cached; another root input does not" {
  make_gate_clone
  run_gate
  [ "$status" -eq 0 ]
  [[ "$output" == *"precommit passed:"* ]]
  [ "$(spy_runs)" -eq 1 ]

  local f
  for f in TODO.md TASK.md; do
    printf 'one more line\n' >>"$CLONE/$f"
    run_gate
    [ "$status" -eq 0 ]
    [[ "$output" == *"precommit: cached"* ]]
    [[ "$output" == *"task-files passed"* ]]
    [ "$(spy_runs)" -eq 1 ]
  done

  # Control: an edit to another root markdown input is not cached, or the
  # assertions above would hold of a gate that never reruns.
  printf 'one more line\n' >>"$CLONE/README.md"
  run_gate
  [ "$status" -eq 0 ]
  [[ "$output" == *"precommit passed:"* ]]
  [[ "$output" != *"precommit: cached"* ]]
  [ "$(spy_runs)" -eq 2 ]
}

@test "precommit refuses a firing TODO.md through task-files before the main gate runs" {
  make_gate_clone
  firing_line >"$CLONE/TODO.md"
  run_gate
  [ "$status" -ne 0 ]
  [[ "$output" == *TODO.md* ]]
  [[ "$output" == *phantom-chardev* ]]
  [[ "$output" != *"precommit passed"* ]]
  [ "$(spy_runs)" -eq 0 ]
}
