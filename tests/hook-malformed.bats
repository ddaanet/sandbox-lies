#!/usr/bin/env bats
# Malformed and non-string-field payloads: annotate.sh must stay fully quiet
# (status 0, empty stdout, empty stderr) rather than leaking jq's parse or
# index errors onto stderr, or reading a non-string field as text (Item 2.3
# slice 6; plans/sandbox-lies/reports/item-2-3-s1-code-review.md finding 9,
# item-2-3-s2-code-review.md finding 2). Split from hook.bats.
#
# Each test collects every miss across its inputs and asserts the list empty
# once at the end, so a red run names every broken input rather than the
# first, and a fix for one input cannot leave the others unseen.

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs
load helpers/git-env
load helpers/hook

setup() {
  hook_copy_tree
  failures=""
}

# quiet_hook <payload> — pipes <payload> into the copied annotate.sh, for
# `run --separate-stderr` to capture stdout and stderr apart.
quiet_hook() {
  printf '%s' "$1" | bash "$HOOK_COPY/hooks/annotate.sh"
}

# check_quiet <label> <payload> — runs annotate.sh on the copied tree and
# appends a line to $failures for each of status 0, empty stdout and empty
# stderr that <payload> misses. Never fails itself, so every input runs.
check_quiet() {
  local label="$1" payload="$2"
  run --separate-stderr quiet_hook "$payload"
  [ "$status" -eq 0 ] || failures+="$label: status $status"$'\n'
  [ -z "$output" ] || failures+="$label: stdout [$output]"$'\n'
  [ -z "$stderr" ] || failures+="$label: stderr [$stderr]"$'\n'
}

# check_fires <label> <payload> — the paired positive, through the same
# invocation: a well-formed payload carrying the same text must yield status
# 0, non-empty stdout and empty stderr, so a hook that exits early on
# everything cannot pass.
check_fires() {
  local label="$1" payload="$2"
  run --separate-stderr quiet_hook "$payload"
  [ "$status" -eq 0 ] && [ -n "$output" ] && [ -z "$stderr" ] \
    || failures+="$label: positive did not fire: status $status, stderr [$stderr]"$'\n'
}

# check_reached <label> <marker> — appends a line to $failures when the stub
# marker file is absent, so a stub the hook never reached cannot pass.
check_reached() {
  [ -e "$2" ] || failures+="$1: stub was never reached"$'\n'
}

# assert_no_failures — the one assertion each test makes, printing every
# collected miss.
assert_no_failures() {
  [ -z "$failures" ] || { printf '%s' "$failures" >&2; return 1; }
}

# The body of "non-json, scalar, array and textless object", shared with its
# BSD re-run below.
malformed_inputs_case() {
  local gitadd porcelain
  gitadd=$(cat "$FIXTURES/fire-masks-gitadd-refused.txt")
  porcelain=$(cat "$FIXTURES/fire-masks-porcelain.txt")
  check_fires "failure payload" "$(failure_payload "$gitadd")"
  check_fires "success payload" "$(post_payload "$porcelain")"

  check_quiet "not json" 'not json'
  check_quiet "scalar" '42'
  check_quiet "array" '[1]'
  # `{}` stops at the missing event; the two textless payloads below carry
  # a valid event and reach the text read with nothing in the text field.
  check_quiet "textless object" '{}'
  check_quiet "failure payload without error" \
    "$(jq 'del(.error)' "$FIXTURES/payload-failure.json")"
  check_quiet "success payload without tool_response" \
    "$(jq 'del(.tool_response)' "$FIXTURES/payload-post.json")"
  # The string holds the positive's firing text, so a hook that reads a
  # string tool_response as the text fails here too, not only one that
  # leaks jq's index error.
  check_quiet "tool_response is a string" \
    "$(jq --arg t "$porcelain" '.tool_response = $t' \
      "$FIXTURES/payload-post.json")"

  assert_no_failures
}

@test "non-json, scalar, array and textless object" {
  malformed_inputs_case
}

@test "non-json, scalar, array and textless object, with BSD tools" {
  local bsd="$BATS_TEST_TMPDIR/bsdtools"
  make_bsd_stubs "$bsd" sed grep
  PATH="$bsd:$PATH" malformed_inputs_case
}

# The phantom matchers are line-anchored, and jq renders an object or array
# with every line indented or bracketed, so no phantom text inside one can
# fire (item-2-3-s2-code-review.md, probe). git-lock is unanchored, so its
# text inside a non-string field fires wherever that field is read as text:
# the stub gives it a verdict (Item 4.1 ships the real one), and each
# negative differs from its positive only in the field's type.
@test "non-string tool_response.stdout and error fields stay quiet" {
  local lock
  lock=$(cat "$FIXTURES/fire-lock-add-commit.txt")
  stub_lib verdicts.sh \
    'verdict_git_lock() { printf "%s\n" "stub lock paragraph" "stub — lock"; }'
  check_fires "error is a string" "$(failure_payload "$lock")"
  check_fires "tool_response.stdout is a string" "$(post_payload "$lock")"

  check_quiet "tool_response.stdout is a number" \
    "$(jq '.tool_response.stdout = 5' "$FIXTURES/payload-post.json")"
  check_quiet "tool_response.stdout is an object" \
    "$(jq --arg t "$lock" '.tool_response.stdout = {text: $t}' \
      "$FIXTURES/payload-post.json")"
  check_quiet "error is a number" \
    "$(jq '.error = 42' "$FIXTURES/payload-failure.json")"
  check_quiet "error is an object" \
    "$(jq --arg t "$lock" '.error = {text: $t}' \
      "$FIXTURES/payload-failure.json")"
  check_quiet "error is an array" \
    "$(jq --arg t "$lock" '.error = [$t]' "$FIXTURES/payload-failure.json")"

  assert_no_failures
}

@test "NUL in the text stays quiet on stderr" {
  # F1 (item-2-3-s6-code-review.md): a well-formed payload whose
  # tool_response.stdout holds \u0000 -- printed by e.g. `git ls-files -z` or
  # `find -print0` run bare -- must not leak bash's NUL-drop warning onto
  # stderr. Only bash >= 4.4 warns, so only there can this case red; under
  # bash 3.2 the drop is silent and it checks just that the NUL does not stop
  # the verdict. The NUL sits in the jq filter's own string literal, ahead of
  # the firing text: a shell variable cannot hold the byte to splice it in
  # via --arg.
  local porcelain payload
  porcelain=$(cat "$FIXTURES/fire-masks-porcelain.txt")
  payload=$(jq --arg t "$porcelain" \
    '.tool_response.stdout = ("\u0000" + $t)' "$FIXTURES/payload-post.json")
  check_fires "NUL then firing text" "$payload"

  assert_no_failures
}

@test "event name is one of two literals" {
  # F2 (item-2-3-s6-code-review.md): hook_event_name must equal one of the
  # two literal event names exactly, or nothing downstream reads the payload
  # as text. The paired positive puts firing text in tool_response.stdout
  # under the literal event. A string holding a newline before that text
  # must not split into an event line and text; an object event must stay
  # quiet on the positive's own payload, the event alone changed -- firing
  # text inside the object would pretty-print JSON-escaped, on lines no
  # line-anchored matcher reads, and stay quiet whatever the hook did.
  local porcelain literal_event newline_event object_event
  porcelain=$(cat "$FIXTURES/fire-masks-porcelain.txt")

  literal_event=$(jq --arg t "$porcelain" \
    '.tool_response.stdout = $t' "$FIXTURES/payload-post.json")
  check_fires "literal event, firing stdout" "$literal_event"

  newline_event=$(jq --arg t "$porcelain" \
    '.hook_event_name = ("PostToolUse\n" + $t)' "$FIXTURES/payload-post.json")
  check_quiet "newline then firing text" "$newline_event"

  object_event=$(printf '%s' "$literal_event" \
    | jq '.hook_event_name = {name: "PostToolUse"}')
  check_quiet "event is an object" "$object_event"

  assert_no_failures
}

# FR-3, runtime-failure path: a probe or verdict that has already printed and
# then returns non-zero must leave the hook wholly quiet, not emit the
# partial output it printed. Each case stubs the same function twice: first
# returning 0, for the paired check_fires, then returning 1, for check_quiet,
# since a later definition wins (stub_lib). Without the pair a hook that
# exits early on everything would pass.
@test "probe dying after output stays quiet" {
  local text called q
  text=$(cat "$FIXTURES/fire-readonly-path-cp-tmp.txt")
  called="$BATS_TEST_TMPDIR/probe-readonly-called"
  q=$(printf '%q' "$called")
  stub_lib probes.sh "probe_readonly_path() { cat >/dev/null; : >$q; printf '%s\n' writable path=/r/x; return 0; }"
  check_fires "probe returning 0" "$(failure_payload "$text")"
  rm -f "$called"

  stub_lib probes.sh "probe_readonly_path() { cat >/dev/null; : >$q; printf '%s\n' writable path=/r/x; return 1; }"
  check_quiet "probe returning 1 after output" "$(failure_payload "$text")"
  check_reached "probe" "$called"

  assert_no_failures
}

@test "verdict dying after a probe stays quiet" {
  local text
  text=$(cat "$FIXTURES/fire-lock-add-commit.txt")
  stub_probe git_lock mask
  stub_lib verdicts.sh \
    'verdict_git_lock() { cat >/dev/null; printf "%s\n" "stub lock paragraph" "stub — lock"; return 0; }'
  check_fires "verdict returning 0" "$(failure_payload "$text")"
  check_reached "paired probe" "$PROBE_CALLED"
  rm -f "$PROBE_CALLED"

  stub_lib verdicts.sh \
    'verdict_git_lock() { cat >/dev/null; printf "%s\n" "stub lock paragraph" "stub — lock"; return 1; }'
  check_quiet "verdict returning 1 after output" "$(failure_payload "$text")"
  check_reached "probe" "$PROBE_CALLED"

  assert_no_failures
}

@test "probe-less verdict dying stays quiet" {
  local text
  text=$(cat "$FIXTURES/fire-masks-gitadd-refused.txt")
  stub_lib verdicts.sh \
    'verdict_phantom_gitadd() { printf "%s\n" "stub paragraph" "stub human line"; return 0; }'
  check_fires "verdict returning 0" "$(failure_payload "$text")"

  stub_lib verdicts.sh \
    'verdict_phantom_gitadd() { printf "%s\n" "stub paragraph" "stub human line"; return 1; }'
  check_quiet "verdict returning 1 after output" "$(failure_payload "$text")"

  assert_no_failures
}
