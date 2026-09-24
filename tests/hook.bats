#!/usr/bin/env bats
# The hook: payload -> text -> detect -> probes -> one JSON verdict object.
#
# Runs a COPY of hooks/ and lib/ under $BATS_TEST_TMPDIR (helpers/hook's
# hook_copy_tree), so a case can stub a copied lib file without touching the
# tracked source. Payloads are built from the Item 1.4 recorded fixtures.

ROOT="${BATS_TEST_DIRNAME}/.."

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs
load helpers/hook

setup() {
  hook_copy_tree
}

@test "gitadd failure payload yields one verdict" {
  local text payload
  text=$(cat "$FIXTURES/fire-masks-gitadd-refused.txt")
  payload=$(failure_payload "$text")
  run bash -c 'printf "%s" "$1" | bash "$2"' \
    _ "$payload" "$HOOK_COPY/hooks/annotate.sh"
  [ "$status" -eq 0 ]
  printf '%s' "$output" | jq -e . >/dev/null

  local keys hso_keys
  keys=$(printf '%s' "$output" | jq -S -c 'keys')
  [ "$keys" = '["hookSpecificOutput","systemMessage"]' ]
  hso_keys=$(printf '%s' "$output" | jq -S -c '.hookSpecificOutput | keys')
  [ "$hso_keys" = '["additionalContext","hookEventName"]' ]
  [ "$(printf '%s' "$output" | jq -r '.hookSpecificOutput.hookEventName')" \
    = "PostToolUseFailure" ]
  printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext' \
    | grep -qF 'Stage explicit paths'
  [ "$(printf '%s' "$output" | jq -r '.systemMessage')" \
    = 'git add — refused a sandbox mask' ]
}

@test "quiet fixture yields nothing" {
  # Paired with the gitadd test above: an inert stub also yields empty
  # stdout here on its own — a negative by nature, so this case's red comes
  # from that pairing, not from this assertion alone. The failure payload is
  # the pairing proper — same helper and event as the gitadd case, only the
  # text differs — so a hook that emits on the event alone fails here.
  local text payload
  text=$(cat "$FIXTURES/quiet-clean-status.txt")
  payload=$(post_payload "$text")
  run bash -c 'printf "%s" "$1" | bash "$2"' \
    _ "$payload" "$HOOK_COPY/hooks/annotate.sh"
  [ "$status" -eq 0 ]
  [ -z "$output" ]

  payload=$(failure_payload "Exit code 1"$'\n'"$text")
  run bash -c 'printf "%s" "$1" | bash "$2"' \
    _ "$payload" "$HOOK_COPY/hooks/annotate.sh"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "hooks.json names both events" {
  # Exactly these two events (FR-1: no PreToolUse), each registered once, as
  # the command hook.bats runs: `bash` on the plugin root's script.
  run jq -e --arg cmd 'bash "${CLAUDE_PLUGIN_ROOT}/hooks/annotate.sh"' '
    def one($k):
      (.hooks[$k] | length == 1)
      and (.hooks[$k][0].matcher == "Bash")
      and (.hooks[$k][0].hooks | length == 1)
      and (.hooks[$k][0].hooks[0].type == "command")
      and (.hooks[$k][0].hooks[0].timeout == 10)
      and (.hooks[$k][0].hooks[0].command == $cmd);
    (.hooks | keys == ["PostToolUse", "PostToolUseFailure"])
    and one("PostToolUse") and one("PostToolUseFailure")
  ' "$ROOT/hooks/hooks.json"
  [ "$status" -eq 0 ]
}
