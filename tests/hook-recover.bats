#!/usr/bin/env bats
# The recovery clause end to end, real probe and real verdict: a checkout that
# moved HEAD to main before git's unlink refusal on .claude/settings.json
# (the fire-readonly-path-checkout-moved fixture, cut from a recorded
# session). The clause must send the agent to the recovery script for main,
# say nothing of HEAD staying put, and not offer update-config.

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs
load helpers/git-env
load helpers/hook

setup() {
  hook_copy_tree
}

@test "a refused checkout that moved HEAD gets the recovery script for the branch, not update-config" {
  local repo="$BATS_TEST_TMPDIR/repo" text cmd payload ctx
  git init -q -b main "$repo"
  git -C "$repo" config user.email test@example.invalid
  git -C "$repo" config user.name test
  git -C "$repo" config commit.gpgsign false
  mkdir "$repo/.claude"
  printf '{}\n' >"$repo/.claude/settings.json"
  git -C "$repo" add .claude/settings.json
  git -C "$repo" commit -q -m main
  git -C "$repo" branch dev
  # the state after the moved checkout: HEAD on main, settings edited
  printf '{"edited":true}\n' >"$repo/.claude/settings.json"

  text=$(cat "$FIXTURES/fire-readonly-path-checkout-moved.txt")
  cmd="git checkout main && git merge --ff-only dev && git log --oneline -1 && git status --short | grep -v '^?? \\.'"
  payload=$(post_payload "$text" | jq --arg c "$cmd" --arg d "$repo" \
    '.tool_input.command = $c | .cwd = $d')

  run bash -c 'printf "%s" "$1" | bash "$2"' _ "$payload" \
    "$HOOK_COPY/hooks/annotate.sh"
  [ "$status" -eq 0 ]
  ctx=$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  [ "$ctx" = "\`$repo/.claude/settings.json\`"' is writable outside the sandbox, whose allowlist refused it. Before any re-run, run `sandbox-lies-recover checkout main` with `dangerouslyDisableSandbox: true` and read its plan: the git command may have stopped part-way. The `sandbox-lies:sandbox-lies` skill says how to carry the plan out.' ]
  run ! grep -qF 'update-config' <<<"$ctx"
  run ! grep -qF 'HEAD unmoved' <<<"$ctx"
}
