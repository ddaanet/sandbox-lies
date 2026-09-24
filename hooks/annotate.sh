#!/usr/bin/env bash
# The hook: payload -> text -> detect -> verdicts -> one JSON object.
# Registered on PostToolUse and PostToolUseFailure, matcher Bash
# (hooks/hooks.json). Any parse or runtime failure exits 0 with no output
# (FR-3). The text is the `error` string of a PostToolUseFailure payload, or
# tool_response.stdout, a newline, and tool_response.stderr of a PostToolUse
# payload (D-13).
#
# One jq call reads stdin and cannot error on any input, so nothing reaches
# stderr: `-Rs` takes it as one raw string and `fromjson?` decodes it,
# dropping what does not parse; `select(type == "object")` drops a scalar or
# array, which jq cannot index without a fatal error; only a string field is
# read as text. The output is the event, then the text, one per line. The
# event is printed only when it equals one of the two literal names, so the
# first newline is always the split point. NUL bytes are dropped in jq:
# bash drops them from a `$(...)` too, but warns on stderr.
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
  human="${human:+$human }$line"

  # FR-6's 2 KB cap: a paragraph that would push additionalContext past
  # 2048 BYTES is dropped; its human line is kept regardless (already
  # appended above). Verdict text carries multibyte characters (em dashes),
  # so ${#candidate} under the ambient locale would count characters, not
  # bytes -- LC_ALL=C makes bash treat the string as single-byte, so the
  # count is bytes. LC_ALL is one of bash's locale special variables:
  # assigning it re-runs setlocale() for the shell, but under bash 3.2 that
  # takes effect from the *next* simple command on, not within the one
  # doing the assignment -- so the assignment, the length read and the
  # restore are each their own statement, never combined on one line. This
  # counts bytes with no fork, unlike `wc -c`.
  candidate="${context:+$context$nl}$para"
  lc_all_save=${LC_ALL-}
  LC_ALL=C
  candidate_bytes=${#candidate}
  LC_ALL=$lc_all_save
  [ "$candidate_bytes" -gt 2048 ] && continue
  context="$candidate"
done < <(printf '%s\n' "$names")

[ -n "$context" ] || exit 0

json=$(jq -n --arg event "$event" --arg ctx "$context" --arg sys "$human" \
  '{hookSpecificOutput: {hookEventName: $event, additionalContext: $ctx}, systemMessage: $sys}') \
  || exit 0
printf '%s\n' "$json"
