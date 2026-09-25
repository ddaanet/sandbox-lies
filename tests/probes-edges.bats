#!/usr/bin/env bats
# lib/probes.sh: edge cases Item 2.4 slice 3's code review already fixed in
# probe_git_lock, opened as a separate file because tests/probes.bats stood
# at 256 lines. Each case here is pinned by mutation, not by a red against
# unimplemented behaviour — the fix landed with the review, ahead of a test.

ROOT="${BATS_TEST_DIRNAME}/.."

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs
load helpers/probes
load helpers/spy

setup() {
  source "$ROOT/lib/probes.sh"
  _probe_holder_pid=
}

# Kills the lock-holding background job "probe writes nothing" starts.
# Guarded: every other test in this file leaves _probe_holder_pid at setup's
# empty default, so there is nothing to kill for them.
teardown() {
  if [ -n "${_probe_holder_pid:-}" ]; then
    # A killed job's wait returns 143, and a failing teardown fails the
    # test; kill finds no process when the holder died on its own.
    kill "$_probe_holder_pid" 2>/dev/null || :
    wait "$_probe_holder_pid" 2>/dev/null || :
  fi
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

# A fuser stub on a tools-only PATH (no lsof) removes the lock, then prints
# fuser's own missing-file line on stderr and exits 1 — the window between
# the holder check and the stat-based vanish read, where the tool sees the
# lock a moment before this probe does. Recreated between the two flag runs
# so the second has something for the stub to remove too.
@test "lock vanishing during the holder check reads gone" {
  local repo="$BATS_TEST_TMPDIR/r" cwd="$BATS_TEST_TMPDIR/elsewhere" lock realrm
  local toolsdir="$BATS_TEST_TMPDIR/tools-only"
  mkdir -p "$repo/.git" "$cwd"
  lock="$repo/.git/index.lock"
  tools_only_path "$toolsdir"
  # realrm resolved before the PATH restriction takes effect: the stub's own
  # rm call must not depend on the tools-only PATH it runs under.
  realrm=$(command -v rm)
  cat >"$toolsdir/fuser" <<STUB
#!/bin/sh
"$realrm" -f "\$1"
printf 'Specified filename %s does not exist.\n' "\$1" >&2
exit 1
STUB
  chmod 755 "$toolsdir/fuser"

  printf '1234567' >"$lock"
  PATH="$toolsdir" run_probe probe_git_lock false "$cwd" "$(git_lock_error "$lock")"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "$output" = "$(printf 'gone\npath=%s' "$lock")" ]

  printf '1234567' >"$lock"
  PATH="$toolsdir" run_probe probe_git_lock true "$cwd" "$(git_lock_error "$lock")"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "$output" = "$(printf 'gone\npath=%s' "$lock")" ]
}

# A fuser stub prints its own "<path>:" line plus a foreign line on stderr,
# and a pid on stdout, space-padded with no newline as psmisc prints it: the
# foreign line is not the access-code shape, so stderr is passed through
# whole. A second stub answering "<path>:ce" (access-code letters only, as
# psmisc appends them on stderr) pins the tolerance that keeps ordinary fuser
# output quiet.
@test "unexpected holder-tool stderr is passed through" {
  local repo="$BATS_TEST_TMPDIR/r" cwd="$BATS_TEST_TMPDIR/elsewhere" lock
  local toolsdir="$BATS_TEST_TMPDIR/tools-only"
  mkdir -p "$repo/.git" "$cwd"
  lock="$repo/.git/index.lock"
  printf '1234567' >"$lock"
  tools_only_path "$toolsdir"
  cat >"$toolsdir/fuser" <<STUB
#!/bin/sh
printf '%s:\n' "$lock" >&2
printf 'fuser: something odd\n' >&2
printf '     77'
STUB
  chmod 755 "$toolsdir/fuser"

  PATH="$toolsdir" run_probe probe_git_lock false "$cwd" "$(git_lock_error "$lock")"

  [ "$status" -eq 0 ]
  [ "${output%%$'\n'*}" = held ]
  printf '%s\n' "$output" | grep -qxF "pid=77"
  [ "$stderr" = "$(printf '%s:\nfuser: something odd' "$lock")" ]

  cat >"$toolsdir/fuser" <<STUB
#!/bin/sh
printf '%s:ce\n' "$lock" >&2
printf '     77'
STUB
  chmod 755 "$toolsdir/fuser"

  PATH="$toolsdir" run_probe probe_git_lock false "$cwd" "$(git_lock_error "$lock")"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = held ]
  printf '%s\n' "$output" | grep -qxF "pid=77"
}

# An lsof stub printing two pids, one per line, beside a fuser stub that
# would answer differently: lsof decides whenever it is present, first pid
# only, it is called exactly as -w -t <path> (one argument per line in its
# log, so a split or merged argument shows), and fuser is never called. The
# repo path holds a space, so an unquoted path would split.
@test "lsof decides when present" {
  local repo="$BATS_TEST_TMPDIR/r r" cwd="$BATS_TEST_TMPDIR/elsewhere" lock
  local toolsdir="$BATS_TEST_TMPDIR/tools-only" calls="$BATS_TEST_TMPDIR/lsof-calls"
  local fuser_calls="$BATS_TEST_TMPDIR/fuser-calls"
  mkdir -p "$repo/.git" "$cwd"
  lock="$repo/.git/index.lock"
  printf '1234567' >"$lock"
  tools_only_path "$toolsdir"
  cat >"$toolsdir/lsof" <<STUB
#!/bin/sh
printf '%s\n' "\$@" >"$calls"
printf '42\n43\n'
STUB
  chmod 755 "$toolsdir/lsof"
  cat >"$toolsdir/fuser" <<STUB
#!/bin/sh
printf '%s\n' "\$@" >"$fuser_calls"
printf '%s:\n' "\$1" >&2
printf '     99'
STUB
  chmod 755 "$toolsdir/fuser"

  PATH="$toolsdir" run_probe probe_git_lock false "$cwd" "$(git_lock_error "$lock")"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = held ]
  printf '%s\n' "$output" | grep -qxF "pid=42"
  [ "$(printf '%s\n' "$output" | grep -c '^pid=')" -eq 1 ]
  [ "$(cat "$calls")" = "$(printf '%s\n' -w -t "$lock")" ]
  [ ! -e "$fuser_calls" ]
}

# A symlink to a missing target: git's O_CREAT|O_EXCL lock create fails on a
# dangling symlink exactly as it does on an existing lock, so the probe reads
# something at the path and nothing can hold it open. Neither mask nor gone
# fits; the holder tool's own missing-file complaint about the link's target
# must stay off stderr, as it already does for a lock that vanishes mid-check.
@test "dangling symlink lock is a quiet orphan" {
  local repo="$BATS_TEST_TMPDIR/r" cwd="$BATS_TEST_TMPDIR/elsewhere" lock
  mkdir -p "$repo/.git" "$cwd"
  lock="$repo/.git/index.lock"
  ln -s "$BATS_TEST_TMPDIR/nowhere" "$lock"

  run_probe probe_git_lock false "$cwd" "$(git_lock_error "$lock")"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = orphan ]
  [ "$(printf '%s\n' "$output" | grep -c '^bytes=')" -eq 0 ]
  printf '%s\n' "$output" | grep -qE '^age=[0-9]+$'
  printf '%s\n' "$output" | grep -qxF "path=$lock"

  run_probe probe_git_lock true "$cwd" "$(git_lock_error "$lock")"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = orphan ]
  [ "$(printf '%s\n' "$output" | grep -c '^bytes=')" -eq 0 ]
  printf '%s\n' "$output" | grep -qE '^age=[0-9]+$'
  printf '%s\n' "$output" | grep -qxF "path=$lock"
}

# NFR-4 / A-8 (slice 4's code review): the probe writes no file, checked with
# a mktemp spy on PATH and TMPDIR naming a missing directory, as
# tests/hook.bats "hook needs no temp dir" checks for the hook. Each call
# runs in its own bash -c subprocess, sourcing lib/probes.sh fresh, so the
# env override reaches only that call and not bats' own `run
# --separate-stderr` plumbing (which uses mktemp itself). Absent,
# unheld-present and held locks are each checked, so every branch that reads
# the holder tool is covered. The probe also runs from inside the payload cwd,
# and the repo and cwd trees are listed before and after each call: a file
# written beside the lock or into the working directory, without mktemp or
# $TMPDIR, changes the listing. Proven by mutation, not by a red: the probe's
# mktemp-free path already passes every branch here.
@test "probe writes nothing" {
  local repo="$BATS_TEST_TMPDIR/r" cwd="$BATS_TEST_TMPDIR/elsewhere" lock
  local spy="$BATS_TEST_TMPDIR/spy" calls="$BATS_TEST_TMPDIR/spy-calls"
  local nonexistent="$BATS_TEST_TMPDIR/does-not-exist" before
  mkdir -p "$repo/.git" "$cwd"
  lock="$repo/.git/index.lock"
  make_spy "$spy" "$calls" mktemp
  cd "$cwd"

  before=$(find "$repo" "$cwd" | LC_ALL=C sort)
  # shellcheck disable=SC2016 # $1/$2 are the inner bash -c's own args, expanded there
  run --separate-stderr env PATH="$spy:$PATH" TMPDIR="$nonexistent" \
    bash -c 'source "$1"; probe_git_lock false "$2"' _ "$ROOT/lib/probes.sh" "$cwd" \
    <<<"$(git_lock_error "$lock")"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = mask ]
  [ ! -e "$calls" ]
  [ "$(find "$repo" "$cwd" | LC_ALL=C sort)" = "$before" ]

  printf '1234567' >"$lock"
  before=$(find "$repo" "$cwd" | LC_ALL=C sort)
  # shellcheck disable=SC2016 # $1/$2 are the inner bash -c's own args, expanded there
  run --separate-stderr env PATH="$spy:$PATH" TMPDIR="$nonexistent" \
    bash -c 'source "$1"; probe_git_lock false "$2"' _ "$ROOT/lib/probes.sh" "$cwd" \
    <<<"$(git_lock_error "$lock")"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = orphan ]
  [ ! -e "$calls" ]
  [ "$(find "$repo" "$cwd" | LC_ALL=C sort)" = "$before" ]

  hold_lock "$lock"
  before=$(find "$repo" "$cwd" | LC_ALL=C sort)
  # shellcheck disable=SC2016 # $1/$2 are the inner bash -c's own args, expanded there
  run --separate-stderr env PATH="$spy:$PATH" TMPDIR="$nonexistent" \
    bash -c 'source "$1"; probe_git_lock false "$2"' _ "$ROOT/lib/probes.sh" "$cwd" \
    <<<"$(git_lock_error "$lock")"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = held ]
  [ ! -e "$calls" ]
  [ "$(find "$repo" "$cwd" | LC_ALL=C sort)" = "$before" ]
}
