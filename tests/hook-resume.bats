#!/usr/bin/env bats
# resume-lost through the hook with the real probe_resume_lost (Item 1.1):
# the wiring, the no-transcript verdict and its BSD re-run. The probe's own
# cases are in tests/probes-resume.bats; the flag policy case stays in
# tests/hook-candidates.bats beside the other candidates' flag policies.

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

@test "resume-lost through the hook: transcripts for both ids, no verdict" {
  local text payload
  text=$(cat "$FIXTURES/fire-resume-lost-two-turn.txt")
  resume_cfg "$RESUME_ID_1" "$RESUME_ID_2"

  payload=$(post_payload "$text")
  run_hook "$payload"
  [ "$status" -eq 0 ]
  assert_lacks "$output" 'never written'
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
