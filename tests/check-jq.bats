#!/usr/bin/env bats
# The SessionStart check: speaks only when `jq` is missing (outline D2).
# The jq-absent cases run the registered command with a PATH of symlinks to a
# fixed tool set (no `jq`); the BSD re-run is the last case.

ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs

# The tools the script may need, linked into the jq-less PATH directory. The
# set is a base chosen ahead of the implementation: the shell, plus the tools
# the BSD re-run shadows.
NOJQ_TOOLS="bash sed grep mktemp stat wc cat dirname"

registered_cmd() {
  jq -r '.hooks.SessionStart[0].hooks[0].command' "$ROOT/hooks/hooks.json"
}

# Make $BATS_TEST_TMPDIR/nojq-bin holding only $NOJQ_TOOLS; the real `jq` is
# resolved first, by absolute path, into JQ. `type -P` names the file on PATH
# even where a function or alias of the same name exists.
setup_nojq() {
  JQ=$(type -P jq)
  [ -x "$JQ" ]
  NOJQ_BIN="$BATS_TEST_TMPDIR/nojq-bin"
  mkdir -p "$NOJQ_BIN"
  local t real
  for t in $NOJQ_TOOLS; do
    real=$(type -P "$t") || { echo "setup_nojq: no $t on PATH" >&2; return 1; }
    ln -s "$real" "$NOJQ_BIN/$t"
  done
  [ ! -e "$NOJQ_BIN/jq" ]
}

# run_nojq <PATH-prefix> [VAR=value ...]: the registered command, PATH the
# prefix plus the jq-less directory, cwd the session's project not the plugin.
# `env -i` keeps the host's BASH_ENV, exported functions and SSH_CLIENT (which
# makes some builds of bash read ~/.bashrc) from putting a `jq` back in reach.
# TMPDIR is carried over so the plain run has a usable one; env applies its
# assignments in order, so a TMPDIR in the arguments replaces it.
run_nojq() {
  local prefix="$1" cmd
  shift
  cmd=$(registered_cmd)
  cd "$BATS_TEST_TMPDIR" || return
  run --separate-stderr env -i CLAUDE_PLUGIN_ROOT="$ROOT" \
    TMPDIR="${TMPDIR:-/tmp}" "$@" \
    PATH="${prefix:+$prefix:}$NOJQ_BIN" "$NOJQ_BIN/bash" -c "$cmd" </dev/null
}

assert_notice() {
  local esc
  esc=$'\033'
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  # A raw ESC byte is invalid JSON, which Claude Code's parser rejects whatever
  # this host's jq accepts: the reset must arrive as the \u001b escape.
  [[ "$output" != *"$esc"* ]]
  printf '%s' "$output" | "$JQ" -e -s 'length == 1 and (.[0] | type == "object")'
  # shellcheck disable=SC2016  # $esc is a jq variable
  printf '%s' "$output" | "$JQ" -e --arg esc "$esc" \
    '.systemMessage | startswith($esc + "[0m") and contains("jq")'
  printf '%s' "$output" | "$JQ" -e '.hookSpecificOutput.hookEventName == "SessionStart"'
  printf '%s' "$output" | "$JQ" -e '.hookSpecificOutput.additionalContext | contains("jq")'
}

@test "jq present: the registered SessionStart command is silent" {
  local cmd
  cmd=$(registered_cmd)
  # Guards against a vacuous pass: an absent registration yields "null", and
  # `bash -c null` would not be the registered command.
  # shellcheck disable=SC2016  # the literal ${...} is the registered text
  [ "$cmd" = 'bash "${CLAUDE_PLUGIN_ROOT}/hooks/check-jq.sh"' ]
  # As Claude Code runs it: the string through a shell, the plugin root
  # exported, cwd the session's project rather than the plugin checkout.
  cd "$BATS_TEST_TMPDIR"
  run --separate-stderr env CLAUDE_PLUGIN_ROOT="$ROOT" bash -c "$cmd" </dev/null
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ -z "$stderr" ]
}

@test "jq absent: one SessionStart JSON object, style reset first, naming jq" {
  setup_nojq
  run_nojq ""
  assert_notice
}

@test "jq absent: TMPDIR naming a missing directory gives the same stdout" {
  setup_nojq
  run_nojq ""
  assert_notice
  local plain="$output"
  run_nojq "" TMPDIR="$BATS_TEST_TMPDIR/no-such-dir"
  assert_notice
  [ "$output" = "$plain" ]
}

@test "jq absent: a re-run with BSD stubs ahead on PATH gives the same stdout" {
  setup_nojq
  run_nojq ""
  assert_notice
  local plain="$output"
  make_bsd_stubs "$BATS_TEST_TMPDIR/bsd-bin" sed grep mktemp stat wc
  run_nojq "$BATS_TEST_TMPDIR/bsd-bin"
  assert_notice
  [ "$output" = "$plain" ]
}
