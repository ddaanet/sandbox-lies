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
