#!/usr/bin/env bats
# NFR-4 on the hook's probe path: the whole hook, run on a payload whose probe
# reads a real scratch tree, creates no temp file. Split from tests/hook.bats
# ("hook needs no temp dir"), which stays under the line cap and pins the
# probe-free gitadd path only. Each payload's cwd is its own scratch tree and
# its error text is built with helpers/probes, never a fixture's host path.
# Proven by mutation: a mktemp call in annotate.sh's probe branch before the
# probe call, and one at the top of _readonly_print_facts, each turn a case
# here red. The recovery-clause case drives the same real-probe payload from
# a subdirectory cwd and pins the script clause, which names no match= file.

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

# The recovery clause sends the agent to the script for the resolved ref and
# names no file, from a payload whose cwd is a subdirectory of the repo: real
# probe, flag absent.
@test "hook recovery clause names the script and ref, not the matching files" {
  local repo="$BATS_TEST_TMPDIR/repo" ctx
  make_scratch_repo "$repo"
  mkdir "$repo/sub"
  readonly_payload_file "$repo"
  jq --arg c "$repo/sub" '.cwd = $c' "$PAYLOAD_FILE" >"$PAYLOAD_FILE.sub"

  run bash "$HOOK_COPY/hooks/annotate.sh" <"$PAYLOAD_FILE.sub"

  [ "$status" -eq 0 ]
  ctx=$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  [ "$ctx" = "\`$repo/a\`"' is writable outside the sandbox, whose allowlist refused it. Before any re-run, run `sandbox-lies-recover merge feat` with `dangerouslyDisableSandbox: true` and read its plan: the git command may have stopped part-way. The `sandbox-lies:sandbox-lies` skill says how to carry the plan out.' ]
  run ! grep -qF "$repo/b" <<<"$ctx"
}

# The probe prints path= in printf %q form (Item 1.1); the verdict decodes it
# (Item 1.2), so a relative path under a cwd holding a blank reads in the
# agent paragraph as the raw absolute path: no escaping backslash. The cwd
# exists and is writable, so the probe answers writable on the absent path.
@test "hook names a blank-holding path raw, with no backslash" {
  local cwd="$BATS_TEST_TMPDIR/dir with blank" text ctx expected
  mkdir "$cwd"
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'f'")
  failure_payload "$text" |
    jq --arg c "$cwd" '.cwd = $c | del(.tool_input.dangerouslyDisableSandbox)' \
      >"$PAYLOAD_FILE"
  expected="\`$cwd/f\` is writable outside the sandbox, whose allowlist refused it."

  run bash "$HOOK_COPY/hooks/annotate.sh" <"$PAYLOAD_FILE"

  [ "$status" -eq 0 ]
  ctx=$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')
  [ "${ctx#"$expected"}" != "$ctx" ]
  assert_lacks "$ctx" "\\"

  make_bsd_stubs "$BATS_TEST_TMPDIR/bsd" grep sed stat wc
  run env PATH="$BATS_TEST_TMPDIR/bsd:$PATH" \
    bash "$HOOK_COPY/hooks/annotate.sh" <"$PAYLOAD_FILE"
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')" = "$ctx" ]
}

# The same seam for a control byte: the probe's `$'...'` value decodes to a
# path holding a newline, which would split the paragraph from its human line,
# so the paragraph shows the wire form on one line.
@test "hook shows the wire form for a path holding a newline, on one line" {
  local cwd="$BATS_TEST_TMPDIR/dir"$'\n'"with newline" text ctx wire
  mkdir "$cwd"
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'f'")
  failure_payload "$text" |
    jq --arg c "$cwd" '.cwd = $c | del(.tool_input.dangerouslyDisableSandbox)' \
      >"$PAYLOAD_FILE"
  wire=$(LC_ALL=C; printf '%q' "$cwd/f")
  [ "${wire#\$\'}" != "$wire" ]

  run bash "$HOOK_COPY/hooks/annotate.sh" <"$PAYLOAD_FILE"

  [ "$status" -eq 0 ]
  ctx=$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')
  [ "$ctx" = "\`$wire\` is writable outside the sandbox, whose allowlist refused it. Re-run the whole call with \`dangerouslyDisableSandbox: true\`." ]
}
