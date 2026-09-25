#!/usr/bin/env bats
# Item 4.1's hook cases: git-lock and config-lock verdicts through the hook.
# Split from tests/hook.bats (at 378 of 400 lines) rather than added there.
#
# Every case here stubs the probe: fire-lock-add-commit.txt names an absolute
# path on the machine that recorded it, and the fixture's path must never
# reach the host filesystem — the stub, not the real probe, answers.

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

# stub_probe <name> <outcome> — overrides probe_<name> in the copied
# lib/probes.sh with one that drains stdin, prints <outcome>, and touches
# $PROBE_CALLED. A case asserts that file exists: the real probe_git_lock on
# this fixture's lock path also answers mask when the path is absent, so a
# stub the hook never reached would otherwise pass while the real probe
# stats the host path, and so would a verdict defaulting to mask with no
# probe call at all.
stub_probe() {
  local name="$1" outcome="$2" called
  PROBE_CALLED="$BATS_TEST_TMPDIR/probe-$name-called"
  called=$(printf '%q' "$PROBE_CALLED")
  stub_lib probes.sh "probe_${name}() { cat >/dev/null; : >${called}; printf '%s\\npath=stub\\n' '${outcome}'; }"
}

@test "mask outcome through the hook" {
  stub_probe git_lock mask
  local text payload ctx sys
  text=$(cat "$FIXTURES/fire-lock-add-commit.txt")
  payload=$(failure_payload "$text")

  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ -f "$PROBE_CALLED" ]
  ctx=$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')
  sys=$(printf '%s' "$output" | jq -r '.systemMessage')
  printf '%s' "$ctx" | grep -qF 'Re-run the same command with'
  printf '%s' "$ctx" | grep -qF 'GIT_INDEX_FILE'
  [ "$sys" = 'index.lock — sandbox mask, not a real lock' ]
}

@test "mask paragraph is flag-neutral under flag true" {
  # A character device under flag true is still mask (a mask visible outside
  # the sandbox where re-running unsandboxed is a no-op); the wording holds
  # rather than taking the flag as an argument (lock-detectors.md's git-lock
  # Flag policy paragraph). Pinned as: flag true yields the same context and
  # human line as flag false, and that context carries the clause for the
  # flag-true case.
  stub_probe git_lock mask
  local text ctx_false sys_false ctx_true sys_true
  text=$(cat "$FIXTURES/fire-lock-add-commit.txt")

  run_hook "$(failure_payload "$text" false)"
  [ "$status" -eq 0 ]
  ctx_false=$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')
  sys_false=$(printf '%s' "$output" | jq -r '.systemMessage')

  rm -f "$PROBE_CALLED"
  run_hook "$(failure_payload "$text" true)"
  [ "$status" -eq 0 ]
  [ -f "$PROBE_CALLED" ]
  ctx_true=$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')
  sys_true=$(printf '%s' "$output" | jq -r '.systemMessage')

  printf '%s' "$ctx_true" | grep -qF 'once no sandboxed command is running'
  [ "$ctx_true" = "$ctx_false" ]
  [ "$sys_true" = "$sys_false" ]
}

@test "mask outcome through the hook under BSD stubs" {
  stub_probe git_lock mask
  local text payload bsd sys
  text=$(cat "$FIXTURES/fire-lock-add-commit.txt")
  payload=$(failure_payload "$text")

  bsd="$BATS_TEST_TMPDIR/bsdtools"
  make_bsd_stubs "$bsd" grep sed
  PATH="$bsd:$PATH" run_hook "$payload"
  [ "$status" -eq 0 ]
  [ -f "$PROBE_CALLED" ]
  sys=$(printf '%s' "$output" | jq -r '.systemMessage')
  [ "$sys" = 'index.lock — sandbox mask, not a real lock' ]
}
