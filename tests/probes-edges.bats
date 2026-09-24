#!/usr/bin/env bats
# lib/probes.sh: edge cases Item 2.4 slice 3's code review already fixed in
# probe_git_lock, opened as a separate file because tests/probes.bats stood
# at 256 lines. Each case here is pinned by mutation, not by a red against
# unimplemented behaviour — the fix landed with the review, ahead of a test.

ROOT="${BATS_TEST_DIRNAME}/.."

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs
load helpers/probes

setup() {
  source "$ROOT/lib/probes.sh"
}

# run_probe_bounded <probe> <flag> <cwd> <text> — as run_probe, but the probe
# runs backgrounded with its streams captured to files and a bounded poll,
# setting $status, $output and $stderr itself. A probe that hangs (as this
# file's non-regular-lock case would before the [ -f ] guard) then fails the
# test on $status instead of hanging the suite. No GNU timeout: this repo's
# portability target excludes it.
#
# set -m gives the backgrounded job its own process group (pid == pgid), so
# a timeout can kill -- "-$pid" the whole group at once. Killing $pid alone
# leaves a blocked grandchild (the FIFO open a dropped guard would leave
# hanging, several forks down through the command substitution that reads
# it) running as an orphan — and bats' own plumbing holds pipe fds that
# orphan inherits, which then keeps the whole run from returning, not just
# this function.
run_probe_bounded() {
  local out="$BATS_TEST_TMPDIR/bounded-out" err="$BATS_TEST_TMPDIR/bounded-err"
  local rc="$BATS_TEST_TMPDIR/bounded-status" pid tries=0
  set -m
  ("$1" "$2" "$3" <<<"$4" >"$out" 2>"$err"; echo "$?" >"$rc") &
  pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$tries" -ge 30 ]; then
      kill -- "-$pid" 2>/dev/null
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
  status=$(cat "$rc")
  output=$(cat "$out")
  stderr=$(cat "$err")
}

# A stat stub on PATH removes its path operand, then runs the real stat: the
# window git's own lock cleanup can land in, between the presence test and
# the mtime read. Recreates the lock between the two flag runs so the second
# run also has something for the stub to remove, rather than hitting the
# probe's earlier, already-absent-at-entry path.
@test "vanished lock is gone" {
  local repo="$BATS_TEST_TMPDIR/r" cwd="$BATS_TEST_TMPDIR/elsewhere" lock
  local stubdir="$BATS_TEST_TMPDIR/stat-stub" realstat
  mkdir -p "$repo/.git" "$cwd" "$stubdir"
  lock="$repo/.git/index.lock"
  realstat=$(command -v stat)
  cat >"$stubdir/stat" <<STUB
#!/bin/sh
for a; do path=\$a; done
rm -f "\$path"
exec "$realstat" "\$@"
STUB
  chmod 755 "$stubdir/stat"

  printf '1234567' >"$lock"
  PATH="$stubdir:$PATH" run_probe probe_git_lock false "$cwd" "$(git_lock_error "$lock")"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "$output" = "$(printf 'gone\npath=%s' "$lock")" ]

  printf '1234567' >"$lock"
  PATH="$stubdir:$PATH" run_probe probe_git_lock true "$cwd" "$(git_lock_error "$lock")"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "$output" = "$(printf 'gone\npath=%s' "$lock")" ]
}

# A FIFO at the lock path: reading it with no writer blocks in open(2), so
# this is the case a hung probe would fail on rather than time the suite out.
# Then a directory: reading one opens but errors, so a guard that excludes
# FIFOs alone still fails there, on stderr and a bytes= line.
@test "non-regular lock has no size" {
  local repo="$BATS_TEST_TMPDIR/r" cwd="$BATS_TEST_TMPDIR/elsewhere" lock
  local status output stderr
  mkdir -p "$repo/.git" "$cwd"
  lock="$repo/.git/index.lock"
  mkfifo "$lock"

  run_probe_bounded probe_git_lock false "$cwd" "$(git_lock_error "$lock")"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = orphan ]
  [ "$(printf '%s\n' "$output" | grep -c '^bytes=')" -eq 0 ]

  rm "$lock"
  mkdir "$lock"

  run_probe_bounded probe_git_lock false "$cwd" "$(git_lock_error "$lock")"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = orphan ]
  [ "$(printf '%s\n' "$output" | grep -c '^bytes=')" -eq 0 ]
}

# touch -t 209901010000 backdates nothing; it sets a future mtime, the clock
# skew case. Age is clamped to 0, not left negative.
@test "future mtime is age 0" {
  local repo="$BATS_TEST_TMPDIR/r" cwd="$BATS_TEST_TMPDIR/elsewhere" lock
  mkdir -p "$repo/.git" "$cwd"
  lock="$repo/.git/index.lock"
  printf '1234567' >"$lock"
  touch -t 209901010000 "$lock"

  run_probe probe_git_lock false "$cwd" "$(git_lock_error "$lock")"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = orphan ]
  printf '%s\n' "$output" | grep -qxF "age=0"
}
