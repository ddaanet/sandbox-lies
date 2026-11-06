#!/usr/bin/env bats
# The recovery clause end to end, real probe and real verdict, over the
# fire-readonly-path-checkout-moved fixture's text: a checkout that moved HEAD
# to main before git's unlink refusal on .claude/settings.json, cut from a
# recorded session. Neither clause says HEAD stayed put or offers update-config.

load helpers/bsd-stubs
load helpers/git-env
load helpers/hook

setup() {
  hook_copy_tree
  REPO="$BATS_TEST_TMPDIR/repo"
  git init -q -b main "$REPO"
  mkdir "$REPO/.claude"
  printf '{}\n' >"$REPO/.claude/settings.json"
  git -C "$REPO" add .claude/settings.json
  git -C "$REPO" commit -q -m main
  git -C "$REPO" branch dev
  # the state after the moved checkout: HEAD on main, settings edited
  printf '{"edited":true}\n' >"$REPO/.claude/settings.json"
}

# hook_context <command> — the hook's additionalContext for the fixture's text
# under <command>, in $ctx.
hook_context() {
  local text payload
  text=$(cat "$FIXTURES/fire-readonly-path-checkout-moved.txt")
  payload=$(post_payload "$text" | jq --arg c "$1" --arg d "$REPO" \
    '.tool_input.command = $c | .cwd = $d')
  run_hook "$payload"
  [ "$status" -eq 0 ]
  ctx=$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')
  assert_lacks "$ctx" 'update-config'
  assert_lacks "$ctx" 'HEAD unmoved'
}

# The body of the lone-checkout case, shared with its BSD re-run.
lone_checkout_case() {
  local ctx
  hook_context 'git checkout main'
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  [ "$ctx" = "\`$REPO/.claude/settings.json\`"' is writable outside the sandbox, whose allowlist refused it. Before any re-run, run `sandbox-lies-recover -C '"$REPO"' checkout main` with `dangerouslyDisableSandbox: true` and read its plan: the git command may have stopped part-way. The `sandbox-lies:sandbox-lies` skill says how to carry the plan out.' ]
}

@test "a lone refused checkout gets the recovery script for its repository and branch" {
  lone_checkout_case
}

@test "a lone refused checkout gets the script clause under BSD grep, sed, stat and wc" {
  local bsd="$BATS_TEST_TMPDIR/bsdtools"
  make_bsd_stubs "$bsd" grep sed stat wc
  PATH="$bsd:$PATH" lone_checkout_case
}

@test "the recorded compound command, two merge-style segments, gets the generic clause" {
  local ctx
  hook_context "git checkout main && git merge --ff-only dev && git log --oneline -1 && git status --short | grep -v '^?? \\.'"
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  [ "$ctx" = "\`$REPO/.claude/settings.json\`"' is writable outside the sandbox, whose allowlist refused it. Before any re-run, follow the `sandbox-lies:sandbox-lies` skill'"'"'s recovery of a refused merge or checkout: the git command may have stopped part-way.' ]
}

@test "a branch name holding a shell metacharacter reaches the recovery script as one argument" {
  local ctx cmd
  # shellcheck disable=SC2016 # the literal $ is the metacharacter under test
  git -C "$REPO" branch 'a;b$IFS(c)'
  hook_context "git checkout 'a;b\$IFS(c)'"
  cmd=${ctx#*run \`}
  cmd=${cmd%%\` with*}
  [[ "$cmd" == sandbox-lies-recover\ * ]]
  printargs() { printf '%s\n' "$@"; }
  run eval "${cmd/sandbox-lies-recover/printargs}"
  [ "$status" -eq 0 ]
  [ "$output" = "-C
$REPO
checkout
a;b\$IFS(c)" ]
}
