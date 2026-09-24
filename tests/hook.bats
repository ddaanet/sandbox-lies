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
load helpers/spy

setup() {
  hook_copy_tree
}

# run_hook <payload> — invokes annotate.sh on the copied tree, setting
# $status and $output via bats' run. Used by the slice 4-5 sweeps below,
# which each call the hook many times over a fixture set.
run_hook() {
  run bash -c 'printf "%s" "$1" | bash "$2"' \
    _ "$1" "$HOOK_COPY/hooks/annotate.sh"
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

@test "porcelain on stdout fires untracked" {
  # Pairs "listing on stderr fires" below: same text, only the
  # tool_response field differs, so a hook that never reads
  # tool_response.stdout on success fails here.
  local text payload
  text=$(cat "$FIXTURES/fire-masks-porcelain.txt")
  payload=$(post_payload "$text")
  run bash -c 'printf "%s" "$1" | bash "$2"' \
    _ "$payload" "$HOOK_COPY/hooks/annotate.sh"
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -r '.hookSpecificOutput.hookEventName')" \
    = "PostToolUse" ]
  printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext' \
    | grep -qF 'reading the sandbox, not the tree'
}

@test "listing on stderr fires" {
  # Paired with the stdout case above: the porcelain text moves to
  # tool_response.stderr and stdout is empty, so a hook that reads only
  # tool_response.stdout on success fails here.
  local text payload
  text=$(cat "$FIXTURES/fire-masks-porcelain.txt")
  payload=$(post_payload "" "$text")
  run bash -c 'printf "%s" "$1" | bash "$2"' \
    _ "$payload" "$HOOK_COPY/hooks/annotate.sh"
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -r '.hookSpecificOutput.hookEventName')" \
    = "PostToolUse" ]
  printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext' \
    | grep -qF 'reading the sandbox, not the tree'
}

@test "rebuild inserts a newline between stdout and stderr" {
  # A rebuild that concatenates stdout and stderr with no separator merges
  # the last stdout line with the first stderr line. Here each field holds
  # one masked name with no trailing newline, as recorded payloads carry
  # them, so the two-name phantom-untracked threshold is only met when a
  # newline is inserted between them; a concatenation with no separator
  # merges them into one line that matches neither, and a rebuild reading
  # one field sees one name. Either way the hook goes quiet. The names sit
  # inside a quoted assignment, not alone on their own source line, so this
  # file stays quiet under its own detector (FR-11).
  local stdout stderr payload
  stdout='?? .bashrc'
  stderr='?? .gitconfig'
  payload=$(post_payload "$stdout" "$stderr")
  run bash -c 'printf "%s" "$1" | bash "$2"' \
    _ "$payload" "$HOOK_COPY/hooks/annotate.sh"
  [ "$status" -eq 0 ]
  printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext' \
    | grep -qF 'reading the sandbox, not the tree'
}

@test "chardev listing alone keeps its own paragraph" {
  # The positive half of the shared-paragraph case below, over the same
  # chardev listing without the porcelain one. A hook that drops
  # phantom-chardev always, rather than only when phantom-untracked also
  # fires, passes the shared case and fails here.
  local text payload expected_ctx expected_sys
  text=$(cat "$FIXTURES/fire-masks-chardev-explicit.txt")
  payload=$(post_payload "$text")
  run bash -c 'printf "%s" "$1" | bash "$2"' \
    _ "$payload" "$HOOK_COPY/hooks/annotate.sh"
  [ "$status" -eq 0 ]

  expected_ctx=$(bash -c '. "$1"; verdict_phantom_chardev' \
    _ "$HOOK_COPY/lib/verdicts.sh" </dev/null | sed -n '1p')
  expected_sys=$(bash -c '. "$1"; verdict_phantom_chardev' \
    _ "$HOOK_COPY/lib/verdicts.sh" </dev/null | sed -n '2p')
  # Empty expectations would match a hook that printed nothing.
  [ -n "$expected_ctx" ]
  [ -n "$expected_sys" ]

  [ "$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')" \
    = "$expected_ctx" ]
  [ "$(printf '%s' "$output" | jq -r '.systemMessage')" = "$expected_sys" ]
}

@test "both listing verdicts share one paragraph" {
  # Item 2.3 says only verdict_phantom_untracked runs when both listing
  # detectors fire, since its paragraph already restates the chardev one —
  # so this asserts against verdict_phantom_untracked's own output, not a
  # substring, because that paragraph contains the chardev text too. The
  # text is the two listings one after the other, as one call running both
  # commands prints them.
  local chardev porcelain text payload expected_ctx expected_sys
  chardev=$(cat "$FIXTURES/fire-masks-chardev-explicit.txt")
  porcelain=$(cat "$FIXTURES/fire-masks-porcelain.txt")
  text=$(printf '%s\n%s' "$chardev" "$porcelain")
  # Both matchers fire on this text, or a hook emitting only the untracked
  # paragraph had no chardev one to leave out. Asked of the matchers rather
  # than of detect, whose output is one place the merge may be implemented.
  printf '%s\n' "$text" | bash -c '. "$1"; match_phantom_chardev' \
    _ "$HOOK_COPY/lib/matchers.sh"
  printf '%s\n' "$text" | bash -c '. "$1"; match_phantom_untracked' \
    _ "$HOOK_COPY/lib/matchers.sh"

  payload=$(post_payload "$text")
  run bash -c 'printf "%s" "$1" | bash "$2"' \
    _ "$payload" "$HOOK_COPY/hooks/annotate.sh"
  [ "$status" -eq 0 ]

  expected_ctx=$(bash -c '. "$1"; verdict_phantom_untracked' \
    _ "$HOOK_COPY/lib/verdicts.sh" </dev/null | sed -n '1p')
  expected_sys=$(bash -c '. "$1"; verdict_phantom_untracked' \
    _ "$HOOK_COPY/lib/verdicts.sh" </dev/null | sed -n '2p')
  # Empty expectations would match a hook that printed nothing.
  [ -n "$expected_ctx" ]
  [ -n "$expected_sys" ]

  [ "$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')" \
    = "$expected_ctx" ]
  [ "$(printf '%s' "$output" | jq -r '.systemMessage')" = "$expected_sys" ]
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

@test "phantom verdicts ignore the flag" {
  # `fire-masks-*.txt` is exactly the fixture set that fires a phantom
  # detector: running `detect` over every file under tests/fixtures/ (see
  # the RED report) shows chardev-explicit and chardev-incidental fire
  # phantom-chardev, gitadd-refused fires phantom-gitadd, and porcelain and
  # two-names fire phantom-untracked. The non-empty check below is what
  # catches a fixture that stops firing: the sweep must not silently shrink
  # to fewer live cases.
  local f text payload absent count=0
  for f in "$FIXTURES"/fire-masks-*.txt; do
    count=$((count + 1))
    text=$(cat "$f")

    case "$text" in
      "Exit code"*) payload=$(failure_payload "$text") ;;
      *)            payload=$(post_payload "$text") ;;
    esac
    run_hook "$payload"
    [ "$status" -eq 0 ]
    absent="$output"
    [ -n "$absent" ] || { echo "no output, flag absent: $f" >&2; return 1; }

    case "$text" in
      "Exit code"*) payload=$(failure_payload "$text" false) ;;
      *)            payload=$(post_payload "$text" "" false) ;;
    esac
    run_hook "$payload"
    [ "$status" -eq 0 ]
    [ "$output" = "$absent" ] \
      || { echo "flag false differs from absent: $f" >&2; return 1; }

    case "$text" in
      "Exit code"*) payload=$(failure_payload "$text" true) ;;
      *)            payload=$(post_payload "$text" "" true) ;;
    esac
    run_hook "$payload"
    [ "$status" -eq 0 ]
    [ "$output" = "$absent" ] \
      || { echo "flag true differs from absent: $f" >&2; return 1; }
  done
  [ "$count" -gt 0 ]
}

@test "every quiet fixture is silent" {
  # A live failure payload's `error` always opens with its exit-code line
  # (detectors.md Conventions), so the failure shape gets one unless the
  # fixture already starts with it; without it, a hook that fires on that
  # line would pass this sweep.
  local f text failure payload count=0
  for f in "$FIXTURES"/quiet-*.txt; do
    count=$((count + 1))
    text=$(cat "$f")
    case "$text" in
      "Exit code"*) failure="$text" ;;
      *)            failure="Exit code 1"$'\n'"$text" ;;
    esac

    payload=$(post_payload "$text")
    run_hook "$payload"
    [ "$status" -eq 0 ]
    [ -z "$output" ] || { echo "fired (post, absent): $f" >&2; return 1; }

    payload=$(post_payload "$text" "" true)
    run_hook "$payload"
    [ "$status" -eq 0 ]
    [ -z "$output" ] || { echo "fired (post, true): $f" >&2; return 1; }

    payload=$(failure_payload "$failure")
    run_hook "$payload"
    [ "$status" -eq 0 ]
    [ -z "$output" ] || { echo "fired (failure, absent): $f" >&2; return 1; }

    payload=$(failure_payload "$failure" true)
    run_hook "$payload"
    [ "$status" -eq 0 ]
    [ -z "$output" ] || { echo "fired (failure, true): $f" >&2; return 1; }
  done
  [ "$count" -gt 0 ]
}

@test "hook needs no temp dir" {
  # Slice 1's gitadd failure payload, unaltered -- same shape as "gitadd
  # failure payload yields one verdict" above. TMPDIR names a directory that
  # does not exist rather than an empty one to inspect afterwards: a mktemp
  # buffer removes itself once detect returns, so an empty-directory check
  # would pass against it. The mktemp spy catches a buffer that falls back to
  # /tmp (residual as in "detect needs no temp dir", matchers.bats). expected
  # is computed in this same run so the comparison is exact rather than
  # merely nonempty. Both runs merge stderr into $output, and expected parses
  # as one JSON document, so the equality also pins an empty stderr.
  local text payload payload_file nonexistent expected
  local spy="$BATS_TEST_TMPDIR/spy" calls="$BATS_TEST_TMPDIR/spy-calls"
  text=$(cat "$FIXTURES/fire-masks-gitadd-refused.txt")
  payload=$(failure_payload "$text")
  payload_file="$BATS_TEST_TMPDIR/hook-needs-no-temp-dir.json"
  printf '%s' "$payload" >"$payload_file"

  run bash "$HOOK_COPY/hooks/annotate.sh" <"$payload_file"
  [ "$status" -eq 0 ]
  expected="$output"
  [ -n "$expected" ]
  printf '%s' "$expected" | jq -e . >/dev/null

  nonexistent="$BATS_TEST_TMPDIR/does-not-exist"
  make_spy "$spy" "$calls" mktemp
  run env PATH="$spy:$PATH" TMPDIR="$nonexistent" \
    bash "$HOOK_COPY/hooks/annotate.sh" <"$payload_file"
  [ "$status" -eq 0 ]
  [ "$output" = "$expected" ]
  [ ! -e "$calls" ] || { cat "$calls" >&2; return 1; }
}

@test "the command is not read" {
  # Paired positive first, per shape: the same firing text in the response
  # field must still fire, so neither negative can pass on a hook that has
  # stopped firing on that event.
  local fire quiet payload

  fire=$(cat "$FIXTURES/fire-masks-porcelain.txt")
  quiet=$(cat "$FIXTURES/quiet-clean-status.txt")

  payload=$(post_payload "$fire")
  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ -n "$output" ] \
    || { echo "positive control did not fire (post)" >&2; return 1; }

  payload=$(failure_payload "Exit code 1"$'\n'"$fire")
  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ -n "$output" ] \
    || { echo "positive control did not fire (failure)" >&2; return 1; }

  payload=$(post_payload "$quiet" \
    | jq --arg c "$fire" '.tool_input.command = $c')
  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ -z "$output" ] \
    || { echo "fired via tool_input.command (post)" >&2; return 1; }

  payload=$(failure_payload "Exit code 1"$'\n'"$quiet" \
    | jq --arg c "$fire" '.tool_input.command = $c')
  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ -z "$output" ] \
    || { echo "fired via tool_input.command (failure)" >&2; return 1; }
}
