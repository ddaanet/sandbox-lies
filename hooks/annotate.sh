#!/usr/bin/env bash
# The hook: payload -> text -> detect -> verdicts -> one JSON object.
# Registered on PostToolUse and PostToolUseFailure, matcher Bash
# (hooks/hooks.json). Any parse or runtime failure exits 0 with no output
# (FR-3). The text is the `error` string of a PostToolUseFailure payload, or
# tool_response.stdout, a newline, and tool_response.stderr of a PostToolUse
# payload (D-13).
#
# One jq call reads the whole payload and cannot itself error on any input:
# `-Rs` slurps stdin as raw text (never auto-decoded, so a non-JSON payload
# never reaches jq's parser); `fromjson?` attempts the decode inside the
# filter and `?` swallows a failure there instead of raising
# (jsonlreadertypeguard); `select(type == "object")` drops a scalar or array
# payload the same way, since indexing one is fatal; every leaf read
# (`.error`, `.tool_response.stdout`, `.tool_response.stderr`) ends in
# `strings`, so a non-string field (a number, an object, an array) is
# dropped rather than rendered as text. jq prints the event name on its own
# line, then the text: event names hold no newline (the harness emits only
# "PostToolUse" or "PostToolUseFailure"), so the first line is always
# exactly the event and nothing in the text can be mistaken for the split
# point.
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

nl='
'

payload=$(cat) || exit 0

parsed=$(printf '%s' "$payload" | jq -Rrs '
    fromjson? | select(type == "object") |
    (.hook_event_name // "") as $event |
    select($event != "") |
    $event,
    (if $event == "PostToolUseFailure" then
       (.error | strings)
     elif $event == "PostToolUse" then
       (.tool_response | objects) as $tr |
       ($tr.stdout | strings), ($tr.stderr | strings)
     else empty end)
  ') || exit 0

event="$parsed"
text=""
case "$parsed" in
  *"$nl"*)
    event=${parsed%%"$nl"*}
    text=${parsed#*"$nl"}
    ;;
esac

[ -n "$event" ] || exit 0
[ -n "$text" ] || exit 0

# Non-zero is either nothing fired or detect failed: both are silent.
names=$(printf '%s\n' "$text" | detect) || exit 0

context=""
human=""
while IFS= read -r name; do
  [ -n "$name" ] || continue
  # detectors.md's phantom-chardev flag policy: one paragraph when both
  # listing detectors fire. The untracked paragraph restates the chardev
  # one, so phantom-chardev is the name skipped.
  if [ "$name" = "phantom-chardev" ]; then
    case "$nl$names$nl" in *"${nl}phantom-untracked$nl"*) continue ;; esac
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
