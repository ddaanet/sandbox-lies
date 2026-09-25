#!/usr/bin/env bats
# lib/probes.sh: probe_git_lock and probe_config_lock, the A-3 contract.
#
# Each probe reads the Bash tool result text on stdin, takes the flag as $1
# and the payload cwd as $2, and prints an outcome token on line 1 followed
# by key=value lines. Synthetic fixture trees live under $BATS_TEST_TMPDIR.

ROOT="${BATS_TEST_DIRNAME}/.."

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs
load helpers/probes

setup() {
  source "$ROOT/lib/probes.sh"
  _probe_holder_pid=
}

# Kills the lock-holding background job the two "held" tests start. Guarded:
# every other test leaves _probe_holder_pid at setup's empty default, so
# there is nothing to kill for them.
teardown() {
  if [ -n "${_probe_holder_pid:-}" ]; then
    # A killed job's wait returns 143, and a failing teardown fails the
    # test; kill finds no process when the holder died on its own.
    kill "$_probe_holder_pid" 2>/dev/null || :
    wait "$_probe_holder_pid" 2>/dev/null || :
  fi
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

# hold_lock <lock> — backgrounds a holder opening <lock> read-only on fd 4
# (any fd but 3), its pid in _probe_holder_pid for teardown to kill, and
# returns only once the open has happened: the ready file is written after
# it, so the probe never runs ahead of the holder. A holder that cannot open
# the lock never writes the file, and the bounded wait fails the test.
#
# fd 3 is closed on the holder: bats duplicates its TAP stream onto fd 3,
# and a background job holding it open keeps the run from returning until
# the 30s sleep exits (seen on this box). The subshell execs sleep, so its
# pid is $! throughout. A finished decoy job runs last, so $! in the test —
# and in the probe's subshell, which inherits it — no longer names the
# holder: a probe printing its own $! cannot pass for one naming the holder.
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

# Exactly one pid= line: a holder query wider than the lock (a whole mount,
# the directory) would list the holder among other pids. The flag only
# selects mask or gone for an absent lock, so both flags read held.
@test "held lock names the holder" {
  local repo="$BATS_TEST_TMPDIR/r" cwd="$BATS_TEST_TMPDIR/elsewhere" lock
  mkdir -p "$repo/.git" "$cwd"
  lock="$repo/.git/index.lock"
  printf '1234567' >"$lock"
  hold_lock "$lock"

  run_probe probe_git_lock false "$cwd" "$(git_lock_error "$lock")"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = held ]
  printf '%s\n' "$output" | grep -qxF "pid=$_probe_holder_pid"
  [ "$(printf '%s\n' "$output" | grep -c '^pid=')" -eq 1 ]

  run_probe probe_git_lock true "$cwd" "$(git_lock_error "$lock")"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = held ]
  printf '%s\n' "$output" | grep -qxF "pid=$_probe_holder_pid"
  [ "$(printf '%s\n' "$output" | grep -c '^pid=')" -eq 1 ]
}

# Same holder, under the quote-and-space path: the only case in this list
# pinning the holder tool's own quoting (slice 3's reviews). An unquoted
# lsof/fuser invocation gets two nonexistent paths, finds no holder and
# reports the misses on stderr (fuser does so, checked on this box).
@test "held lock under a quoted, spaced path" {
  local repo="$BATS_TEST_TMPDIR/it's here/r" cwd="$BATS_TEST_TMPDIR/elsewhere" lock
  mkdir -p "$repo/.git" "$cwd"
  lock="$repo/.git/index.lock"
  printf '1234567' >"$lock"
  hold_lock "$lock"

  run_probe probe_git_lock false "$cwd" "$(git_lock_error "$lock")"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = held ]
  printf '%s\n' "$output" | grep -qxF "pid=$_probe_holder_pid"
  [ "$(printf '%s\n' "$output" | grep -c '^pid=')" -eq 1 ]
}

# A symlink to /dev/null keeps the ordinary lock shape under extraction (the
# path still ends in index.lock), so this pins the character-device rule
# rather than the path parse. /dev/null typically has many open holders
# (every redirected stdio on the box), so a probe with no character-device
# rule reads this as held, not mask. The control first: a symlink to a 7-byte
# regular file stats as a regular file and reads orphan, so a rule keyed on
# the symlink itself rather than on what it resolves to fails there.
@test "character device is mask" {
  local repo="$BATS_TEST_TMPDIR/r" cwd="$BATS_TEST_TMPDIR/elsewhere" lock
  mkdir -p "$repo/.git" "$cwd"
  lock="$repo/.git/index.lock"
  printf '1234567' >"$repo/.git/target"
  ln -s "$repo/.git/target" "$lock"

  run_probe probe_git_lock false "$cwd" "$(git_lock_error "$lock")"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = orphan ]
  printf '%s\n' "$output" | grep -qxF "bytes=7"

  rm "$lock"
  ln -s /dev/null "$lock"

  run_probe probe_git_lock false "$cwd" "$(git_lock_error "$lock")"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = mask ]
  printf '%s\n' "$output" | grep -qxF "path=$lock"

  run_probe probe_git_lock true "$cwd" "$(git_lock_error "$lock")"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = mask ]
  printf '%s\n' "$output" | grep -qxF "path=$lock"
}

# PATH set to a directory holding only the tools probe_git_lock itself calls,
# built from this host's own binaries: neither lsof nor fuser is there, so
# the case never depends on which of the two (if either) the host provides.
@test "no holder tool is unknown" {
  local repo="$BATS_TEST_TMPDIR/r" cwd="$BATS_TEST_TMPDIR/elsewhere" lock
  local toolsdir="$BATS_TEST_TMPDIR/tools-only"
  mkdir -p "$repo/.git" "$cwd"
  lock="$repo/.git/index.lock"
  printf '1234567' >"$lock"
  tools_only_path "$toolsdir"

  PATH="$toolsdir" run_probe probe_git_lock false "$cwd" "$(git_lock_error "$lock")"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = unknown ]
  printf '%s\n' "$output" | grep -qxF "bytes=7"
}

# The error text names the lock relative to git's cwd (".git/index.lock").
# The probe runs from an unrelated directory holding a 3-byte decoy lock at
# that same relative path (slice 2's code review): a probe resolving against
# its process cwd, even only as a first try before $2, reads the decoy, so
# bytes=7 and the absolute path= can only come from $2. $2 reaches the repo
# through a symlink, and path= keeps it as given rather than canonicalised,
# as every other case prints the path the error text gave.
@test "relative path resolves against cwd" {
  local repo="$BATS_TEST_TMPDIR/r" unrelated="$BATS_TEST_TMPDIR/elsewhere"
  local link="$BATS_TEST_TMPDIR/link"
  mkdir -p "$repo/.git" "$unrelated/.git"
  ln -s "$repo" "$link"
  printf '1234567' >"$repo/.git/index.lock"
  printf 'abc' >"$unrelated/.git/index.lock"
  cd "$unrelated"

  run_probe probe_git_lock false "$link" "$(git_lock_error .git/index.lock)"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = orphan ]
  printf '%s\n' "$output" | grep -qxF "bytes=7"
  printf '%s\n' "$output" | grep -qxF "path=$link/.git/index.lock"
}
