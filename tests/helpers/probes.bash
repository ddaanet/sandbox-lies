# Shared helpers for tests/probes.bats, tests/probes-edges.bats,
# tests/probes-tools.bats and tests/probes-config.bats: the error builders
# and the `run` wrapper their probe cases use.

# Self-quiet (FR-11): git's lock error is built from two fragments at run
# time, as lib/matchers.sh match_git_lock builds its follow-on, so no test
# file holds the diagnostic whole. The follow-on sentence is left out
# entirely — the probe does not read it.
git_lock_error() {
  local path="$1" text
  text="fatal: Unable to create '"
  text="${text}${path}': File exists."
  printf '%s\n' "$text"
}

# config_lock_error <path> — git's config-lock error line, built from two
# fragments at run time (self-quiet, FR-11), the same split
# tests/matchers.bats "detect sees past a NUL" uses for match_config_lock's
# own pattern, so no source line here reads "error: could not lock config
# file ...: File exists" whole. <path> names the config file, not the lock:
# the probe appends ".lock" itself.
config_lock_error() {
  local path="$1" text
  text="error: could not lock config file $path: File"
  text="${text} exists"
  printf '%s\n' "$text"
}

# run_probe <probe> <flag> <cwd> <text> — the probe under bats' run with
# <text> on stdin: stdout in $output, stderr in $stderr, exit in $status.
# stderr is kept apart so it cannot shift the outcome off line 1. Line 1 is
# read as ${output%%$'\n'*}, never ${lines[0]}: bats drops empty lines from
# lines, so a stray blank first line would pass for the token.
run_probe() {
  run --separate-stderr "$1" "$2" "$3" <<<"$4"
}

# tools_only_path <dir> — symlinks into <dir> every external tool
# probe_git_lock calls other than the holder tools (lsof, fuser), plus
# mktemp for bats' own `run --separate-stderr` (test_functions.bash), taken
# from this host's own `command -v` so the case runs on any box. A PATH set
# to exactly <dir> can then never see lsof or fuser unless a test writes one
# there itself. The tool list lives here once, so a new probe call site
# updates one place.
tools_only_path() {
  local dir="$1" tool
  mkdir -p "$dir"
  for tool in cat sed head stat wc tr date mktemp; do
    ln -s "$(command -v "$tool")" "$dir/$tool"
  done
}

# hold_lock <lock> — backgrounds a holder opening <lock> read-only on fd 4
# (any fd but 3), its pid in _probe_holder_pid for the caller's teardown to
# kill, and returns only once the open has happened: the ready file is
# written after it, so the probe never runs ahead of the holder. A holder
# that cannot open the lock never writes the file, and the bounded wait
# fails the test.
#
# fd 3 is closed on the holder: bats duplicates its TAP stream onto fd 3, and
# a background job holding it open keeps the run from returning until the
# 30s sleep exits (seen on this box). The subshell execs sleep, so its pid is
# $! throughout. A finished decoy job runs last, so $! in the test — and in
# the probe's subshell, which inherits it — no longer names the holder: a
# probe printing its own $! cannot pass for one naming the holder.
#
# Shared by tests/probes.bats and tests/probes-edges.bats: each file's own
# setup() resets _probe_holder_pid and its own teardown() kills it.
hold_lock() {
  local ready="$BATS_TEST_TMPDIR/holder-ready" tries=0
  (
    exec 4<"$1"
    : >"$ready"
    exec sleep 30
  ) 3>&- &
  _probe_holder_pid=$!
  until [ -e "$ready" ]; do
    [ "$tries" -lt 50 ] || return 1
    tries=$((tries + 1))
    sleep 0.1
  done
  : &
  wait "$!"
}

# run_probe_bounded <probe> <flag> <cwd> <text> — as run_probe, but the probe
# runs backgrounded with its streams captured to files and a bounded poll,
# setting $status, $output and $stderr itself. A probe that hangs (a walk-up
# regression, or tests/probes-edges.bats' non-regular-lock case before its
# [ -f ] guard) then fails the test on $status instead of hanging the suite.
# No GNU timeout: this repo's portability target excludes it.
#
# set -m gives the backgrounded job its own process group (pid == pgid), so
# a timeout can kill -- "-$pid" the whole group at once. Killing $pid alone
# leaves a blocked grandchild (a FIFO open several forks down through the
# command substitution that reads it) running as an orphan — and bats' own
# plumbing holds pipe fds that orphan inherits, which then keeps the whole
# run from returning, not just this function. The kill tolerates a group
# that exited since the poll, so errexit cannot end the test before $status
# is set.
#
# Shared by tests/probes-edges.bats and tests/probes-config.bats.
run_probe_bounded() {
  local out="$BATS_TEST_TMPDIR/bounded-out" err="$BATS_TEST_TMPDIR/bounded-err"
  local rc="$BATS_TEST_TMPDIR/bounded-status" pid tries=0
  set -m
  ("$1" "$2" "$3" <<<"$4" >"$out" 2>"$err"; echo "$?" >"$rc") &
  pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$tries" -ge 30 ]; then
      kill -- "-$pid" 2>/dev/null || :
      wait "$pid" 2>/dev/null || :
      set +m
      status=124
      output=$(cat "$out" 2>/dev/null || :)
      stderr="TIMEOUT: probe did not return within the bound"
      return
    fi
    tries=$((tries + 1))
    sleep 0.1
  done
  wait "$pid" 2>/dev/null || :
  set +m
  # shellcheck disable=SC2034 # read by the calling test, not here
  status=$(cat "$rc")
  # shellcheck disable=SC2034 # read by the calling test, not here
  output=$(cat "$out")
  # shellcheck disable=SC2034 # read by the calling test, not here
  stderr=$(cat "$err")
}
