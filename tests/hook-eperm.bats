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
    merge=1 partial=1 target=unification recover=checkout "repo=$REPO")
  [ "$ctx" = "$(printf '%s\n' "$want" | sed -n '1p')" ]
  [ "$sys" = 'read-only — sandbox allowlist, writable outside' ]
  [ "$sys" = "$(printf '%s\n' "$want" | sed -n '2p')" ]
  [[ "$ctx" == "\`$REPO/.claude/agents/quiet-task.md\` is writable outside"* ]] || false
  [[ "$ctx" == *"sandbox-lies-recover -C $REPO checkout unification"* ]] || false
}

@test "a checkout refused as not permitted gets the recovery script clause and the writable line" {
  checkout_case
}

@test "a checkout refused as not permitted gets the script clause under BSD grep, sed, stat and wc" {
  local bsd="$BATS_TEST_TMPDIR/bsdtools"
  make_bsd_stubs "$bsd" grep sed stat wc
  PATH="$bsd:$PATH" checkout_case
}

@test "a refused config write after a checkout gets the nopath act alone" {
  local text payload ctx sys want
  assert_no_git_above "$BATS_TEST_TMPDIR"
  text=$(cat "$FIXTURES/fire-readonly-path-config-eperm.txt")
  payload=$(post_payload "$text" | jq \
    --arg c 'git checkout origin/tmp -b tmp_checkout' \
    --arg d "$BATS_TEST_TMPDIR" '.tool_input.command = $c | .cwd = $d')
  hook_fields "$payload"
  want=$(expected_text nopath merge=1)
  [ "$ctx" = "$(printf '%s\n' "$want" | sed -n '1p')" ]
  [ "$sys" = 'read-only — probably the sandbox, path not checked' ]
  [[ "$ctx" == *'Re-run the whole call with '* ]] || false
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
