#!/usr/bin/env bats
# The candidate detectors through the hook: the flag policy of the shipped
# verdict-only candidates (tmpdir-unset, resume-lost, seccomp-init, Item 4.2)
# and readonly-path's silence while it has no verdict (Item 4.3). First file
# to exist for candidate hook cases (runbook Phase 4 preamble), so it also
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
  [ "$sys" = '$TMPDIR — expanded empty, path collapsed to /' ]

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

@test "hook silent without a verdict" {
  # readonly-path fires (Item 4.3 slice 1) but has no verdict_readonly_path
  # yet (Item 6.1 ships it): the declare -F gate on the verdict must run
  # before the probe is even looked up (hooks/annotate.sh), so this probe is
  # never reached.
  stub_probe readonly_path writable
  local text payload
  text=$(cat "$FIXTURES/fire-readonly-path-cp-tmp.txt")
  payload=$(failure_payload "$text")
  # detect names readonly-path on this text, alone: the silence below cannot
  # come from nothing firing.
  run bash -c 'printf "%s\n" "$1" | bash "$2"' \
    _ "$text" "$HOOK_COPY/lib/matchers.sh"
  [ "$status" -eq 0 ]
  [ "$output" = readonly-path ]

  run_hook "$payload"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -f "$PROBE_CALLED" ]

  # The same payload with a stub verdict defined reaches the stub probe, so
  # the absence above is the missing verdict's doing.
  stub_lib verdicts.sh 'verdict_readonly_path() { cat >/dev/null; printf "stub paragraph\nstub line\n"; }'
  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ -f "$PROBE_CALLED" ]
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
  [ "$sys" = '$TMPDIR — expanded empty, path collapsed to /' ]
}
