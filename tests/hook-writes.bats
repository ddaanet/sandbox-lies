#!/usr/bin/env bats
# NFR-4 on the hook's probe path: the whole hook, run on a payload whose probe
# reads a real scratch tree, creates no temp file. Split from tests/hook.bats
# ("hook needs no temp dir"), which stays under the line cap and pins the
# probe-free gitadd path only. Each payload's cwd is its own scratch tree and
# its error text is built with helpers/probes, never a fixture's host path.
# Proven by mutation: a mktemp call in annotate.sh's probe branch before the
# probe call, and one at the top of _readonly_print_facts, each turn a case
# here red.

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs
load helpers/git-env
load helpers/hook
load helpers/spy
load helpers/probes

setup() {
  hook_copy_tree
  PAYLOAD_FILE="$BATS_TEST_TMPDIR/payload.json"
}

# readonly_payload_file <repo> — writes the payload for a writable refusal of
# <repo>/a under `git merge feat` (so _readonly_print_facts runs its git
# reads, flag absent) to $PAYLOAD_FILE (set in setup).
readonly_payload_file() {
  local repo="$1" text
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'$repo/a'")
  failure_payload "$text" |
    jq --arg c "$repo" '.cwd = $c | .tool_input.command = "git merge feat"
      | del(.tool_input.dangerouslyDisableSandbox)' >"$PAYLOAD_FILE"
}

# run_spied <extra-path-dir|-> — runs the hook copy on $PAYLOAD_FILE with a
# mktemp spy on PATH (after <extra-path-dir>, when given) and TMPDIR naming a
# directory that does not exist, into $output and $status.
run_spied() {
  local prefix="$BATS_TEST_TMPDIR/spy"
  [ "$1" = - ] || prefix="$1:$prefix"
  SPY_CALLS="$BATS_TEST_TMPDIR/spy-calls"
  make_spy "$BATS_TEST_TMPDIR/spy" "$SPY_CALLS" mktemp
  run env PATH="$prefix:$PATH" TMPDIR="$BATS_TEST_TMPDIR/does-not-exist" \
    bash "$HOOK_COPY/hooks/annotate.sh" <"$PAYLOAD_FILE"
}

# The payload's probe runs git reads, and the writable refusal prints the
# human line; the unspied run is computed here so the comparison is exact.
@test "hook needs no temp dir on a readonly-path refusal" {
  local repo="$BATS_TEST_TMPDIR/repo" expected
  make_scratch_repo "$repo"
  readonly_payload_file "$repo"

  run bash "$HOOK_COPY/hooks/annotate.sh" <"$PAYLOAD_FILE"
  [ "$status" -eq 0 ]
  expected="$output"
  printf '%s' "$expected" | jq -e . >/dev/null
  [ "$(printf '%s' "$expected" | jq -r .systemMessage)" = \
    'read-only — sandbox allowlist, writable outside' ]

  run_spied -
  [ "$status" -eq 0 ]
  [ "$output" = "$expected" ]
  [ ! -e "$SPY_CALLS" ] || { cat "$SPY_CALLS" >&2; return 1; }
}

@test "hook needs no temp dir on a git-lock refusal" {
  # git_lock_error leaves out the follow-on sentence the matcher requires; it
  # is added here from two fragments (self-quiet, FR-11).
  local scratch="$BATS_TEST_TMPDIR/lockrepo" expected text follow
  follow='Another git process seems to be running'
  follow="$follow in this repository"
  mkdir -p "$scratch/.git"
  text="$(git_lock_error "$scratch/.git/index.lock")"$'\n'"$follow"
  failure_payload "$text" |
    jq --arg c "$scratch" '.cwd = $c' >"$PAYLOAD_FILE"

  run bash "$HOOK_COPY/hooks/annotate.sh" <"$PAYLOAD_FILE"
  [ "$status" -eq 0 ]
  expected="$output"
  printf '%s' "$expected" | jq -e . >/dev/null
  [ "$(printf '%s' "$expected" | jq -r .systemMessage)" = \
    'index.lock — sandbox mask, not a real lock' ]

  run_spied -
  [ "$status" -eq 0 ]
  [ "$output" = "$expected" ]
  [ ! -e "$SPY_CALLS" ] || { cat "$SPY_CALLS" >&2; return 1; }
}

# The readonly-path case again with the BSD-strict grep, sed, stat and wc in
# front of the spy: the probe's git reads and tool calls must survive the
# stubs and produce the same output as the plain run.
@test "hook needs no temp dir on a readonly-path refusal under BSD stubs" {
  local repo="$BATS_TEST_TMPDIR/repo" expected
  make_scratch_repo "$repo"
  readonly_payload_file "$repo"

  run bash "$HOOK_COPY/hooks/annotate.sh" <"$PAYLOAD_FILE"
  [ "$status" -eq 0 ]
  expected="$output"
  [ -n "$expected" ]

  make_bsd_stubs "$BATS_TEST_TMPDIR/bsd" grep sed stat wc
  run_spied "$BATS_TEST_TMPDIR/bsd"
  [ "$status" -eq 0 ]
  [ "$output" = "$expected" ]
  [ ! -e "$SPY_CALLS" ] || { cat "$SPY_CALLS" >&2; return 1; }
}
