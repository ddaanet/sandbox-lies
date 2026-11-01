#!/usr/bin/env bats
# bin/sandbox-lies-recover: its plan output, exit codes and invocation (-C, a
# linked worktree). The recovery states themselves are in tests/recover.bats,
# which describes the refusal set-up these cases share.
#
# Contract: plans/2026-11-01-recovery-script.md. No git diagnostic is quoted
# here (self-quiet, FR-11): the refusals are asserted by exit status and HEAD
# position, as the observation table in
# skills/sandbox-lies/references/refused-merge-recovery.md records them.

# shellcheck disable=SC2030,SC2031,SC2034 # state set in a @test body is read by helpers/recover.bash

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs
load helpers/git-env
load helpers/recover

RECOVER="$BATS_TEST_DIRNAME/../bin/sandbox-lies-recover"

setup() {
  REPO="$BATS_TEST_TMPDIR/repo"
  BASEBR=main
  git config --file "$GIT_CONFIG_GLOBAL" init.defaultBranch main
}

# A frozen directory is not removable by bats; make the whole tree writable.
teardown() {
  chmod -R u+w "$BATS_TEST_TMPDIR" 2>/dev/null || true
}

# ---- the cases -------------------------------------------------------------

# Dry run.

@test "a dry run changes nothing under checkout and prints the plan" {
  scenario checkout change
  local before after
  before=$(snap)
  run rec dry checkout feat
  [ "$status" -eq 0 ]
  [[ "$output" == *"restore d/f"* ]]
  after=$(snap)
  [ "$before" = "$after" ]
}

@test "a dry run changes nothing under merge and ends the plan with the re-run" {
  scenario merge m1
  local before after
  before=$(snap)
  run rec dry merge feat
  [ "$status" -eq 0 ]
  [[ "$output" == *"remove a/new/x"* ]]
  [[ "${lines[$((${#lines[@]} - 1))]}" == *"git merge --ff-only feat" ]]
  after=$(snap)
  [ "$before" = "$after" ]
}

@test "--apply prints each act and the re-run it runs" {
  scenario merge m1
  apply_ok
  [[ "$output" == *"remove a/new/x"* ]]
  [[ "$output" == *"git merge --ff-only feat"* ]]
  assert_reached
  assert_status
}

# Exit codes.

@test "exit 0 and no change when the recovery has already been done" {
  scenario checkout change
  apply_ok
  assert_reached
  assert_status
  local before after
  before=$(snap)
  apply_ok
  after=$(snap)
  [ "$before" = "$after" ]
  assert_status
}

@test "exit 1 when the re-run is refused again, and HEAD stays" {
  build_repo same
  PRE=$(g rev-parse HEAD)
  : >"$REPO/.git/index.lock"
  run git -C "$REPO" checkout feat
  [ "$status" -ne 0 ]
  run rec apply checkout feat
  [ "$status" -eq 1 ]
  [ "$(g symbolic-ref -q HEAD)" = refs/heads/main ]
  [ "$(g rev-parse HEAD)" = "$PRE" ]
}

@test "exit 1 when kept work blocks the re-run, which leaves HEAD and the work alone" {
  scenario merge add
  printf 'mine\n' >"$REPO/d/new"
  run rec apply merge feat
  [ "$status" -eq 1 ]
  [[ "$output" == *"keep d/new"* ]]
  [ "$(g rev-parse HEAD)" = "$PRE" ]
  [ "$(g symbolic-ref -q HEAD)" = refs/heads/main ]
  assert_status '?? d/new'
  assert_bytes d/new $'mine\n'
}

@test "exit 2 without arguments" {
  build_repo plain
  run in_repo
  [ "$status" -eq 2 ]
}

@test "exit 2 for an unknown subcommand" {
  build_repo plain
  run in_repo --apply rebase feat
  [ "$status" -eq 2 ]
}

@test "exit 2 for an unknown option" {
  build_repo plain
  run in_repo --force checkout feat
  [ "$status" -eq 2 ]
}

@test "exit 2 for checkout without a branch" {
  build_repo plain
  run in_repo checkout
  [ "$status" -eq 2 ]
}

@test "exit 2 for -C naming a directory that is no repository" {
  mkdir "$BATS_TEST_TMPDIR/empty"
  run "$RECOVER" -C "$BATS_TEST_TMPDIR/empty" checkout feat
  [ "$status" -eq 2 ]
}

@test "exit 2 and nothing touched when a reached checkout has no move in the reflog" {
  cannot_tell_repo
  g symbolic-ref HEAD refs/heads/feat
  [ "$(g symbolic-ref -q HEAD)" = refs/heads/feat ]
  local before after
  before=$(snap)
  run in_repo --apply checkout feat
  [ "$status" -eq 2 ]
  [ -n "$output" ]
  after=$(snap)
  [ "$before" = "$after" ]
}

@test "exit 2 and nothing touched when a reached merge has no fast-forward in the reflog" {
  cannot_tell_repo
  local before after
  before=$(snap)
  run in_repo --apply merge main
  [ "$status" -eq 2 ]
  [ -n "$output" ]
  after=$(snap)
  [ "$before" = "$after" ]
}

@test "exit 2 and nothing touched when a commit sits above the old move onto the branch" {
  # A refused same-branch checkout writes no reflog entry, so the newest move
  # onto feat is an old one, with the user's commit and edit made since.
  build_repo change
  g checkout -q feat
  printf 'other v2\n' >"$REPO/other.txt"
  g commit -q -a -m 'on feat'
  printf 'f v1\n' >"$REPO/d/f"
  : >"$REPO/.git/index.lock"
  run git -C "$REPO" checkout feat
  rm "$REPO/.git/index.lock"
  local before after
  before=$(snap)
  run in_repo --apply checkout feat
  [ "$status" -eq 2 ]
  after=$(snap)
  [ "$before" = "$after" ]
  assert_bytes d/f $'f v1\n'
}

@test "exit 2 and nothing touched when git diff fails" {
  scenario merge change
  g config diff.algorithm bogus
  local before after
  before=$(snap)
  run in_repo --apply merge feat
  [ "$status" -eq 2 ]
  after=$(snap)
  [ "$before" = "$after" ]
}

# -C, linked worktree, portability.

@test "-C from an unrelated directory, to a repository whose path has a space" {
  REPO="$BATS_TEST_TMPDIR/my repo"
  USE_C=1
  cell checkout change
}

@test "-C names a linked worktree" {
  build_repo change
  local wt="$BATS_TEST_TMPDIR/wt tree"
  g worktree add -q -b wtb "$wt" main
  REPO=$wt
  BASEBR=wtb
  VERB=checkout
  PRE=$(g rev-parse HEAD)
  TARGET=$(g rev-parse feat)
  refuse
  thaw
  USE_C=1
  apply_ok
  assert_reached
  assert_status
}
