#!/usr/bin/env bats
# lib/probes.sh: probe_git_lock and probe_config_lock, the A-3 contract.
#
# Each probe reads the Bash tool result text on stdin, takes the flag as $1
# and the payload cwd as $2, and prints an outcome token on line 1 followed
# by key=value lines. Synthetic fixture trees live under $BATS_TEST_TMPDIR.

ROOT="${BATS_TEST_DIRNAME}/.."

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs

setup() {
  source "$ROOT/lib/probes.sh"
}

# Self-quiet (FR-11): git's lock error is built from two fragments at run
# time, as lib/matchers.sh match_git_lock builds its follow-on, so this file
# never holds the diagnostic whole. The follow-on sentence is left out
# entirely — the probe does not read it.
git_lock_error() {
  local path="$1" text
  text="fatal: Unable to create '"
  text="${text}${path}': File exists."
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

# $2 names an unrelated directory, so the path= line can only come from the
# error text. The lock is never created; absence is guarded rather than
# probed, so no tool error reaches stderr.
@test "absent lock, sandboxed, is mask" {
  local repo="$BATS_TEST_TMPDIR/r" cwd="$BATS_TEST_TMPDIR/elsewhere" lock
  mkdir -p "$repo/.git" "$cwd"
  lock="$repo/.git/index.lock"

  run_probe probe_git_lock false "$cwd" "$(git_lock_error "$lock")"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = mask ]
  printf '%s\n' "$output" | grep -qxF "path=$lock"
}

@test "absent lock, unsandboxed, is gone" {
  local repo="$BATS_TEST_TMPDIR/r" cwd="$BATS_TEST_TMPDIR/elsewhere" lock
  mkdir -p "$repo/.git" "$cwd"
  lock="$repo/.git/index.lock"

  run_probe probe_git_lock true "$cwd" "$(git_lock_error "$lock")"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = gone ]
  printf '%s\n' "$output" | grep -qxF "path=$lock"
}

# The directory name holds a raw non-UTF-8 byte (octal 351). Run under
# LC_ALL=C.UTF-8: under that locale GNU sed's "." does not match an invalid
# byte, which is exactly why the extractor forces LC_ALL=C internally. The
# path is asserted byte-exact via an exact-line path= match.
@test "non-UTF-8 byte in the path" {
  local repo cwd lock
  repo="$BATS_TEST_TMPDIR/r$(printf '\351')n/r"
  cwd="$BATS_TEST_TMPDIR/elsewhere"
  mkdir -p "$repo/.git" "$cwd"
  lock="$repo/.git/index.lock"

  # Precondition: under C.UTF-8 a locale-aware sed cannot match the path
  # whole. Without the locale installed, sed falls back to byte-wise C and
  # the path= assertion passes whatever the extractor does, so this fails
  # loudly instead (a skip would read as a pass in run-bats.sh's count).
  [ -z "$(printf '%s\n' "$lock" | LC_ALL=C.UTF-8 sed -n 's/^.*$/x/p')" ]

  LC_ALL=C.UTF-8 run_probe probe_git_lock false "$cwd" "$(git_lock_error "$lock")"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  printf '%s\n' "$output" | grep -qxF "path=$lock"
}

# The lock holds exactly 7 bytes, no trailing newline. No holder process ever
# opens it, and the holder tool (lsof or fuser) is on the ordinary PATH. Its
# mtime is backdated to 2000 (POSIX touch -t), so an age over a day can only
# come from reading the mtime: a constant 0, or an age taken from the ctime
# or the clock, stays under it.
@test "present unheld lock is orphan" {
  local repo="$BATS_TEST_TMPDIR/r" cwd="$BATS_TEST_TMPDIR/elsewhere" lock age
  mkdir -p "$repo/.git" "$cwd"
  lock="$repo/.git/index.lock"
  printf '1234567' >"$lock"
  touch -t 200001010000 "$lock"

  run_probe probe_git_lock false "$cwd" "$(git_lock_error "$lock")"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = orphan ]
  printf '%s\n' "$output" | grep -qxF "bytes=7"
  printf '%s\n' "$output" | grep -qE '^age=[0-9]+$'
  age=$(printf '%s\n' "$output" | sed -n 's/^age=//p')
  [ "$age" -gt 86400 ]
  printf '%s\n' "$output" | grep -qxF "path=$lock"

  run_probe probe_git_lock true "$cwd" "$(git_lock_error "$lock")"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = orphan ]
  printf '%s\n' "$output" | grep -qxF "bytes=7"
  printf '%s\n' "$output" | grep -qE '^age=[0-9]+$'
  age=$(printf '%s\n' "$output" | sed -n 's/^age=//p')
  [ "$age" -gt 86400 ]
  printf '%s\n' "$output" | grep -qxF "path=$lock"
}

# Only the literal true reads as unsandboxed (slice 2's code review): an
# empty flag and a wrong-case TRUE must both still read as sandboxed.
@test "unexpected flag reads as sandboxed" {
  local repo="$BATS_TEST_TMPDIR/r" cwd="$BATS_TEST_TMPDIR/elsewhere" lock
  mkdir -p "$repo/.git" "$cwd"
  lock="$repo/.git/index.lock"

  run_probe probe_git_lock "" "$cwd" "$(git_lock_error "$lock")"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = mask ]
  printf '%s\n' "$output" | grep -qxF "path=$lock"

  run_probe probe_git_lock TRUE "$cwd" "$(git_lock_error "$lock")"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = mask ]
  printf '%s\n' "$output" | grep -qxF "path=$lock"
}

# The repo directory name holds a single quote and a space (slice 1's code
# review): pins the greedy .lock capture and quoting through the size and
# mtime reads. Not the holder check's quoting: a split path has no holder
# either, so it still reads orphan. The lock holds 12 bytes, not 7, so a
# constant bytes=7 cannot pass every lock test.
@test "quote and space in the lock path" {
  local repo="$BATS_TEST_TMPDIR/it's here/r" cwd="$BATS_TEST_TMPDIR/elsewhere" lock
  mkdir -p "$repo/.git" "$cwd"
  lock="$repo/.git/index.lock"
  printf '0123456789ab' >"$lock"

  run_probe probe_git_lock false "$cwd" "$(git_lock_error "$lock")"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = orphan ]
  printf '%s\n' "$output" | grep -qxF "path=$lock"
  printf '%s\n' "$output" | grep -qxF "bytes=12"
  printf '%s\n' "$output" | grep -qE '^age=[0-9]+$'
}
