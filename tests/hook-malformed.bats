#!/usr/bin/env bats
# Malformed and non-string-field payloads: annotate.sh must stay fully quiet
# (status 0, empty stdout, empty stderr) rather than leaking jq's parse or
# index errors onto stderr, or reading a non-string field as text (Item 2.3
# slice 6; plans/sandbox-lies/reports/item-2-3-s1-code-review.md finding 9,
# item-2-3-s2-code-review.md finding 2). Split from hook.bats to keep that
# file under the 400-line cap.
#
# Each test collects every miss across its inputs and asserts the list empty
# once at the end, so a red run names every broken input rather than the
# first, and a fix for one input cannot leave the others unseen.

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs
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

# assert_no_failures — the one assertion each test makes, printing every
# collected miss.
assert_no_failures() {
  [ -z "$failures" ] || { printf '%s' "$failures" >&2; return 1; }
}

@test "non-json, scalar, array and textless object" {
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
