#!/usr/bin/env bats
# The git-lock `gone` outcome through the hook: fire-lock-release-excluded.txt
# is a call `excludedCommands` ran unsandboxed, whose payload carries no flag,
# and whose lock was released before the probe ran. An absent lock reads gone
# under either flag, and the flag-absent verdict hedges the cause: a sandbox
# mask or a lock its holder has since released. Split from tests/hook-locks.bats.
#
# The fixture's recorded lock path is a real path on the machine that cut it,
# so the stub case never lets the real probe stat it; the real-probe case
# rewrites it, at run time, to an absent path under $BATS_TEST_TMPDIR.

# shellcheck disable=SC2030,SC2031 # $output set by run in a @test body is read by a helper
bats_require_minimum_version 1.5.0

load helpers/bsd-stubs
load helpers/git-env
load helpers/hook

setup() {
  hook_copy_tree
}

# run_hook <payload> — as tests/hook-locks.bats's, $status and $output.
run_hook() {
  run bash -c 'printf "%s" "$1" | bash "$2"' \
    _ "$1" "$HOOK_COPY/hooks/annotate.sh"
}

# assert_hedged_gone — $output is the hook's reply for a gone, flag-absent
# git-lock: the hedged paragraph and the new human line, no sandbox claim.
assert_hedged_gone() {
  local ctx sys
  ctx=$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')
  sys=$(printf '%s' "$output" | jq -r '.systemMessage')
  printf '%s' "$ctx" | grep -qF 'No lock exists now: this refusal came from a sandbox mask or from a lock its holder has since released.'
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  printf '%s' "$ctx" | grep -qF 'Retry the command with `dangerouslyDisableSandbox: true`.'
  printf '%s' "$ctx" | grep -qF 'GIT_INDEX_FILE'
  assert_lacks "$ctx" 'sandbox artefact'
  assert_lacks "$ctx" 'git cleaned it'
  [ "$sys" = 'index.lock — absent now, mask or released' ]
}

@test "release-excluded fixture, flag absent, gone: the hedged paragraph" {
  stub_probe git_lock gone
  local text
  text=$(cat "$FIXTURES/fire-lock-release-excluded.txt")

  run_hook "$(failure_payload "$text")"
  [ "$status" -eq 0 ]
  [ -f "$PROBE_CALLED" ]
  assert_hedged_gone
}

@test "release-excluded fixture, flag true, gone: git cleaned it" {
  stub_probe git_lock gone
  local text ctx sys
  text=$(cat "$FIXTURES/fire-lock-release-excluded.txt")

  run_hook "$(failure_payload "$text" true)"
  [ "$status" -eq 0 ]
  [ -f "$PROBE_CALLED" ]
  ctx=$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')
  sys=$(printf '%s' "$output" | jq -r '.systemMessage')
  printf '%s' "$ctx" | grep -qF 'No lock exists now; git cleaned it after the failure. Retry once.'
  [ "$sys" = 'index.lock — cleared after failure' ]
}

# The body of the real-probe case, shared with its BSD re-run. The recorded
# path is read from the fixture and swapped for an absent one under the test
# tmpdir; the swap is asserted, so a fixture without that path cannot pass on
# the host's own state.
real_probe_case() {
  local text recorded absent
  text=$(cat "$FIXTURES/fire-lock-release-excluded.txt")
  recorded=$(grep -o "'[^']*index\.lock'" "$FIXTURES/fire-lock-release-excluded.txt" \
    | head -n 1 | tr -d "'")
  [ -n "$recorded" ]
  absent="$BATS_TEST_TMPDIR/absent-repo/.git/index.lock"
  text=${text//"$recorded"/$absent}
  [[ $text == *"$absent"* ]]
  [ ! -e "$absent" ]

  run_hook "$(failure_payload "$text")"
  [ "$status" -eq 0 ]
  assert_hedged_gone
}

@test "release-excluded fixture, flag absent, real probe on an absent path" {
  real_probe_case
}

@test "release-excluded fixture, flag absent, real probe, with BSD grep, sed, stat and wc" {
  local bsd="$BATS_TEST_TMPDIR/bsdtools"
  make_bsd_stubs "$bsd" grep sed stat wc
  PATH="$bsd:$PATH" real_probe_case
}
