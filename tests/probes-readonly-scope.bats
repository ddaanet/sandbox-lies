#!/usr/bin/env bats
# lib/probes-readonly.sh's probe_readonly_path: the two facts read off every
# matching line rather than the first. claudeonly=1 says each refused path
# lies under a .claude directory; configonly=1 says each matching line is
# git's config-file write refusal. Both print under writable and nopath only.
# The git lines come from helpers/probes.bash's eperm_shape_line, built from
# fragments, so no source line here holds a refusal whole (self-quiet, FR-11).

ROOT="${BATS_TEST_DIRNAME}/.."

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs
load helpers/git-env
load helpers/probes

setup() {
  source "$ROOT/lib/probes.sh"
  assert_unescaped_dir "$BATS_TEST_TMPDIR"
  REPO="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$REPO/.git" "$REPO/.claude/agents" "$REPO/src"
}

# checkout_lines [<extra line>] — the four git refusal shapes a checkout
# printed on .claude files (fire-readonly-path-checkout-eperm), one per
# line, then <extra line> when given.
checkout_lines() {
  eperm_shape_line 3 .claude/agents/quiet-task.md
  eperm_shape_line 1 .claude/agents/commit.md
  eperm_shape_line 2 .claude/settings.json
  [ -z "${1-}" ] || printf '%s\n' "$1"
}

# fact <key> — the probe's <key>= line of the last run, empty when none.
fact() {
  printf '%s\n' "$output" | grep "^$1=" || :
}

scope_case() {
  run_probe_command probe_readonly_path false "$REPO/src" 'git checkout x' \
    "$(checkout_lines)"
  [ "$status" -eq 0 ]
  [ "${output%%$'\n'*}" = writable ]
  [ "$(fact claudeonly)" = claudeonly=1 ]
  [ -z "$(fact configonly)" ]
}

@test "every refused path under .claude, from a subdirectory, prints claudeonly=1" {
  scope_case
}

@test "every refused path under .claude prints claudeonly=1 under BSD grep and sed" {
  local bsd="$BATS_TEST_TMPDIR/bsdtools"
  make_bsd_stubs "$bsd" grep sed
  PATH="$bsd:$PATH" scope_case
}

@test "one refused path outside .claude withholds claudeonly=1" {
  run_probe_command probe_readonly_path false "$REPO" 'git checkout x' \
    "$(checkout_lines "$(eperm_shape_line 2 src/main.c)")"
  [ "$status" -eq 0 ]
  [ "${output%%$'\n'*}" = writable ]
  [ -z "$(fact claudeonly)" ]
}

@test "a refused line with no readable path withholds claudeonly=1" {
  run_probe_command probe_readonly_path false "$REPO" 'git checkout x' \
    "$(checkout_lines "$(eperm_shape_line 4 .git/config)")"
  [ "$status" -eq 0 ]
  [ -z "$(fact claudeonly)" ]
}

@test "a cp refusal under an absolute .claude path prints claudeonly=1" {
  local text
  mkdir -p "$BATS_TEST_TMPDIR/home/.claude"
  text="cp: cannot create regular file '$BATS_TEST_TMPDIR/home/.claude/x.json': $(erofs_message)"
  run_probe_command probe_readonly_path false "$REPO" 'cp a b' "$text"
  [ "$status" -eq 0 ]
  [ "${output%%$'\n'*}" = writable ]
  [ "$(fact claudeonly)" = claudeonly=1 ]
}

@test "a directory merely named like .claude does not count" {
  local text
  mkdir "$BATS_TEST_TMPDIR/x.claude"
  text="cp: cannot create regular file '$BATS_TEST_TMPDIR/x.claude/y': $(erofs_message)"
  run_probe_command probe_readonly_path false "$REPO" 'cp a b' "$text"
  [ "$status" -eq 0 ]
  [ "${output%%$'\n'*}" = writable ]
  [ -z "$(fact claudeonly)" ]
}

@test "the create-file line reads its unquoted path, joined onto the worktree top" {
  run_probe_command probe_readonly_path false "$REPO/src" 'git checkout x' \
    "$(eperm_shape_line 1 .claude/agents/commit.md)"
  [ "$status" -eq 0 ]
  [ "${output%%$'\n'*}" = writable ]
  [ "$(fact path)" = "path=$REPO/.claude/agents/commit.md" ]
}

@test "config-file write refusals alone print configonly=1" {
  local text
  text=$(printf '%s\n' "branch 'b' set up to track 'origin/b'." \
    "$(eperm_shape_line 4 .git/config)" "$(eperm_shape_line 4 .git/config)" \
    "Switched to a new branch 'b'")
  run_probe_command probe_readonly_path false "$REPO" 'git checkout origin/b -b b' "$text"
  [ "$status" -eq 0 ]
  [ "${output%%$'\n'*}" = nopath ]
  [ "$(fact configonly)" = configonly=1 ]
  [ -z "$(fact claudeonly)" ]
}

@test "a config-file write refusal worded as busy prints configonly=1" {
  run_probe_command probe_readonly_path false "$REPO" 'git branch -D b' \
    "$(eperm_shape_line 4 .git/config 'Device or resource busy')"
  [ "$status" -eq 0 ]
  [ "$(fact configonly)" = configonly=1 ]
}

@test "another refusal beside the config-file write withholds configonly=1" {
  local text
  text=$(printf '%s\n' "$(eperm_shape_line 4 .git/config)" \
    "$(eperm_shape_line 2 src/main.c)")
  run_probe_command probe_readonly_path false "$REPO" 'git checkout x' "$text"
  [ "$status" -eq 0 ]
  [ "${output%%$'\n'*}" = nopath ]
  [ -z "$(fact configonly)" ]
}

# Claude Code keeps its worktrees under <repo>/.claude/worktrees/<name>/:
# project files there run no code, so they do not count as under .claude,
# while a worktree's own .claude directory does.
@test "a path inside a .claude/worktrees checkout withholds claudeonly=1" {
  local wt="$REPO/.claude/worktrees/x"
  mkdir -p "$wt/src"
  : >"$wt/.git"
  run_probe_command probe_readonly_path false "$wt" 'git checkout x' \
    "$(eperm_shape_line 1 src/a.c)"
  [ "$status" -eq 0 ]
  [ "${output%%$'\n'*}" = writable ]
  [ "$(fact path)" = "path=$wt/src/a.c" ]
  [ -z "$(fact claudeonly)" ]
}

@test "a worktree's own .claude directory still prints claudeonly=1" {
  local wt="$REPO/.claude/worktrees/x"
  mkdir -p "$wt/.claude"
  : >"$wt/.git"
  run_probe_command probe_readonly_path false "$wt" 'git checkout x' \
    "$(eperm_shape_line 2 .claude/settings.json)"
  [ "$status" -eq 0 ]
  [ "${output%%$'\n'*}" = writable ]
  [ "$(fact claudeonly)" = claudeonly=1 ]
}
