#!/usr/bin/env bats
# lib/probes.sh: a relative lock path resolved against a directory the Bash
# command names (`cd <dir>`, `git -C <dir>`) when a lock exists there, so a
# command that runs git in another repository has its lock stat'ed in that
# repository, not in the one holding the payload cwd. Every case builds repo A
# (the cwd, no lock) and repo B (an empty, writable `.git/config.lock`), so a
# probe resolving against the cwd answers gone with A's path. Opened as a
# separate file: tests/probes-config.bats stands at 410 lines.

ROOT="${BATS_TEST_DIRNAME}/.."

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs
load helpers/probes

setup() {
  assert_unescaped_dir "$BATS_TEST_TMPDIR"
  source "$ROOT/lib/probes.sh"
  A="$BATS_TEST_TMPDIR/a"
  B="$BATS_TEST_TMPDIR/b"
  mkdir -p "$A/.git" "$B/.git"
  : >"$B/.git/config.lock"
}

# assert_lock_at <lock> — the last probe run exited 0, quiet on stderr, did
# not answer gone, and named <lock> on its path= line.
assert_lock_at() {
  local want
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" != gone ]
  want=$(LC_ALL=C; printf 'path=%q' "$1")
  printf '%s\n' "$output" | grep -qxF -- "$want"
}

# assert_cwd_fallback — the last probe run answered gone on A's lock, the
# cwd-based resolution.
assert_cwd_fallback() {
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = gone ]
  printf '%s\n' "$output" | grep -qxF "path=$A/.git/config.lock"
}

run_config() {
  run_probe_command probe_config_lock false "$A" "$1" \
    "$(config_lock_error .git/config)"
}

# The body of "cd into another repository", shared with its BSD re-run.
cd_other_repo_case() {
  run_config "cd $B && git remote add origin x"
  assert_lock_at "$B/.git/config.lock"
}

@test "cd into another repository" {
  cd_other_repo_case
}

@test "cd into another repository, with BSD sed, stat and wc" {
  local bsd="$BATS_TEST_TMPDIR/bsdtools"
  make_bsd_stubs "$bsd" sed stat wc
  PATH="$bsd:$PATH" cd_other_repo_case
}

@test "git -C another repository" {
  run_config "git -C $B config x y"
  assert_lock_at "$B/.git/config.lock"
}

@test "git-lock: git -C another repository" {
  : >"$B/.git/index.lock"
  run_probe_command probe_git_lock false "$A" "git -C $B add f" \
    "$(git_lock_error .git/index.lock)"
  assert_lock_at "$B/.git/index.lock"
}

@test "quoted targets holding a space" {
  local s="$BATS_TEST_TMPDIR/b dir"
  mkdir -p "$s/.git"
  : >"$s/.git/config.lock"

  run_config "cd \"$s\" && git remote add origin x"
  assert_lock_at "$s/.git/config.lock"

  run_config "git -C '$s' config x y"
  assert_lock_at "$s/.git/config.lock"
}

# A relative target joins onto the cwd; B sits under A, so the walk-up from
# the cwd finds A, whose lock is absent.
@test "relative cd target" {
  mkdir -p "$A/sub/b/.git"
  : >"$A/sub/b/.git/config.lock"
  run_config "cd sub/b; git remote add origin x"
  assert_lock_at "$A/sub/b/.git/config.lock"
}

# The walk-up applies to a candidate as to the cwd: a cd into B's
# subdirectory finds B's top-level.
@test "cd into a subdirectory of another repository" {
  mkdir -p "$B/src"
  run_config "(cd $B/src && git remote add origin x)"
  assert_lock_at "$B/.git/config.lock"
}

@test "tilde target" {
  HOME="$BATS_TEST_TMPDIR" run_config "cd ~/b && git remote add origin x"
  assert_lock_at "$B/.git/config.lock"
}

@test "tilde target with HOME empty yields no candidate" {
  HOME='' run_config "cd ~/b && git remote add origin x"
  assert_cwd_fallback
}

@test "a variable target yields no candidate" {
  run_config "cd \"\$B\" && git remote add origin x"
  assert_cwd_fallback
  run_config "cd \$B/x && git remote add origin x"
  assert_cwd_fallback
}

@test "a target glued to a quote or substitution yields no candidate" {
  run_config "cd $B\"x\" && git remote add origin x"
  assert_cwd_fallback
  run_config "cd $B\$(pwd) && git remote add origin x"
  assert_cwd_fallback
}

@test "the last candidate holding a lock wins" {
  local c="$BATS_TEST_TMPDIR/c"
  mkdir -p "$c/.git"

  run_config "cd $B && git remote add origin x; cd $c && git status"
  assert_lock_at "$B/.git/config.lock"

  : >"$c/.git/config.lock"
  run_config "cd $B && git remote add origin x; cd $c && git status"
  assert_lock_at "$c/.git/config.lock"
}

@test "no candidate holding a lock keeps the cwd resolution" {
  rm "$B/.git/config.lock"
  run_config "cd $B && git -C $B remote add origin x"
  assert_cwd_fallback
}

@test "cd - and an option target yield no candidate" {
  run_config "cd - && git -C -x config x y"
  assert_cwd_fallback
}

@test "an absolute lock path ignores the command" {
  run_probe_command probe_config_lock false "$A" "cd $B && git config x y" \
    "$(config_lock_error "$A/.git/config")"
  assert_cwd_fallback
}
