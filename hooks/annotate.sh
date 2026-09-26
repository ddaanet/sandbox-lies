#!/usr/bin/env bash
# The hook: payload -> text -> detect -> probes -> verdicts -> one JSON
# object. Registered on PostToolUse and PostToolUseFailure, matcher Bash
# (hooks/hooks.json). Any parse or runtime failure exits 0 with no output
# (FR-3). The text is the `error` string of a PostToolUseFailure payload, or
# whichever of tool_response.stdout and tool_response.stderr are strings,
# joined by a newline, of a PostToolUse payload (D-13).
#
# One jq call reads stdin and cannot error on any input, so nothing reaches
# stderr: `-Rs` takes it as one raw string and `fromjson?` decodes it,
# dropping what does not parse; `select(type == "object")` drops a scalar or
# array, which jq cannot index without a fatal error; only a string field is
# read as text. The output is the event, the sandbox flag, the payload cwd,
# then each text part, each ending in a newline, which is the join. The
# event is printed only when it equals one of the two literal names, the flag
# is `true` or `false`, and the cwd has each backslash doubled and each
# newline written `\n` (undone by `printf %b`), so the first three newlines
# are always the split points for event/flag/cwd. NUL bytes are dropped in
# jq: bash drops them from a `$(...)` too, but warns on stderr.
#
# Writes nothing (NFR-4): no here-document, which bash before 5.1 spools
# through a temp file.
set -u

script_dir=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd) || exit 0
lib_dir="$script_dir/../lib"
# shellcheck disable=SC1091 # lib/ sits beside this script; path is dynamic
. "$lib_dir/matchers.sh" || exit 0
# shellcheck disable=SC1091 # lib/ sits beside this script; path is dynamic
. "$lib_dir/probes.sh" || exit 0
# shellcheck disable=SC1091 # lib/ sits beside this script; path is dynamic
. "$lib_dir/verdicts.sh" || exit 0

nl='
'

# FR-5: dangerouslyDisableSandbox reads as "true" only when literally true;
# absent, any other value, or a tool_input that is not an object reads as
# "false". `objects` keeps jq from indexing a scalar, and `// false` turns the
# empty it leaves into false rather than dropping the whole payload.
parsed=$(jq -Rrs '
    fromjson? | select(type == "object") |
    .hook_event_name as $event |
    (if ((.tool_input | objects | .dangerouslyDisableSandbox) // false) == true
     then "true" else "false" end) as $flag |
    ((.cwd | strings) // "" |
     split("\\") | join("\\\\") | split("\n") | join("\\n")) as $cwd |
    if $event == "PostToolUseFailure" then
      $event, $flag, $cwd, (.error | strings)
    elif $event == "PostToolUse" then
      $event, $flag, $cwd,
      (.tool_response | objects | (.stdout | strings), (.stderr | strings))
    else empty end |
    split("\u0000") | join("")
  ') || exit 0

event="" flag=false cwd="" text=""
case "$parsed" in
  *"$nl"*"$nl"*"$nl"*)
    event=${parsed%%"$nl"*}
    rest=${parsed#*"$nl"}
    flag=${rest%%"$nl"*}
    rest=${rest#*"$nl"}
    printf -v cwd '%b' "${rest%%"$nl"*}"
    text=${rest#*"$nl"}
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
  # detectors.md's candidate flag policies (FR-5): gating lives here, never
  # in the matcher. tmpdir-unset fires only when the flag is true; resume-lost,
  # seccomp-init and readonly-path are silent when it is.
  case "$name:$flag" in
    tmpdir-unset:false | resume-lost:true | seccomp-init:true | \
      readonly-path:true) continue ;;
  esac
  # A detected name with no verdict function contributes nothing and the
  # other names still emit theirs; the `|| exit 0` below is for a verdict
  # that exists and fails.
  fn="verdict_${name//-/_}"
  declare -F "$fn" >/dev/null || continue

  # FR-4: a name whose probe is also defined runs it first, outside the
  # sandbox, with the result text on stdin and the flag and cwd as its
  # arguments; the probe's first line becomes the verdict's outcome argument,
  # any lines after it become the verdict's stdin, and the flag becomes its
  # second argument (D-17), which a verdict not worded by the flag ignores.
  probe_fn="probe_${name//-/_}"
  if declare -F "$probe_fn" >/dev/null; then
    probe_out=$(printf '%s\n' "$text" | "$probe_fn" "$flag" "$cwd") || exit 0
    case "$probe_out" in
      *"$nl"*)
        outcome=${probe_out%%"$nl"*}
        probe_rest=${probe_out#*"$nl"}
        ;;
      *)
        outcome=$probe_out
        probe_rest=""
        ;;
    esac
    out=$(printf '%s\n' "$probe_rest" | "$fn" "$outcome" "$flag") || exit 0
  else
    out=$("$fn" </dev/null) || exit 0
  fi
  # An outcome the verdict has no text for, an empty one included, prints
  # nothing and contributes nothing: no empty paragraph or human line.
  [ -n "$out" ] || continue
  para=${out%%"$nl"*}
  line=${out#*"$nl"}
  line=${line%%"$nl"*}
  # `; ` between human lines: each is a clause, and a bare space ran them
  # together into one unreadable line.
  human="${human:+$human; }$line"

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
