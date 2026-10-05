#!/usr/bin/env bats
# The SessionStart check: speaks only when `jq` is missing (outline D2).
# Pending (slice 2): the jq-absent notice, TMPDIR missing, and a case re-run
# with `make_bsd_stubs` on PATH.

ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs

@test "jq present: the registered SessionStart command is silent" {
  local cmd
  cmd=$(jq -r '.hooks.SessionStart[0].hooks[0].command' "$ROOT/hooks/hooks.json")
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
