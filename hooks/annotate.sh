#!/usr/bin/env bash
# The hook: payload -> text -> detect -> verdicts -> one JSON object.
# Registered on PostToolUse and PostToolUseFailure, matcher Bash
# (hooks/hooks.json). Any parse or runtime failure exits 0 with no output
# (FR-3). The text is the `error` string of a PostToolUseFailure payload, or
# whichever of tool_response.stdout and tool_response.stderr are strings,
# joined by a newline, of a PostToolUse payload (D-13).
#
# One jq call reads stdin and cannot error on any input, so nothing reaches
# stderr: `-Rs` takes it as one raw string and `fromjson?` decodes it,
# dropping what does not parse; `select(type == "object")` drops a scalar or
# array, which jq cannot index without a fatal error; only a string field is
# read as text. The output is the event, then each text part, each ending in
# a newline, which is the join. The event is printed only when it equals one
# of the two literal names, so the first newline is always the split point.
# NUL bytes are dropped in jq: bash drops them from a `$(...)` too, but warns
# on stderr.
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

parsed=$(jq -Rrs '
    fromjson? | select(type == "object") |
    .hook_event_name as $event |
    if $event == "PostToolUseFailure" then
      $event, (.error | strings)
    elif $event == "PostToolUse" then
      $event,
      (.tool_response | objects | (.stdout | strings), (.stderr | strings))
    else empty end |
    split("\u0000") | join("")
  ') || exit 0

text=""
case "$parsed" in
  *"$nl"*)
    event=${parsed%%"$nl"*}
    text=${parsed#*"$nl"}
    ;;
esac

[ -n "$text" ] || exit 0

# Non-zero means nothing fired, so the hook stays silent.
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
  # A detected name with no verdict function contributes nothing and the
  # other names still emit theirs; the `|| exit 0` below is for a verdict
  # that exists and fails.
  fn="verdict_${name//-/_}"
  declare -F "$fn" >/dev/null || continue
  out=$("$fn" </dev/null) || exit 0
  para=${out%%"$nl"*}
  line=${out#*"$nl"}
  line=${line%%"$nl"*}
  human="${human:+$human }$line"

  # FR-6: a paragraph that would take additionalContext past 2048 bytes,
  # joining newline included, is dropped; its human line is already kept.
  # ${#var} counts characters under a UTF-8 locale and verdicts carry em
  # dashes, so the length is read under LC_ALL=C: bytes, with no fork. An
  # LC_ALL unset on entry is restored empty, which bash treats as unset.
  candidate="${context:+$context$nl}$para"
  lc_all_save=${LC_ALL-}
  LC_ALL=C
  candidate_bytes=${#candidate}
  LC_ALL=$lc_all_save
  [ "$candidate_bytes" -gt 2048 ] && continue
  context="$candidate"
done < <(printf '%s\n' "$names")

# A context the cap emptied still carries its human lines (FR-6).
[ -n "$context$human" ] || exit 0

json=$(jq -n --arg event "$event" --arg ctx "$context" --arg sys "$human" \
  '{hookSpecificOutput: {hookEventName: $event, additionalContext: $ctx}, systemMessage: $sys}') \
  || exit 0
printf '%s\n' "$json"
