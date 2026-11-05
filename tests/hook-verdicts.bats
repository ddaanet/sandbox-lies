#!/usr/bin/env bats
# A detected name with no verdict function contributes nothing to the
# output; the other detected names still emit theirs (Item 2.3 paragraph:
# "calls verdict_<name> for each name that has one -- a name with no verdict
# function contributes nothing"). Split from hook.bats
# (Item 2.3 slice 9).
#
# item-2-3-s1-code-review.md finding 1 found the opposite: today a missing
# verdict function makes the whole hook exit 0 silently, so a mixed set
# (a real name alongside a verdict-less one) emits nothing at all, not the
# real name's paragraph.
#
# The test collects every miss across its variants and asserts the list
# empty once at the end, as hook-malformed.bats does, so a red run names
# every broken order rather than the first.

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs
load helpers/git-env
load helpers/hook

setup() {
  hook_copy_tree
  failures=""
}

# verdicts_hook <payload> — pipes <payload> into the copied annotate.sh, for
# `run --separate-stderr` to capture stdout and stderr apart.
verdicts_hook() {
  printf '%s' "$1" | bash "$HOOK_COPY/hooks/annotate.sh"
}

# check_emits <label> <payload> <ctx> <sys> — runs the copied hook on
# <payload> and appends a line to $failures for each of status 0, empty
# stderr, additionalContext <ctx> and systemMessage <sys> that the run
# misses. Never fails itself, so every variant runs.
check_emits() {
  local label="$1" payload="$2" ctx="$3" sys="$4" got
  run --separate-stderr verdicts_hook "$payload"
  [ "$status" -eq 0 ] || failures+="$label: status $status"$'\n'
  [ -z "$stderr" ] || failures+="$label: stderr [$stderr]"$'\n'
  got=$(printf '%s' "$output" \
    | jq -r '.hookSpecificOutput.additionalContext' 2>&1)
  [ "$got" = "$ctx" ] || failures+="$label: additionalContext [$got]"$'\n'
  got=$(printf '%s' "$output" | jq -r '.systemMessage' 2>&1)
  [ "$got" = "$sys" ] || failures+="$label: systemMessage [$got]"$'\n'
}

# check_quiet <label> <payload> — the same run, appending a line for each of
# status 0, empty stdout and empty stderr that it misses.
check_quiet() {
  local label="$1" payload="$2"
  run --separate-stderr verdicts_hook "$payload"
  [ "$status" -eq 0 ] || failures+="$label: status $status"$'\n'
  [ -z "$output" ] || failures+="$label: stdout [$output]"$'\n'
  [ -z "$stderr" ] || failures+="$label: stderr [$stderr]"$'\n'
}

# assert_no_failures — the one assertion the test makes, printing every
# collected miss.
assert_no_failures() {
  [ -z "$failures" ] || { printf '%s' "$failures" >&2; return 1; }
}

@test "a name with no verdict contributes nothing" {
  local text payload expected_ctx expected_sys

  # The payload's own text fires phantom-gitadd, so a stub that failed to
  # replace detect would leave the alone case below emitting it.
  text=$(cat "$FIXTURES/fire-masks-gitadd-refused.txt")
  payload=$(post_payload "$text")

  expected_ctx=$(bash -c '. "$1"; verdict_phantom_gitadd' \
    _ "$HOOK_COPY/lib/verdicts.sh" </dev/null | sed -n '1p')
  expected_sys=$(bash -c '. "$1"; verdict_phantom_gitadd' \
    _ "$HOOK_COPY/lib/verdicts.sh" </dev/null | sed -n '2p')
  # Empty expectations would match a hook that printed nothing.
  [ -n "$expected_ctx" ]
  [ -n "$expected_sys" ]

  # Verdict-less name last: the name that has a verdict still emits it, and
  # only it, in additionalContext and systemMessage.
  stub_lib matchers.sh \
    'detect() { printf "phantom-gitadd\nno-such-detector\n"; }'
  check_emits "verdict-less name last" \
    "$payload" "$expected_ctx" "$expected_sys"

  # Verdict-less name first: rules out an implementation that stops (exits
  # or breaks the loop) on the first missing verdict, or that skips the
  # name after it, since either would never reach phantom-gitadd.
  stub_lib matchers.sh \
    'detect() { printf "no-such-detector\nphantom-gitadd\n"; }'
  check_emits "verdict-less name first" \
    "$payload" "$expected_ctx" "$expected_sys"

  # Verdict-less name alone: nothing to contribute, so the hook stays quiet.
  stub_lib matchers.sh 'detect() { printf "no-such-detector\n"; }'
  check_quiet "verdict-less name alone" "$payload"

  assert_no_failures
}
