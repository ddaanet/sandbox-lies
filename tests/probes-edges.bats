#!/usr/bin/env bats
# lib/probes.sh: probe_git_lock edge cases whose fixes landed in code
# reviews ahead of a test — a lock vanishing mid-probe, non-regular and
# dangling-symlink locks, clock skew, holder-tool stubs — and NFR-4's
# writes-nothing check. Each case is pinned by mutation, not by a red against
# unimplemented behaviour.

ROOT="${BATS_TEST_DIRNAME}/.."

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs
load helpers/git-env
load helpers/probes
load helpers/spy

setup() {
  source "$ROOT/lib/probes.sh"
  _probe_holder_pid=
}

teardown() {
  kill_holder
}

# touch -t 209901010000 backdates nothing; it sets a future mtime, the clock
# skew case. Age is clamped to 0, not left negative.
# The body of "future mtime is age 0", shared with its BSD re-run.
future_mtime_case() {
  local repo="$BATS_TEST_TMPDIR/r" cwd="$BATS_TEST_TMPDIR/elsewhere" lock
  mkdir -p "$repo/.git" "$cwd"
  lock="$repo/.git/index.lock"
  printf '1234567' >"$lock"
  touch -t 209901010000 "$lock"

  run_probe probe_git_lock false "$cwd" "$(git_lock_error "$lock")"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = orphan ]
  # The size line is the BSD re-run's wc check: BSD wc pads its count.
  printf '%s\n' "$output" | grep -qxF "bytes=7"
  printf '%s\n' "$output" | grep -qxF "age=0"
}

# A stat stub on PATH removes its path operand, then runs the real stat: the
# window git's own lock cleanup can land in, between the presence test and
# the mtime read. Recreates the lock between the two flag runs so the second
# run also has something for the stub to remove, rather than hitting the
# probe's earlier, already-absent-at-entry path. That path also reads
# gone now, so the stub logs its call and the log shows the stat was reached.
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
echo called >>"$stubdir/stat-called"
exec "$realstat" "\$@"
STUB
  chmod 755 "$stubdir/stat"

  printf '1234567' >"$lock"
  PATH="$stubdir:$PATH" run_probe probe_git_lock false "$cwd" "$(git_lock_error "$lock")"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ -s "$stubdir/stat-called" ]
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

@test "future mtime is age 0" {
  future_mtime_case
}

@test "future mtime is age 0, with BSD sed, stat and wc" {
  local bsd="$BATS_TEST_TMPDIR/bsdtools"
  make_bsd_stubs "$bsd" sed stat wc
  PATH="$bsd:$PATH" future_mtime_case
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
echo called >>"$toolsdir/fuser-called"
exit 1
STUB
  chmod 755 "$toolsdir/fuser"

  printf '1234567' >"$lock"
  PATH="$toolsdir" run_probe probe_git_lock false "$cwd" "$(git_lock_error "$lock")"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ -s "$toolsdir/fuser-called" ]
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
  [ "${output%%$'\n'*}" = gone ]
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

# The same check on the readonly-path probe, whose _readonly_print_facts runs
# git reads on a refusal of a writable path: line 1 `writable` and a merge=1
# line show the facts ran, so a write there is inside what the listing, the
# spy and the nonexistent TMPDIR watch. Proven by mutation (a mktemp call at
# the top of _readonly_print_facts), not by a red against unimplemented
# behaviour.
@test "readonly-path probe writes nothing" {
  local repo="$BATS_TEST_TMPDIR/r" cwd="$BATS_TEST_TMPDIR/elsewhere" text before
  local spy="$BATS_TEST_TMPDIR/spy" calls="$BATS_TEST_TMPDIR/spy-calls"
  local nonexistent="$BATS_TEST_TMPDIR/does-not-exist"
  make_scratch_repo "$repo"
  mkdir -p "$cwd"
  make_spy "$spy" "$calls" mktemp
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'$repo/a'")
  cd "$cwd"

  before=$(find "$repo" "$cwd" | LC_ALL=C sort)
  # shellcheck disable=SC2016 # $1..$3 are the inner bash -c's own args, expanded there
  run --separate-stderr env PATH="$spy:$PATH" TMPDIR="$nonexistent" \
    bash -c 'source "$1"; probe_readonly_path false "$2" "$3"' \
    _ "$ROOT/lib/probes.sh" "$repo" 'git merge feat' <<<"$text"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = writable ]
  printf '%s\n' "$output" | command grep -qxF 'merge=1'
  [ ! -e "$calls" ]
  [ "$(find "$repo" "$cwd" | LC_ALL=C sort)" = "$before" ]
}
