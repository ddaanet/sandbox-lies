#!/usr/bin/env bats
# resume-lost through the hook with the real probe_resume_lost (Item 1.1):
# the wiring, the no-transcript and transcript-exists verdicts, the
# no-transcript verdict's BSD re-run, and the absence of any flag policy: the
# probe decides under either value of dangerouslyDisableSandbox. The probe's
# own cases are in tests/probes-resume.bats.

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

# The resume-lost cases below run the real probe over a config dir under
# $BATS_TEST_TMPDIR; the two ids are those of fire-resume-lost-two-turn.txt.
RESUME_ID_1=37b5f8f7-cd46-44d7-8416-946cf6729b30
RESUME_ID_2=7ded81f3-920a-40b7-bf8b-5f08e913c333

# resume_cfg [id...] — an empty config dir exported as CLAUDE_CONFIG_DIR, with
# a transcript projects/-p/<id>.jsonl, one JSON line as CC writes, for each
# id given.
resume_cfg() {
  local id
  export CLAUDE_CONFIG_DIR="$BATS_TEST_TMPDIR/cfg"
  mkdir -p "$CLAUDE_CONFIG_DIR/projects/-p"
  for id in "$@"; do
    printf '{}\n' >"$CLAUDE_CONFIG_DIR/projects/-p/$id.jsonl"
  done
}

# The verdicts, written out here and not read from lib/verdicts.sh, so a
# wording change in the library turns these cases red.
# shellcheck disable=SC2016 # backticks are literal prose, not expansion
LOST_CTX='The transcript was never written: `~/.claude/projects` is read-only inside the sandbox. Run the entire multi-turn flow in one unsandboxed call.'
LOST_SYS='--resume — transcript not persisted in sandbox'
# shellcheck disable=SC2016 # backticks are literal prose, not expansion
FOUND_CTX='A transcript for this session exists, so the sandbox did not lose it and an unsandboxed retry will not help. `--resume` finds a session from any working directory: check that this call reads the config directory that holds the transcript (`CLAUDE_CONFIG_DIR`, else `~/.claude`).'
FOUND_SYS='--resume — transcript exists, not the sandbox'

# resume_verdict <flag> <ctx> <sys> — runs the hook on the fixture text with
# the flag set to true|false, or absent when <flag> is empty, and requires
# exactly this additionalContext and systemMessage. A flag given is proven to
# be in the payload the hook reads, so a silent hook cannot be read as "the
# payload never carried the flag".
resume_verdict() {
  local flag="$1" want_ctx="$2" want_sys="$3" text payload ctx sys
  text=$(cat "$FIXTURES/fire-resume-lost-two-turn.txt")
  payload=$(post_payload "$text" "" "$flag")
  if [ -n "$flag" ]; then
    [ "$(printf '%s' "$payload" | jq -r '.tool_input.dangerouslyDisableSandbox')" = "$flag" ]
  else
    printf '%s' "$payload" | jq -e '.tool_input | has("dangerouslyDisableSandbox") | not' >/dev/null
  fi
  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ -n "$output" ] || { echo "no verdict emitted, flag '${flag:-absent}'" >&2; return 1; }
  ctx=$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')
  sys=$(printf '%s' "$output" | jq -r '.systemMessage')
  [ "$ctx" = "$want_ctx" ]
  [ "$sys" = "$want_sys" ]
}

@test "resume-lost through the hook: no transcript, today's verdict" {
  local text payload ctx sys
  text=$(cat "$FIXTURES/fire-resume-lost-two-turn.txt")
  resume_cfg

  payload=$(post_payload "$text")
  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ -n "$output" ] \
    || { echo "no verdict emitted, config dir empty" >&2; return 1; }
  ctx=$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')
  sys=$(printf '%s' "$output" | jq -r '.systemMessage')
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  [ "$ctx" = 'The transcript was never written: `~/.claude/projects` is read-only inside the sandbox. Run the entire multi-turn flow in one unsandboxed call.' ]
  [ "$sys" = '--resume — transcript not persisted in sandbox' ]
}

@test "resume-lost no-transcript verdict survives BSD grep, sed, mktemp, stat and wc" {
  local text payload bsd plain
  text=$(cat "$FIXTURES/fire-resume-lost-two-turn.txt")
  resume_cfg
  payload=$(post_payload "$text")

  run_hook "$payload"
  [ "$status" -eq 0 ]
  plain="$output"

  bsd="$BATS_TEST_TMPDIR/bsdtools"
  make_bsd_stubs "$bsd" sed grep mktemp stat wc
  PATH="$bsd:$PATH" run_hook "$payload"
  [ "$status" -eq 0 ]
  [ -n "$output" ] \
    || { echo "no verdict emitted under BSD stubs" >&2; return 1; }
  [ "$output" = "$plain" ]
  [ "$(printf '%s' "$output" | jq -r '.systemMessage')" = '--resume — transcript not persisted in sandbox' ]
}

@test "resume-lost through the hook: no config root to search, silent" {
  # HOME and CLAUDE_CONFIG_DIR both unset: the probe has nowhere to look and
  # its outcome is one the verdict has no text for. The case above emits for
  # the same text once a root exists; here nothing reaches stdout or stderr
  # (run_hook merges stderr into $output).
  local text payload
  text=$(cat "$FIXTURES/fire-resume-lost-two-turn.txt")
  payload=$(post_payload "$text")

  # shellcheck disable=SC2016 # $1 and $2 expand in the inner bash
  run env -u HOME -u CLAUDE_CONFIG_DIR \
    bash -c 'printf "%s" "$1" | bash "$2"' _ "$payload" "$HOOK_COPY/hooks/annotate.sh"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "resume-lost through the hook: transcripts for both ids, the exists verdict" {
  resume_cfg "$RESUME_ID_1" "$RESUME_ID_2"
  resume_verdict "" "$FOUND_CTX" "$FOUND_SYS"
}

# The partial cases come in both orders under both flag values: a probe that
# tests only the first id reads the first-only partial as found, one that lets
# the last id decide reads the second-only partial as found, and each flag-true
# case has a flag-absent twin on the same config dir.
@test "resume-lost through the hook: only the first id has a transcript, the lost verdict" {
  resume_cfg "$RESUME_ID_1"
  resume_verdict "" "$LOST_CTX" "$LOST_SYS"
}

@test "resume-lost through the hook: only the second id has a transcript, the lost verdict" {
  resume_cfg "$RESUME_ID_2"
  resume_verdict "" "$LOST_CTX" "$LOST_SYS"
}

@test "resume-lost flag true: no transcript, the lost verdict as with the flag absent" {
  resume_cfg
  resume_verdict true "$LOST_CTX" "$LOST_SYS"
}

@test "resume-lost flag true: transcripts for both ids, the exists verdict as with the flag absent" {
  resume_cfg "$RESUME_ID_1" "$RESUME_ID_2"
  resume_verdict true "$FOUND_CTX" "$FOUND_SYS"
}

@test "resume-lost flag true: only the first id has a transcript, the lost verdict as with the flag absent" {
  resume_cfg "$RESUME_ID_1"
  resume_verdict true "$LOST_CTX" "$LOST_SYS"
}

@test "resume-lost flag true: only the second id has a transcript, the lost verdict as with the flag absent" {
  resume_cfg "$RESUME_ID_2"
  resume_verdict true "$LOST_CTX" "$LOST_SYS"
}
