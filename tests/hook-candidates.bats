#!/usr/bin/env bats
# Item 4.2's hook cases: the flag policy of the shipped candidate detectors
# (tmpdir-unset, resume-lost, seccomp-init) through the hook. First file to
# exist for candidate hook cases (runbook Phase 4 preamble), so it also
# carries the one BSD-portability case any such file owes.

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs
load helpers/hook

setup() {
  hook_copy_tree
}

# run_hook <payload> — invokes the copied annotate.sh, for `run` to capture
# $status and $output (stderr merged in, as hook.bats's run_hook does).
run_hook() {
  run bash -c 'printf "%s" "$1" | bash "$2"' \
    _ "$1" "$HOOK_COPY/hooks/annotate.sh"
}

# Each flag-policy case runs one fixture twice, differing only in the flag, so
# the silent half can only be the policy: the fires-with half shows the matcher
# and verdict fire on the same text.

@test "tmpdir-unset flag policy" {
  # Fires only when the flag is true.
  local text payload ctx sys
  text=$(cat "$FIXTURES/fire-tmpdir-unset-redirect.txt")

  payload=$(failure_payload "$text" true)
  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ -n "$output" ] \
    || { echo "no verdict emitted, flag true" >&2; return 1; }
  ctx=$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')
  printf '%s' "$ctx" | grep -qF '/tmp/claude/'
  sys=$(printf '%s' "$output" | jq -r '.systemMessage')
  # shellcheck disable=SC2016 # $TMPDIR is literal prose, not expansion
  [ "$sys" = '$TMPDIR — unset unsandboxed' ]

  payload=$(failure_payload "$text")
  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "resume-lost flag policy" {
  # Fires only when the flag is false.
  local text payload ctx sys
  text=$(cat "$FIXTURES/fire-resume-lost-two-turn.txt")

  payload=$(post_payload "$text")
  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ -n "$output" ] \
    || { echo "no verdict emitted, flag absent" >&2; return 1; }
  ctx=$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')
  printf '%s' "$ctx" | grep -qF 'one unsandboxed call'
  sys=$(printf '%s' "$output" | jq -r '.systemMessage')
  [ "$sys" = '--resume — transcript not persisted in sandbox' ]

  payload=$(post_payload "$text" "" true)
  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "seccomp-init flag policy" {
  # Silent when the flag is true.
  local text payload ctx sys
  text=$(cat "$FIXTURES/fire-seccomp-init-sed.txt")

  payload=$(failure_payload "$text")
  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ -n "$output" ] \
    || { echo "no verdict emitted, flag absent" >&2; return 1; }
  ctx=$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')
  printf '%s' "$ctx" | grep -qF 'Retry the identical command once'
  sys=$(printf '%s' "$output" | jq -r '.systemMessage')
  [ "$sys" = 'sandbox init failed — transient, retry' ]

  payload=$(failure_payload "$text" true)
  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "tmpdir-unset flag policy survives BSD grep and sed" {
  local text payload bsd ctx sys
  text=$(cat "$FIXTURES/fire-tmpdir-unset-redirect.txt")
  payload=$(failure_payload "$text" true)

  bsd="$BATS_TEST_TMPDIR/bsdtools"
  make_bsd_stubs "$bsd" grep sed
  PATH="$bsd:$PATH" run_hook "$payload"
  [ "$status" -eq 0 ]
  [ -n "$output" ] \
    || { echo "no verdict emitted under BSD stubs, flag true" >&2; return 1; }
  ctx=$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')
  printf '%s' "$ctx" | grep -qF '/tmp/claude/'
  sys=$(printf '%s' "$output" | jq -r '.systemMessage')
  # shellcheck disable=SC2016 # $TMPDIR is literal prose, not expansion
  [ "$sys" = '$TMPDIR — unset unsandboxed' ]
}
