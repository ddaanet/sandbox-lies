#!/usr/bin/env bats
# lib/probes.sh: a resolved lock path holding a newline (Item 5.5). A relative
# lock path is joined onto the payload cwd, so a newline in the cwd's name
# splits the path= line and forges the key line after it (here age=). The
# outcome stands and path= is left out. Every case builds the blank-twin
# directory <g> (a blank where <b> has each newline) and compares whole
# outputs, so a guard that also drops blanks fails on <g>. Five of
# _probe_lock_at's six path= print sites are pinned: absent under each flag,
# character device, held, and the final orphan print. The gone print after a
# lock vanishes mid-probe has no deterministic trigger and stays a residual.
# Opened as a separate file: tests/probes-config.bats would pass 400 lines.

ROOT="${BATS_TEST_DIRNAME}/.."

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs
load helpers/probes

setup() {
  source "$ROOT/lib/probes.sh"
  _probe_holder_pid=
}

teardown() {
  kill_holder
}

# orphan_twins <path> — the orphan halves with the probe run under PATH=<path>.
# The outcome token is read off the blank twin's line 1 rather than written
# here: it is orphan where a holder tool is on PATH and unknown where none is,
# and the case pins the facts around it, not which host it runs on. Each age=
# value is read back from the output's first age= line and must lie within a
# minute of the lock's real age (its mtime backdated to 2000), so a forged
# age=99999 cannot stand in for it; a forged second line fails the
# whole-output equality.
orphan_twins() {
  local probe_path="$1" token age real
  local good="$BATS_TEST_TMPDIR/r age=99999 x"
  local bad="$BATS_TEST_TMPDIR/r"$'\n'"age=99999"$'\n'"x"
  mkdir -p "$good/.git" "$bad/.git"
  printf 'abc' >"$good/.git/index.lock"
  printf 'abc' >"$bad/.git/index.lock"
  touch -t 200001010000 "$good/.git/index.lock" "$bad/.git/index.lock"

  PATH="$probe_path" run_probe probe_git_lock false "$good" \
    "$(git_lock_error .git/index.lock)"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  token=${output%%$'\n'*}
  [ "$token" = orphan ] || [ "$token" = unknown ]
  age=$(printf '%s\n' "$output" | grep -m1 '^age=')
  real=$(($(date +%s) - $(index_mtime "$good/.git/index.lock")))
  [ "${age#age=}" -ge $((real - 60)) ]
  [ "${age#age=}" -le $((real + 60)) ]
  [ "$output" = "$(printf '%s\n' "$token" bytes=3 "$age" \
    "path=$good/.git/index.lock")" ]

  PATH="$probe_path" run_probe probe_git_lock false "$bad" \
    "$(git_lock_error .git/index.lock)"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  age=$(printf '%s\n' "$output" | grep -m1 '^age=')
  [ "${age#age=}" -ge $((real - 60)) ]
  [ "${age#age=}" -le $((real + 60)) ]
  [ "$output" = "$(printf '%s\n' "$token" bytes=3 "$age")" ]
}

# The middle half names <g> absolutely from cwd <b>, so a guard keyed on the
# cwd rather than the resolved path fails it.
@test "config-lock: a resolved lock path holding a newline gives mask without path=" {
  local good="$BATS_TEST_TMPDIR/r age=99999 x"
  local bad="$BATS_TEST_TMPDIR/r"$'\n'"age=99999"$'\n'"x"
  mkdir -p "$good/.git" "$bad/.git"

  run_probe probe_config_lock false "$good" "$(config_lock_error .git/config)"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "$output" = "$(printf '%s\n' mask "path=$good/.git/config.lock")" ]

  run_probe probe_config_lock false "$bad" \
    "$(config_lock_error "$good/.git/config")"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "$output" = "$(printf '%s\n' mask "path=$good/.git/config.lock")" ]

  run_probe probe_config_lock false "$bad" "$(config_lock_error .git/config)"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "$output" = mask ]
}

@test "git-lock orphan: a resolved lock path holding a newline gives no path=" {
  orphan_twins "$PATH"
}

# The orphan case again through BSD sed, stat and wc: the one case in this
# suite re-run with make_bsd_stubs on PATH.
@test "git-lock orphan under BSD sed, stat and wc: a newline-bearing path gives no path=" {
  local bsd="$BATS_TEST_TMPDIR/bsdtools"
  make_bsd_stubs "$bsd" sed stat wc
  orphan_twins "$bsd:$PATH"
}

# The <g> holder is killed and its ready file removed before <b>'s is started:
# hold_lock returns as soon as that file exists, so a stale one would let the
# probe run ahead of the second open.
@test "git-lock held: a resolved lock path holding a newline gives no path=" {
  local good="$BATS_TEST_TMPDIR/r age=99999 x"
  local bad="$BATS_TEST_TMPDIR/r"$'\n'"age=99999"$'\n'"x"
  mkdir -p "$good/.git" "$bad/.git"
  printf 'abc' >"$good/.git/index.lock"
  printf 'abc' >"$bad/.git/index.lock"

  hold_lock "$good/.git/index.lock"
  run_probe probe_git_lock false "$good" "$(git_lock_error .git/index.lock)"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "$output" = "$(printf '%s\n' held "pid=$_probe_holder_pid" \
    "path=$good/.git/index.lock")" ]
  kill_holder
  rm "$BATS_TEST_TMPDIR/holder-ready"

  hold_lock "$bad/.git/index.lock"
  run_probe probe_git_lock false "$bad" "$(git_lock_error .git/index.lock)"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "$output" = "$(printf '%s\n' held "pid=$_probe_holder_pid")" ]
}

# Flag true, so an absent lock reads gone: mask can only come from the
# character-device rule (a symlink to /dev/null), not from the absent-lock
# print under flag false.
@test "git-lock character device: a newline-bearing path gives mask without path=" {
  local good="$BATS_TEST_TMPDIR/r age=99999 x"
  local bad="$BATS_TEST_TMPDIR/r"$'\n'"age=99999"$'\n'"x"
  mkdir -p "$good/.git" "$bad/.git"
  ln -s /dev/null "$good/.git/index.lock"
  ln -s /dev/null "$bad/.git/index.lock"

  run_probe probe_git_lock true "$good" "$(git_lock_error .git/index.lock)"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "$output" = "$(printf '%s\n' mask "path=$good/.git/index.lock")" ]

  run_probe probe_git_lock true "$bad" "$(git_lock_error .git/index.lock)"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "$output" = mask ]
}

# The middle half names <g> absolutely from cwd <b>, as in the config-lock
# case, for a cwd-keyed guard placed in probe_git_lock.
@test "git-lock gone: a resolved lock path holding a newline gives no path=" {
  local good="$BATS_TEST_TMPDIR/r age=99999 x"
  local bad="$BATS_TEST_TMPDIR/r"$'\n'"age=99999"$'\n'"x"
  mkdir -p "$good/.git" "$bad/.git"

  run_probe probe_git_lock true "$good" "$(git_lock_error .git/index.lock)"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "$output" = "$(printf '%s\n' gone "path=$good/.git/index.lock")" ]

  run_probe probe_git_lock true "$bad" \
    "$(git_lock_error "$good/.git/index.lock")"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "$output" = "$(printf '%s\n' gone "path=$good/.git/index.lock")" ]

  run_probe probe_git_lock true "$bad" "$(git_lock_error .git/index.lock)"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "$output" = gone ]
}
