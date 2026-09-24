#!/usr/bin/env bash
# The hook: payload -> text -> detect -> probes -> one JSON verdict object.
# Registered on PostToolUse and PostToolUseFailure, matcher Bash
# (hooks/hooks.json). Any parse or runtime failure exits 0 with no output
# (FR-3).
#
# Slice 1 (Item 2.3): the failure-payload text comes from `error` (D-13); the
# PostToolUse success-text rebuild from tool_response.stdout/stderr lands in
# a later slice, so a success payload contributes no text here yet. Probe
# calls join in Item 4.1.
set -u

script_dir=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd) || exit 0
lib_dir="$script_dir/../lib"
# shellcheck disable=SC1091 # lib/ sits beside this script; path is dynamic
. "$lib_dir/matchers.sh" || exit 0
# shellcheck disable=SC1091 # lib/ sits beside this script; path is dynamic
. "$lib_dir/verdicts.sh" || exit 0

payload=$(cat) || exit 0

event=$(printf '%s' "$payload" | jq -r '.hook_event_name // empty') || exit 0
[ -n "$event" ] || exit 0

text=""
case "$event" in
  PostToolUseFailure)
    text=$(printf '%s' "$payload" | jq -r '.error // empty') || exit 0
    ;;
esac

[ -n "$text" ] || exit 0

names=$(printf '%s\n' "$text" | detect)
[ -n "$names" ] || exit 0

context_parts=()
human_parts=()
while IFS= read -r name; do
  [ -n "$name" ] || continue
  fn="verdict_${name//-/_}"
  out=$("$fn" </dev/null)
  context_parts+=("$(printf '%s\n' "$out" | sed -n '1p')")
  human_parts+=("$(printf '%s\n' "$out" | sed -n '2p')")
done <<NAMES
$names
NAMES

[ "${#context_parts[@]}" -gt 0 ] || exit 0

context=$(printf '%s\n' "${context_parts[@]}")
human=$(printf '%s ' "${human_parts[@]}")
human="${human% }"

jq -n --arg event "$event" --arg ctx "$context" --arg sys "$human" \
  '{hookSpecificOutput: {hookEventName: $event, additionalContext: $ctx}, systemMessage: $sys}'
