#!/usr/bin/env bats
# lib/probes.sh: probe_config_lock (Item 2.4 slice 8) and the relative-path
# base resolution it settles ($2's nearest .git ancestor, falling back to $2,
# falling back to the probe's own working directory). Opened as a separate
# file: tests/probes.bats already stands at 325 lines.

ROOT="${BATS_TEST_DIRNAME}/.."

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs
load helpers/probes

setup() {
  source "$ROOT/lib/probes.sh"
}

# The config-lock error names the config file itself (no quotes, no ".lock"
# suffix), unlike git-lock's "Unable to create '<path>.lock'" line; the probe
# appends ".lock". The text names an absolute path, so this case is
# independent of $2's base-resolution rules (slices below).
@test "config-lock reads its own error" {
  local repo="$BATS_TEST_TMPDIR/r" cwd="$BATS_TEST_TMPDIR/elsewhere" lock
  mkdir -p "$repo/.git" "$cwd"
  lock="$repo/.git/config.lock"

  run_probe probe_config_lock false "$cwd" "$(config_lock_error "$repo/.git/config")"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = mask ]
  printf '%s\n' "$output" | grep -qxF "path=$lock"

  printf '1234567' >"$lock"

  run_probe probe_config_lock false "$cwd" "$(config_lock_error "$repo/.git/config")"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = orphan ]
  printf '%s\n' "$output" | grep -qxF "bytes=7"
  printf '%s\n' "$output" | grep -qxF "path=$lock"
}

# The suffix goes on the file the text names, whatever its name: from a linked
# worktree git names <main>/.git/worktrees/<wt>/config.worktree, absolute, so
# a probe that rebuilt the path as <dir>/config.lock or <$2>/.git/config.lock
# misses it. Under a quoted, spaced directory, as the text carries it
# unquoted.
@test "config-lock appends .lock to the named file" {
  local top="$BATS_TEST_TMPDIR/it's here" wtdir lock
  wtdir="$top/main/.git/worktrees/wt"
  mkdir -p "$wtdir" "$top/wt"
  lock="$wtdir/config.worktree.lock"
  printf '1234567' >"$lock"

  run_probe probe_config_lock false "$top/wt" "$(config_lock_error "$wtdir/config.worktree")"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = orphan ]
  printf '%s\n' "$output" | grep -qxF "bytes=7"
  printf '%s\n' "$output" | grep -qxF "path=$lock"
}

# Each probe reads its own line from a text holding both, the other probe's
# line first, and the lock that line names present where the probe's own is
# absent: a probe reading either shape, or the first lock line of any shape,
# answers orphan with the decoy's path. Git-lock text alone is not a
# config-lock error: probe_config_lock does not fall back to the index lock.
@test "each probe reads only its own lock line" {
  local repo="$BATS_TEST_TMPDIR/r4" cwd="$BATS_TEST_TMPDIR/elsewhere" index config
  mkdir -p "$repo/.git" "$cwd"
  index="$repo/.git/index.lock"
  config="$repo/.git/config.lock"

  printf '1234567' >"$config"
  run_probe probe_git_lock false "$cwd" \
    "$(config_lock_error "$repo/.git/config"; git_lock_error "$index")"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = mask ]
  printf '%s\n' "$output" | grep -qxF "path=$index"

  rm "$config"
  printf '1234567' >"$index"
  run_probe probe_config_lock false "$cwd" \
    "$(git_lock_error "$index"; config_lock_error "$repo/.git/config")"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = mask ]
  printf '%s\n' "$output" | grep -qxF "path=$config"

  run_probe probe_config_lock false "$cwd" "$(git_lock_error "$index")"

  [ "$status" -eq 0 ]
  [ "${output%%$'\n'*}" != orphan ]
  [ "${output%%$'\n'*}" != held ]
  [ "$(printf '%s\n' "$output" | grep -cxF "path=$index")" -eq 0 ]
}

# Text with no lock line at all: $2 is an existing directory that is also the
# probe's own process cwd (the "cd" below, not just the argument), so a
# resolver that joined the empty extracted path onto $2 or onto the process
# cwd would land on a real, existing directory — one the probe's own shell
# sits in, so the holder check finds a "holder" (this process) and misreads
# it as held. Already fixed (Item 2.4 slice 7's code review): an empty
# extracted path is never joined onto anything.
@test "pathless text never names the base" {
  local dir="$BATS_TEST_TMPDIR/pathless"
  mkdir -p "$dir"
  cd "$dir"

  run_probe probe_git_lock false "$dir" "$(printf 'quiet preamble text\n')"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" != held ]
  [ "${output%%$'\n'*}" != orphan ]
  [ "$(printf '%s\n' "$output" | grep -c '^pid=')" -eq 0 ]

  run_probe probe_git_lock true "$dir" "$(printf 'quiet preamble text\n')"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" != held ]
  [ "${output%%$'\n'*}" != orphan ]
  [ "$(printf '%s\n' "$output" | grep -c '^pid=')" -eq 0 ]
}

# Git prints the config-lock path relative to the main worktree's top-level
# even from a subdirectory: $2 is a subdirectory holding no .git of its own,
# and the lock the text names relative to $2 sits at the ancestor repo's
# .git/config.lock instead. Resolving against $2 itself, with no walk-up,
# would look for <repo>/sub/.git/config.lock, which does not exist, and misread
# the present lock as absent.
@test "config-lock from a subdirectory" {
  local repo="$BATS_TEST_TMPDIR/r2" sub lock
  sub="$repo/sub"
  mkdir -p "$repo/.git" "$sub"
  lock="$repo/.git/config.lock"
  printf '1234567' >"$lock"

  run_probe probe_config_lock false "$sub" "$(config_lock_error .git/config)"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = orphan ]
  printf '%s\n' "$output" | grep -qxF "path=$lock"
}

# A repo nested in another: the walk-up stops at the nearest .git, and $2
# itself counts when it holds one. The inner lock is present and the outer
# absent, so a walk to the outermost .git reads mask with the outer path; $2
# two levels below the inner repo catches a single dirname step, and $2 the
# inner repo itself catches a walk starting at its parent.
@test "config-lock resolves at the nearest .git" {
  local outer="$BATS_TEST_TMPDIR/outer" inner lock
  inner="$outer/inner"
  mkdir -p "$outer/.git" "$inner/.git" "$inner/a/b"
  lock="$inner/.git/config.lock"
  printf '1234567' >"$lock"

  run_probe probe_config_lock false "$inner/a/b" "$(config_lock_error .git/config)"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = orphan ]
  printf '%s\n' "$output" | grep -qxF "path=$lock"

  run_probe probe_config_lock false "$inner" "$(config_lock_error .git/config)"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = orphan ]
  printf '%s\n' "$output" | grep -qxF "path=$lock"
}

# $2 has no .git in it or in any ancestor up to /, checked here before the
# probe runs: the walk-up then finds nothing and falls back to $2 itself, the
# same result the plain (pre-walk-up) join onto $2 already gave.
@test "no .git above cwd keeps cwd" {
  local cwd="$BATS_TEST_TMPDIR/nogit/deep" lock ancestor
  mkdir -p "$cwd"
  lock="$cwd/.git/index.lock"

  ancestor="$cwd"
  while [ "$ancestor" != / ]; do
    [ ! -e "$ancestor/.git" ]
    ancestor=$(dirname "$ancestor")
  done
  [ ! -e "/.git" ]

  run_probe probe_git_lock false "$cwd" "$(git_lock_error .git/index.lock)"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = mask ]
  printf '%s\n' "$output" | grep -qxF "path=$lock"
}

# $2 absent, then $2 the empty string: the probe falls back to its own
# process working directory rather than joining the relative path onto
# nothing, which would print a path rooted at / (never under the repo the
# probe actually ran from).
@test "missing or empty cwd uses the working directory" {
  local repo="$BATS_TEST_TMPDIR/r3" lock
  mkdir -p "$repo/.git"
  lock="$repo/.git/index.lock"
  printf '1234567' >"$lock"
  cd "$repo"

  run --separate-stderr probe_git_lock false <<<"$(git_lock_error .git/index.lock)"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = orphan ]
  printf '%s\n' "$output" | grep -qxF "path=$repo/.git/index.lock"

  run --separate-stderr probe_git_lock false "" <<<"$(git_lock_error .git/index.lock)"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = orphan ]
  printf '%s\n' "$output" | grep -qxF "path=$repo/.git/index.lock"
}
