#!/usr/bin/env bash
# The hook: payload -> text -> detect -> verdicts -> one JSON object.
# Registered on PostToolUse and PostToolUseFailure, matcher Bash
# (hooks/hooks.json). Any parse or runtime failure exits 0 with no output
# (FR-3). The text is the `error` string of a PostToolUseFailure payload, or
# tool_response.stdout, a newline, and tool_response.stderr of a PostToolUse
# payload (D-13).
#
# Writes nothing (NFR-4): no here-document, which bash before 5.1 spools
# through a temp file.
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
  PostToolUse)
    # jq -r ends each output with a newline: that is the separator.
    text=$(printf '%s' "$payload" | jq -r \
      '.tool_response.stdout // empty, .tool_response.stderr // empty') \
      || exit 0
    ;;
esac

[ -n "$text" ] || exit 0

names=$(printf '%s\n' "$text" | detect)

# detectors.md's phantom-chardev flag policy: when phantom-untracked also
# fires, its paragraph already restates the chardev one, so only
# verdict_phantom_untracked runs and phantom-chardev is skipped here.
untracked_fires=0
printf '%s\n' "$names" | grep -qFx 'phantom-untracked' && untracked_fires=1

nl='
'
context=""
human=""
while IFS= read -r name; do
  [ -n "$name" ] || continue
  if [ "$name" = "phantom-chardev" ] && [ "$untracked_fires" -eq 1 ]; then
    continue
  fi
  out=$("verdict_${name//-/_}" </dev/null) || exit 0
  para=${out%%"$nl"*}
  line=${out#*"$nl"}
  line=${line%%"$nl"*}
  context="${context:+$context$nl}$para"
  human="${human:+$human }$line"
done < <(printf '%s\n' "$names")

[ -n "$context" ] || exit 0

json=$(jq -n --arg event "$event" --arg ctx "$context" --arg sys "$human" \
  '{hookSpecificOutput: {hookEventName: $event, additionalContext: $ctx}, systemMessage: $sys}') \
  || exit 0
printf '%s\n' "$json"
