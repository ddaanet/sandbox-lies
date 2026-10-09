#!/usr/bin/env bats
# lib/probes.sh: a resolved lock path holding a newline (Item 5.5, reworked by
# Item 1.1). A relative lock path is joined onto the payload cwd, so a newline
# in the cwd's name would split the path= line and forge the key line after it
# (here age=). path= is printed in printf %q form, so the path stays one line:
# the outcome stands and path= is one $'...' line with the newline written \n.
# Every case builds the blank-twin directory <g> (a blank where <b> has each
# newline), whose path= line is the backslash form, and asserts both twins
# against literals: the outcome and every non-path= line, then each path= line
# in its literal encoded form, so an encoder that escapes only blanks, or one
# that leaves the newline raw, fails on <b>. Five of _probe_lock_at's six
# path= print sites are pinned: absent under each flag, character device,
# held, and the final orphan print. The gone print after a lock vanishes
# mid-probe has no deterministic trigger and stays a residual.
# Opened as a separate file: tests/probes-config.bats would pass 400 lines.

ROOT="${BATS_TEST_DIRNAME}/.."

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs
load helpers/locale
load helpers/probes

setup() {
  source "$ROOT/lib/probes.sh"
  _probe_holder_pid=
  # The literals below interpolate BATS_TEST_TMPDIR as itself; a byte %q
  # escapes in it would differ from the encoder's output for another reason.
  [ "$(LC_ALL=C printf %q "$BATS_TEST_TMPDIR")" = "$BATS_TEST_TMPDIR" ]
}

teardown() {
  kill_holder
}

# good_wire <suffix> and bad_wire <suffix> — the literal path= line for
# <suffix> under the blank twin <g> and the newline twin <b>. Written out
# rather than produced by printf %q, so the expectation is independent of the
# encoder.
good_wire() {
  printf '%s\n' "path=$BATS_TEST_TMPDIR/r\\ age=99999\\ x$1"
}

bad_wire() {
  local nl='\n'
  printf '%s\n' "path=\$'$BATS_TEST_TMPDIR/r${nl}age=99999${nl}x$1'"
}

# assert_lines <path-line> <line>... — the last run's output holds exactly one
# path= line, equal to <path-line>, and every other line is the <line>s given,
# in order, the first of them on line 1 (the outcome token, which a path= line
# printed ahead of it would displace). A forged key line from a split path=
# lands among the other lines and fails the third check.
assert_lines() {
  local wire="$1"
  shift
  [ "${output%%$'\n'*}" = "$1" ]
  [ "$(printf '%s\n' "$output" | grep '^path=')" = "$wire" ]
  [ "$(printf '%s\n' "$output" | grep -v '^path=')" = "$(printf '%s\n' "$@")" ]
}

# orphan_twins <path> — the orphan halves with the probe run under PATH=<path>.
# The outcome token is read off <b>'s line 1 rather than written here: it is
# orphan where a holder tool is on PATH and unknown where none is, and the
# case pins the facts around it, not which host it runs on. <g> must give the
# same token. Each age= value is read back from its own output's first age=
# line and must lie within a minute of the lock's real age (its mtime
# backdated to 2000), so a forged age=99999 cannot stand in for it; a forged
# second line fails assert_lines.
orphan_twins() {
  local probe_path="$1" token age real
  local good="$BATS_TEST_TMPDIR/r age=99999 x"
  local bad="$BATS_TEST_TMPDIR/r"$'\n'"age=99999"$'\n'"x"
  mkdir -p "$good/.git" "$bad/.git"
  printf 'abc' >"$good/.git/index.lock"
  printf 'abc' >"$bad/.git/index.lock"
  touch -t 200001010000 "$good/.git/index.lock" "$bad/.git/index.lock"
  real=$(($(date +%s) - $(index_mtime "$good/.git/index.lock")))

  PATH="$probe_path" run_probe probe_git_lock false "$bad" \
    "$(git_lock_error .git/index.lock)"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  token=${output%%$'\n'*}
  [ "$token" = orphan ] || [ "$token" = unknown ]
  age=$(printf '%s\n' "$output" | grep -m1 '^age=')
  [ "${age#age=}" -ge $((real - 60)) ]
  [ "${age#age=}" -le $((real + 60)) ]
  assert_lines "$(bad_wire /.git/index.lock)" "$token" bytes=3 "$age"

  PATH="$probe_path" run_probe probe_git_lock false "$good" \
    "$(git_lock_error .git/index.lock)"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  age=$(printf '%s\n' "$output" | grep -m1 '^age=')
  [ "${age#age=}" -ge $((real - 60)) ]
  [ "${age#age=}" -le $((real + 60)) ]
  assert_lines "$(good_wire /.git/index.lock)" "$token" bytes=3 "$age"
}

# The middle half names <g> absolutely from cwd <b>, so a guard keyed on the
# cwd rather than the resolved path fails it: its path= line is <g>'s, not <b>'s.
@test "config-lock: a resolved lock path holding a newline gives mask and one encoded path= line" {
  local good="$BATS_TEST_TMPDIR/r age=99999 x"
  local bad="$BATS_TEST_TMPDIR/r"$'\n'"age=99999"$'\n'"x"
  mkdir -p "$good/.git" "$bad/.git"

  run_probe probe_config_lock false "$bad" "$(config_lock_error .git/config)"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  assert_lines "$(bad_wire /.git/config.lock)" mask

  run_probe probe_config_lock false "$bad" \
    "$(config_lock_error "$good/.git/config")"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  assert_lines "$(good_wire /.git/config.lock)" mask

  run_probe probe_config_lock false "$good" "$(config_lock_error .git/config)"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  assert_lines "$(good_wire /.git/config.lock)" mask
}

@test "git-lock orphan: a resolved lock path holding a newline gives one encoded path= line" {
  orphan_twins "$PATH"
}

# The orphan case again through BSD sed, stat and wc: the one case in this
# suite re-run with make_bsd_stubs on PATH.
@test "git-lock orphan under BSD sed, stat and wc: a newline-bearing path gives one encoded path= line" {
  local bsd="$BATS_TEST_TMPDIR/bsdtools"
  make_bsd_stubs "$bsd" sed stat wc
  orphan_twins "$bsd:$PATH"
}

# The <b> holder is killed and its ready file removed before <g>'s is started:
# hold_lock returns as soon as that file exists, so a stale one would let the
# probe run ahead of the second open.
@test "git-lock held: a resolved lock path holding a newline gives one encoded path= line" {
  local good="$BATS_TEST_TMPDIR/r age=99999 x"
  local bad="$BATS_TEST_TMPDIR/r"$'\n'"age=99999"$'\n'"x"
  mkdir -p "$good/.git" "$bad/.git"
  printf 'abc' >"$good/.git/index.lock"
  printf 'abc' >"$bad/.git/index.lock"

  hold_lock "$bad/.git/index.lock"
  run_probe probe_git_lock false "$bad" "$(git_lock_error .git/index.lock)"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  assert_lines "$(bad_wire /.git/index.lock)" held "pid=$_probe_holder_pid"
  kill_holder
  rm "$BATS_TEST_TMPDIR/holder-ready"

  hold_lock "$good/.git/index.lock"
  run_probe probe_git_lock false "$good" "$(git_lock_error .git/index.lock)"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  assert_lines "$(good_wire /.git/index.lock)" held "pid=$_probe_holder_pid"
}

# Flag true, so an absent lock reads gone: mask can only come from the
# character-device rule (a symlink to /dev/null), not from the absent-lock
# print under flag false.
@test "git-lock character device: a newline-bearing path gives mask and one encoded path= line" {
  local good="$BATS_TEST_TMPDIR/r age=99999 x"
  local bad="$BATS_TEST_TMPDIR/r"$'\n'"age=99999"$'\n'"x"
  mkdir -p "$good/.git" "$bad/.git"
  ln -s /dev/null "$good/.git/index.lock"
  ln -s /dev/null "$bad/.git/index.lock"

  run_probe probe_git_lock true "$bad" "$(git_lock_error .git/index.lock)"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  assert_lines "$(bad_wire /.git/index.lock)" mask

  run_probe probe_git_lock true "$good" "$(git_lock_error .git/index.lock)"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  assert_lines "$(good_wire /.git/index.lock)" mask
}

# The middle half names <g> absolutely from cwd <b>, as in the config-lock
# case, for a cwd-keyed guard placed in probe_git_lock.
@test "git-lock gone: a resolved lock path holding a newline gives gone and one encoded path= line" {
  local good="$BATS_TEST_TMPDIR/r age=99999 x"
  local bad="$BATS_TEST_TMPDIR/r"$'\n'"age=99999"$'\n'"x"
  mkdir -p "$good/.git" "$bad/.git"

  run_probe probe_git_lock true "$bad" "$(git_lock_error .git/index.lock)"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  assert_lines "$(bad_wire /.git/index.lock)" gone

  run_probe probe_git_lock true "$bad" \
    "$(git_lock_error "$good/.git/index.lock")"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  assert_lines "$(good_wire /.git/index.lock)" gone

  run_probe probe_git_lock true "$good" "$(git_lock_error .git/index.lock)"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  assert_lines "$(good_wire /.git/index.lock)" gone
}

# A newline and a non-ASCII byte pair in one path, under a UTF-8 locale: the
# one line carries both, newline as \n and each byte as octal.
@test "git-lock gone: a newline and e-acute in one lock path print one encoded line under a UTF-8 locale" {
  local loc cwd="$BATS_TEST_TMPDIR/r"$'\n\303\251'
  loc=$(utf8_locale)
  mkdir -p "$cwd/.git"

  LC_ALL="$loc" run_probe probe_git_lock true "$cwd" \
    "$(git_lock_error .git/index.lock)"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  assert_lines "path=\$'$BATS_TEST_TMPDIR/r\\n\\303\\251/.git/index.lock'" gone
}
