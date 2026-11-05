#!/usr/bin/env bats
# lib/verdicts.sh's verdict_readonly_path: the writable/nopath tail composed
# from the probe's key=value facts on stdin (readfile=, path=, merge=1,
# target=, match=), transcribed from docs/references/readonly-path.md's
# readonly-path Verdicts tail and merge-clause composition (Item 8.0 slice
# 2). Complements tests/verdicts.bats and tests/hook-locks.bats.

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs
load helpers/verdicts

# readonly_path_text <outcome> [fact...] — verdict_readonly_path's two-line
# text over synthetic stdin key lines (path=, readfile=, merge=1, target=,
# match=), one call per composition.
readonly_path_text() {
  local outcome="$1"
  shift
  # shellcheck disable=SC1090 # $VERDICTS is lib/verdicts.sh, resolved above
  printf '%s\n' "$@" | ( . "$VERDICTS"; verdict_readonly_path "$outcome" )
}

@test "readonly-path with no facts states the plain re-run act" {
  local w n
  w=$(readonly_path_text writable path=/r/x | sed -n '1p')
  n=$(readonly_path_text nopath | sed -n '1p')
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  [ "$w" = '`/r/x` is writable outside the sandbox, whose allowlist refused it. Re-run the whole call with `dangerouslyDisableSandbox: true`.' ]
  [ "$n" = "The sandbox's write allowlist most likely refused this write. Re-run the whole call with \`dangerouslyDisableSandbox: true\`." ]
  [ "${#w}" -lt 400 ]
  [ "${#n}" -lt 400 ]
  run bash -c 'printf "%s\n" "$1" | bash "$2"' _ "$w
$n" "$MATCHERS"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "readonly-path readfile fact re-runs the writer, not the whole call" {
  local text line1 expected
  text=$(readonly_path_text nopath readfile=/w/build.log)
  line1=$(printf '%s\n' "$text" | sed -n '1p')
  expected="The sandbox's write allowlist most likely refused this write. Re-run the command that wrote \`/w/build.log\`."
  [ "$line1" = "$expected" ]
  text_lacks "$line1" 'dangerouslyDisableSandbox'
  [ "${#line1}" -lt 400 ]
  run bash -c 'printf "%s\n" "$1" | bash "$2"' _ "$text" "$MATCHERS"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "readonly-path settings.json path composes the update-config act, readfile winning" {
  # readfile= wins by the tail's precedence, not by line order: both orders
  # give the read act.
  local text line1 read_act
  text=$(readonly_path_text writable path=/r/.claude/settings.json)
  line1=$(printf '%s\n' "$text" | sed -n '1p')
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  [ "$line1" = '`/r/.claude/settings.json` is writable outside the sandbox, whose allowlist refused it. Write `.claude/settings.json` through the `update-config` skill.' ]
  [ "${#line1}" -lt 400 ]
  run bash -c 'printf "%s\n" "$1" | bash "$2"' _ "$text" "$MATCHERS"
  [ "$status" -eq 1 ]
  [ -z "$output" ]

  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  read_act='`/r/.claude/settings.json` is writable outside the sandbox, whose allowlist refused it. Re-run the command that wrote `/w/build.log`.'
  text=$(readonly_path_text writable path=/r/.claude/settings.json readfile=/w/build.log)
  line1=$(printf '%s\n' "$text" | sed -n '1p')
  [ "$line1" = "$read_act" ]
  text=$(readonly_path_text writable readfile=/w/build.log path=/r/.claude/settings.json)
  line1=$(printf '%s\n' "$text" | sed -n '1p')
  [ "$line1" = "$read_act" ]
  [ "${#line1}" -lt 400 ]
}

@test "readonly-path update-config act is writable-only and needs a .claude/settings.json" {
  # Each negative runs over the same stdin as the positive above, differing
  # only in the outcome or in the path's .claude component.
  local line1
  line1=$(readonly_path_text nopath path=/r/.claude/settings.json | sed -n '1p')
  [ "$line1" = "The sandbox's write allowlist most likely refused this write.$(readonly_path_tail)" ]
  text_lacks "$line1" 'update-config'

  line1=$(readonly_path_text writable path=/r/settings.json | sed -n '1p')
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  [ "$line1" = '`/r/settings.json` is writable outside the sandbox, whose allowlist refused it.'"$(readonly_path_tail)" ]
  text_lacks "$line1" 'update-config'
}

# writable_lead <path> — the writable outcome's first sentence for <path>.
writable_lead() {
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  printf '`%s` is writable outside the sandbox, whose allowlist refused it.' "$1"
}

# script_clause <sub> <ref> — the clause that sends the agent to the recovery
# script, built here from the contract's wording, not read off lib/.
script_clause() {
  printf '%s' "Before any re-run, run \`sandbox-lies-recover -C /r $1 $2\` with \`dangerouslyDisableSandbox: true\` and read its plan: the git command may have stopped part-way. The \`sandbox-lies:sandbox-lies\` skill says how to carry the plan out."
}

# generic_clause — the clause when no script invocation can be named.
generic_clause() {
  printf '%s' "Before any re-run, follow the \`sandbox-lies:sandbox-lies\` skill's recovery of a refused merge or checkout: the git command may have stopped part-way."
}

# line_one <text> — the verdict's first line.
line_one() {
  printf '%s\n' "$1" | sed -n '1p'
}

# assert_quiet <text> — every line of the verdict stays under 400 characters
# and the matchers fire no detector on it (status 1, no output).
assert_quiet() {
  local l fired rc=0
  while IFS= read -r l; do
    [ "${#l}" -lt 400 ]
  done <<<"$1"
  fired=$(printf '%s\n' "$1" | bash "$MATCHERS") || rc=$?
  [ "$rc" -eq 1 ]
  [ -z "$fired" ]
}

@test "readonly-path merge with recover, target and match sends the agent to the script" {
  local text line1
  text=$(readonly_path_text writable path=/r/x merge=1 recover=checkout repo=/r \
    target=main match=/r/alpha.txt match=/r/beta.txt)
  line1=$(line_one "$text")
  [ "$line1" = "$(writable_lead /r/x) $(script_clause checkout main)" ]
  [ "$(printf '%s\n' "$text" | sed -n '2p')" = 'read-only — sandbox allowlist, writable outside' ]
  text_lacks "$line1" 'alpha'
  text_lacks "$line1" 'beta'
  text_lacks "$line1" 'HEAD unmoved'
  text_lacks "$line1" 'restore'
  assert_quiet "$text"
}

@test "readonly-path merge with recover, target and partial but no match still sends the agent to the script" {
  # The moved-HEAD case: git stopped after the switch, so no file matches the
  # target any more, and the clause must not say HEAD stayed.
  local text line1
  text=$(readonly_path_text writable path=/r/x merge=1 partial=1 \
    recover=checkout repo=/r target=main)
  line1=$(line_one "$text")
  [ "$line1" = "$(writable_lead /r/x) $(script_clause checkout main)" ]
  text_lacks "$line1" 'HEAD unmoved'
  text_lacks "$line1" 'restore'
  assert_quiet "$text"
}

@test "readonly-path merge with recover=merge repo=/r names the merge subcommand and its ref" {
  local text line1
  text=$(readonly_path_text writable path=/r/x merge=1 partial=1 \
    recover=merge repo=/r target=dev match=/r/alpha.txt)
  line1=$(line_one "$text")
  [ "$line1" = "$(writable_lead /r/x) $(script_clause merge dev)" ]
  assert_quiet "$text"
}

@test "readonly-path merge with partial=1 and no target gives the generic clause" {
  local text line1
  text=$(readonly_path_text writable path=/r/x merge=1 partial=1)
  line1=$(line_one "$text")
  [ "$line1" = "$(writable_lead /r/x) $(generic_clause)" ]
  assert_quiet "$text"

  # recover= without target= cannot name the invocation either.
  text=$(readonly_path_text writable path=/r/x merge=1 partial=1 recover=checkout repo=/r)
  line1=$(line_one "$text")
  [ "$line1" = "$(writable_lead /r/x) $(generic_clause)" ]
  assert_quiet "$text"
}

@test "readonly-path merge with recover and target but no repo gives the generic clause" {
  local text line1
  text=$(readonly_path_text writable path=/r/x merge=1 partial=1 recover=checkout target=main)
  line1=$(line_one "$text")
  [ "$line1" = "$(writable_lead /r/x) $(generic_clause)" ]
  assert_quiet "$text"
}

@test "readonly-path prints a %q repo verbatim in the script clause" {
  local line1
  line1=$(line_one "$(readonly_path_text writable path=/r/x merge=1 partial=1 \
    recover=merge target=dev 'repo=/a\ b')")
  printf '%s' "$line1" | grep -qF 'sandbox-lies-recover -C /a\ b merge dev'
}

@test "readonly-path merge with a target but no recover gives the generic clause" {
  local text line1
  text=$(readonly_path_text writable path=/r/x merge=1 partial=1 target=main)
  line1=$(line_one "$text")
  [ "$line1" = "$(writable_lead /r/x) $(generic_clause)" ]
  assert_quiet "$text"

  text=$(readonly_path_text writable path=/r/x merge=1 target=main match=/r/alpha.txt)
  line1=$(line_one "$text")
  [ "$line1" = "$(writable_lead /r/x) $(generic_clause)" ]
  text_lacks "$line1" 'alpha'
  assert_quiet "$text"
}

@test "readonly-path merge with neither partial=1 nor match states the act alone" {
  # Each fact set equals the no-facts baseline: no clause fires.
  local text baseline1 facts
  baseline1=$(line_one "$(readonly_path_text writable path=/r/x)")
  [ "$baseline1" = "$(writable_lead /r/x)$(readonly_path_tail)" ]
  for facts in 'merge=1' 'merge=1 target=main' \
    'merge=1 recover=checkout repo=/r target=main'; do
    # shellcheck disable=SC2086 # facts hold no blank within a fact
    text=$(readonly_path_text writable path=/r/x $facts)
    [ "$(line_one "$text")" = "$baseline1" ]
    assert_quiet "$text"
  done
}

@test "readonly-path clause facts without merge=1 leave the act alone" {
  local text baseline1
  baseline1=$(line_one "$(readonly_path_text writable path=/r/x)")
  text=$(readonly_path_text writable path=/r/x partial=1 recover=checkout repo=/r \
    target=main match=/r/alpha.txt)
  [ "$(line_one "$text")" = "$baseline1" ]
  assert_quiet "$text"
}

@test "readonly-path settings.json draws update-config only without merge=1" {
  local text line1
  # positive control: without merge=1, even beside clause facts.
  text=$(readonly_path_text writable path=/r/.claude/settings.json \
    partial=1 recover=checkout repo=/r target=main)
  line1=$(line_one "$text")
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  [ "$line1" = "$(writable_lead /r/.claude/settings.json)"' Write `.claude/settings.json` through the `update-config` skill.' ]

  # merge=1 and no clause: the plain re-run act.
  text=$(readonly_path_text writable path=/r/.claude/settings.json merge=1)
  line1=$(line_one "$text")
  [ "$line1" = "$(writable_lead /r/.claude/settings.json)$(readonly_path_tail)" ]
  text_lacks "$line1" 'update-config'
  assert_quiet "$text"

  # merge=1 with clause facts: the script clause replaces the act.
  text=$(readonly_path_text writable path=/r/.claude/settings.json merge=1 \
    partial=1 recover=checkout repo=/r target=main match=/r/alpha.txt)
  line1=$(line_one "$text")
  [ "$line1" = "$(writable_lead /r/.claude/settings.json) $(script_clause checkout main)" ]
  text_lacks "$line1" 'update-config'
  assert_quiet "$text"

  # the generic clause too, and nopath over a settings path.
  text=$(readonly_path_text writable path=/r/.claude/settings.json merge=1 partial=1)
  text_lacks "$text" 'update-config'
}

@test "readonly-path nopath carries the clause after its own lead" {
  local text line1 lead
  lead="The sandbox's write allowlist most likely refused this write."
  text=$(readonly_path_text nopath merge=1 partial=1 recover=checkout repo=/r target=main)
  line1=$(line_one "$text")
  [ "$line1" = "$lead $(script_clause checkout main)" ]
  assert_quiet "$text"

  text=$(readonly_path_text nopath merge=1 match=/r/alpha.txt)
  line1=$(line_one "$text")
  [ "$line1" = "$lead $(generic_clause)" ]
  assert_quiet "$text"
}

@test "readonly-path clause is followed by the read act as its own sentence" {
  local text line1
  text=$(readonly_path_text writable path=/r/x merge=1 partial=1 \
    readfile=/w/b.log)
  line1=$(line_one "$text")
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  [ "$line1" = "$(writable_lead /r/x) $(generic_clause)"' Re-run the command that wrote `/w/b.log`.' ]
  assert_quiet "$text"

  text=$(readonly_path_text writable path=/r/x merge=1 partial=1 \
    recover=merge repo=/r target=dev readfile=/w/b.log)
  line1=$(line_one "$text")
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  [ "$line1" = "$(writable_lead /r/x) $(script_clause merge dev)"' Re-run the command that wrote `/w/b.log`.' ]
  assert_quiet "$text"
}

@test "readonly-path never names the match= files, however many" {
  local text line1
  text=$(readonly_path_text writable path=/r/x merge=1 recover=checkout repo=/r \
    target=main match=/r/f1.txt match=/r/f2.txt match=/r/f3.txt \
    match=/r/f4.txt match=/r/f5.txt match=/r/f6.txt match=/r/f7.txt)
  line1=$(line_one "$text")
  [ "$line1" = "$(writable_lead /r/x) $(script_clause checkout main)" ]
  text_lacks "$text" 'f1.txt'
  text_lacks "$text" 'f7.txt'
  text_lacks "$text" 'more'
  assert_quiet "$text"
}

@test "readonly-path longest composition stays under 400 with one-character values" {
  # The script clause with a readfile act behind a settings.json lead: the
  # prose's own length, values at one character.
  local line1
  line1=$(readonly_path_text writable path=/.claude/settings.json merge=1 \
    partial=1 recover=checkout repo=/r target=t readfile=/w | sed -n '1p')
  printf '%s' "$line1" | grep -qF 'sandbox-lies-recover -C /r checkout t'
  printf '%s' "$line1" | grep -qF 'Re-run the command that wrote'
  [ "${#line1}" -lt 400 ]
}

@test "readonly-path readonly ignores the probe's facts" {
  local text baseline line1
  text=$(readonly_path_text readonly path=/r/x readfile=/w/build.log \
    merge=1 partial=1 recover=checkout repo=/r target=main match=a)
  baseline=$(readonly_path_text readonly path=/r/x)
  [ "$text" = "$baseline" ]
  line1=$(line_one "$text")
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  [ "$line1" = '`/r/x` is not writable outside the sandbox either; this is not a sandbox effect. Unsandboxing will not help: write somewhere writable, or ask before changing its permissions.' ]
  assert_quiet "$text"
}

@test "readonly-path compositions drop the old restore wording and remove nothing" {
  # Each old phrase is paired with the phrase that replaces it over the same
  # text, so an empty or failed composition cannot pass as clean.
  local combined
  combined="$(readonly_path_text writable path=/r/x)
$(readonly_path_text writable path=/r/x readfile=/w/build.log)
$(readonly_path_text writable path=/r/.claude/settings.json)
$(readonly_path_text writable path=/r/x merge=1 partial=1 recover=checkout repo=/r target=main match=a match=b)
$(readonly_path_text writable path=/r/x merge=1 partial=1)
$(readonly_path_text nopath merge=1 partial=1 recover=merge repo=/r target=main)"
  printf '%s' "$combined" | grep -qF 'Before any re-run'
  text_lacks "$combined" 'The merge or checkout left'
  text_lacks "$combined" 'HEAD unmoved'
  text_lacks "$combined" 'restore'
  text_lacks "$combined" 'they match'
  printf '%s' "$combined" | grep -qF 'Re-run the command that wrote'
  # Status 1 exactly, so an erroring grep cannot read as "no match".
  run bash -c 'printf "%s" "$1" | grep -qiE "(^|[^[:alpha:]])rm |remove|delete"' \
    _ "$combined"
  [ "$status" -eq 1 ]
}
