#!/usr/bin/env bats
# lib/verdicts.sh's verdict_readonly_path under the probe's claudeonly=1 and
# configonly=1 facts: the act for refusals that all fall under a .claude
# directory, and the act for a call whose only refusal is git's config-file
# write. Their precedence against readfile=, the update-config act and the
# merge clause. The rest of the composition: tests/verdicts-readonly.bats.

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs
load helpers/verdicts

# line1 <outcome> [fact...] — the verdict's first line over the facts given.
line1() {
  local outcome="$1"
  shift
  # shellcheck disable=SC1090 # $VERDICTS is lib/verdicts.sh
  printf '%s\n' "$@" | ( . "$VERDICTS"; verdict_readonly_path "$outcome" ) \
    | sed -n '1p'
}

# quiet <text> — the matchers fire on none of <text> (self-quiet, FR-11).
quiet() {
  run bash -c 'printf "%s\n" "$1" | bash "$2"' _ "$1" "$MATCHERS"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "claudeonly=1 hands the call to the user in place of the re-run" {
  local w n
  w=$(line1 writable path=/r/.claude/agents/a.md claudeonly=1)
  n=$(line1 nopath claudeonly=1)
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  [ "$w" = '`/r/.claude/agents/a.md` is writable outside the sandbox, whose allowlist refused it. Every refused path is under a `.claude` directory, whose files can run code: tell the user what was refused, and leave any unsandboxed re-run or recovery to them.' ]
  [[ "$n" == "The sandbox's write allowlist most likely refused this write. Every refused path"* ]] || false
  text_lacks "$w" 'dangerouslyDisableSandbox'
  quiet "$w"
}

@test "claudeonly=1 replaces the recovery script clause, keeping the part-way warning" {
  local w
  w=$(line1 writable path=/r/.claude/settings.json merge=1 partial=1 \
    target=b recover=checkout repo=/r claudeonly=1)
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  [[ "$w" == *'The git command may have stopped part-way. Every refused path is under a `.claude` directory'* ]] || false
  text_lacks "$w" 'sandbox-lies-recover'
  text_lacks "$w" 'dangerouslyDisableSandbox'
  text_lacks "$w" 'recovery of a refused merge'
  quiet "$w"
}

@test "without claudeonly=1 the same facts keep the recovery script clause" {
  local w
  w=$(line1 writable path=/r/.claude/settings.json merge=1 partial=1 \
    target=b recover=checkout repo=/r)
  [[ "$w" == *'sandbox-lies-recover -C /r checkout b'* ]] || false
  text_lacks "$w" 'Every refused path'
}

@test "the update-config act and the read act win over claudeonly=1" {
  local w r
  w=$(line1 writable path=/r/.claude/settings.json claudeonly=1)
  r=$(line1 nopath readfile=/w/b.log claudeonly=1)
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  [[ "$w" == *'through the `update-config` skill.' ]] || false
  text_lacks "$w" 'Every refused path'
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  [[ "$r" == *'Re-run the command that wrote `/w/b.log`.' ]] || false
  text_lacks "$r" 'Every refused path'
}

@test "configonly=1 makes the config change alone, not a re-run of the call" {
  local n
  n=$(line1 nopath merge=1 configonly=1)
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  [ "$n" = "The sandbox's write allowlist most likely refused this write. Only git's config-file write was refused, and the rest of the call may already have run: make that config change alone with \`dangerouslyDisableSandbox: true\`, not a re-run of the whole call." ]
  quiet "$n"
}

@test "the read act wins over configonly=1" {
  local n
  n=$(line1 nopath readfile=/w/b.log configonly=1)
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  [[ "$n" == *'Re-run the command that wrote `/w/b.log`.' ]] || false
  text_lacks "$n" 'config change'
}
