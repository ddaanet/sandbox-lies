#!/usr/bin/env bats
# readonly-path through the hook, real matcher, probe and verdict, over three
# recorded git results worded as operation-not-permitted refusals (the
# fire-readonly-path-*-eperm fixtures): a checkout whose first matching line
# is an unlink warning, a refused config write, and a refused index lock. The
# expected paragraph and human line come from lib/verdicts.sh fed the facts
# the probe is expected to print, so the wording is never pasted here; the
# literal assertions pin what the facts must carry.

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs
load helpers/git-env
load helpers/hook
load helpers/probes

setup() {
  hook_copy_tree
  REPO="$BATS_TEST_TMPDIR/repo"
  # facts print the path in printf %q form; the literal expectations assume
  # it needs no escape
  assert_unescaped_dir "$BATS_TEST_TMPDIR"
}

# expected_text <outcome> <fact>... — lib/verdicts.sh's two-line text for the
# probe facts given one per line.
expected_text() {
  local outcome="$1"
  shift
  # shellcheck disable=SC1091 # the copied lib, resolved at run time
  ( . "$HOOK_COPY/lib/verdicts.sh"; verdict_readonly_path "$outcome" ) \
    < <(printf '%s\n' "$@")
}

# hook_fields <payload> — the hook's output split into $ctx and $sys.
hook_fields() {
  run_hook "$1"
  [ "$status" -eq 0 ]
  [ -n "$output" ] || { echo "no verdict emitted" >&2; return 1; }
  ctx=$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')
  sys=$(printf '%s' "$output" | jq -r '.systemMessage')
}

# make_checkout_repo — $REPO on main holding .claude/agents/quiet-task.md, a
# branch unification beside it, cwd of the recorded checkout.
make_checkout_repo() {
  git init -q -b main "$REPO"
  mkdir -p "$REPO/.claude/agents"
  printf 'q\n' >"$REPO/.claude/agents/quiet-task.md"
  git -C "$REPO" add .claude
  git -C "$REPO" commit -q -m main
  git -C "$REPO" branch unification
}

# The body of the checkout case, shared with its BSD re-run.
checkout_case() {
  local text payload ctx sys want
  make_checkout_repo
  text=$(cat "$FIXTURES/fire-readonly-path-checkout-eperm.txt")
  payload=$(post_payload "$text" | jq --arg c 'git checkout unification' \
    --arg d "$REPO" '.tool_input.command = $c | .cwd = $d')
  hook_fields "$payload"
  want=$(expected_text writable "path=$REPO/.claude/agents/quiet-task.md" \
    merge=1 partial=1 target=unification recover=checkout "repo=$REPO" \
    claudeonly=1)
  [ "$ctx" = "$(printf '%s\n' "$want" | sed -n '1p')" ]
  [ "$sys" = 'read-only — sandbox allowlist, writable outside' ]
  [ "$sys" = "$(printf '%s\n' "$want" | sed -n '2p')" ]
  [[ "$ctx" == "\`$REPO/.claude/agents/quiet-task.md\` is writable outside"* ]] || false
  [[ "$ctx" == *'tell the user'* ]] || false
  assert_lacks "$ctx" 'sandbox-lies-recover'
  assert_lacks "$ctx" 'dangerouslyDisableSandbox'
}

# Every refused path of the recorded checkout is under .claude/: the verdict
# hands the call to the user, with no unsandboxed recovery or re-run.
@test "a checkout refused on .claude paths alone points at the user, with no unsandboxed act" {
  checkout_case
}

@test "a checkout refused on .claude paths alone points at the user under BSD grep, sed, stat and wc" {
  local bsd="$BATS_TEST_TMPDIR/bsdtools"
  make_bsd_stubs "$bsd" grep sed stat wc
  PATH="$bsd:$PATH" checkout_case
}

# The recorded checkout from a subdirectory: its first line, the unlink
# warning, names its path from the worktree top, so the path is found and
# reads writable rather than readonly through the absent sub/.claude.
@test "a checkout run from a subdirectory reads its unlink warning's path from the worktree top" {
  local text payload ctx sys
  make_checkout_repo
  mkdir "$REPO/sub"
  text=$(cat "$FIXTURES/fire-readonly-path-checkout-eperm.txt")
  payload=$(post_payload "$text" | jq --arg c 'git checkout unification' \
    --arg d "$REPO/sub" '.tool_input.command = $c | .cwd = $d')
  hook_fields "$payload"
  [ "$sys" = 'read-only — sandbox allowlist, writable outside' ]
  [[ "$ctx" == "\`$REPO/.claude/agents/quiet-task.md\` is writable outside"* ]] || false
}

# The branch was made and checked out; only its tracking config was refused,
# so a re-run of the call would fail on the existing branch.
@test "a refused config write after a checkout gets the config-only act" {
  local text payload ctx sys want
  assert_no_git_above "$BATS_TEST_TMPDIR"
  text=$(cat "$FIXTURES/fire-readonly-path-config-eperm.txt")
  payload=$(post_payload "$text" | jq \
    --arg c 'git checkout origin/tmp -b tmp_checkout' \
    --arg d "$BATS_TEST_TMPDIR" '.tool_input.command = $c | .cwd = $d')
  hook_fields "$payload"
  want=$(expected_text nopath merge=1 configonly=1)
  [ "$ctx" = "$(printf '%s\n' "$want" | sed -n '1p')" ]
  [ "$sys" = 'read-only — probably the sandbox, path not checked' ]
  [[ "$ctx" == *'that config change alone'* ]] || false
  assert_lacks "$ctx" 'Re-run the whole call'
  assert_lacks "$ctx" 'tell the user'
  assert_lacks "$ctx" 'sandbox-lies-recover'
  assert_lacks "$ctx" 'recovery of a refused merge'
}

@test "a refused index lock gets writable and the plain re-run act" {
  local text payload ctx sys want lock="$REPO/.git/index.lock"
  git init -q -b main "$REPO"
  # the quoted path of line 2 is replaced, keeping the /.git/index.lock suffix
  # the matcher's lock alternative requires; line 1's quoted ref is replaced
  # too, which leaves it a non-shape line
  text=$(readonly_path_text fire-readonly-path-index-lock-eperm "'$lock'")
  payload=$(failure_payload "$text" | jq \
    --arg c 'cd /Users/david/code/plugin-craft && git symbolic-ref HEAD' \
    --arg d "$REPO" '.tool_input.command = $c | .cwd = $d')
  hook_fields "$payload"
  want=$(expected_text writable "path=$lock")
  [ "$ctx" = "$(printf '%s\n' "$want" | sed -n '1p')" ]
  [ "$sys" = 'read-only — sandbox allowlist, writable outside' ]
  [[ "$ctx" == "\`$lock\` is writable outside"* ]] || false
  assert_lacks "$ctx" 'sandbox-lies-recover'
}
