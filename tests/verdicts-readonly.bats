#!/usr/bin/env bats
# lib/verdicts.sh's verdict_readonly_path: the writable/nopath tail composed
# from the probe's key=value facts on stdin (readfile=, path=, merge=1,
# target=, match=), transcribed from docs/references/detectors.md's
# readonly-path Verdicts tail and merge-clause composition (Item 8.0 slice
# 2). New file: tests/verdicts.bats and tests/hook-locks.bats already sit at
# the 400-line cap.

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

@test "readonly-path merge with target and match restores the named files then acts" {
  local text line1 line2
  text=$(readonly_path_text writable path=/r/x merge=1 target=main match=a match=b)
  line1=$(printf '%s\n' "$text" | sed -n '1p')
  line2=$(printf '%s\n' "$text" | sed -n '2p')
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  [ "$line1" = '`/r/x` is writable outside the sandbox, whose allowlist refused it. The merge or checkout left files at the target with HEAD unmoved, blocking a re-run: restore `a`, `b` from HEAD — they match `main` —, then re-run the whole call with `dangerouslyDisableSandbox: true`.' ]
  [ "$line2" = 'read-only — sandbox allowlist, writable outside' ]
  [ "${#line1}" -lt 400 ]
  run bash -c 'printf "%s\n" "$1" | bash "$2"' _ "$text" "$MATCHERS"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "readonly-path merge alone restores the written files then acts" {
  local text line1
  text=$(readonly_path_text writable path=/r/x merge=1)
  line1=$(printf '%s\n' "$text" | sed -n '1p')
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  [ "$line1" = '`/r/x` is writable outside the sandbox, whose allowlist refused it. The merge or checkout left the files it wrote with HEAD unmoved, blocking a re-run: restore them from HEAD, then re-run the whole call with `dangerouslyDisableSandbox: true`.' ]
  [ "${#line1}" -lt 400 ]
  run bash -c 'printf "%s\n" "$1" | bash "$2"' _ "$text" "$MATCHERS"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "readonly-path merge clause leads lowercase into whichever act the facts select" {
  local text line1
  text=$(readonly_path_text writable path=/r/x merge=1 readfile=/w/b.log)
  line1=$(printf '%s\n' "$text" | sed -n '1p')
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  [ "$line1" = '`/r/x` is writable outside the sandbox, whose allowlist refused it. The merge or checkout left the files it wrote with HEAD unmoved, blocking a re-run: restore them from HEAD, then re-run the command that wrote `/w/b.log`.' ]
  [ "${#line1}" -lt 400 ]
  run bash -c 'printf "%s\n" "$1" | bash "$2"' _ "$text" "$MATCHERS"
  [ "$status" -eq 1 ]
  [ -z "$output" ]

  text=$(readonly_path_text writable path=/r/.claude/settings.json merge=1 target=t match=a)
  line1=$(printf '%s\n' "$text" | sed -n '1p')
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  [ "$line1" = '`/r/.claude/settings.json` is writable outside the sandbox, whose allowlist refused it. The merge or checkout left files at the target with HEAD unmoved, blocking a re-run: restore `a` from HEAD — they match `t` —, then write `.claude/settings.json` through the `update-config` skill.' ]
  [ "${#line1}" -lt 400 ]
  run bash -c 'printf "%s\n" "$1" | bash "$2"' _ "$text" "$MATCHERS"
  [ "$status" -eq 1 ]
  [ -z "$output" ]

  text=$(readonly_path_text nopath merge=1 target=t match=a)
  line1=$(printf '%s\n' "$text" | sed -n '1p')
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  [ "$line1" = "The sandbox's write allowlist most likely refused this write. The merge or checkout left files at the target with HEAD unmoved, blocking a re-run: restore \`a\` from HEAD — they match \`t\` —, then re-run the whole call with \`dangerouslyDisableSandbox: true\`." ]
  [ "${#line1}" -lt 400 ]
  run bash -c 'printf "%s\n" "$1" | bash "$2"' _ "$text" "$MATCHERS"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "readonly-path merge with target and no match states the act alone" {
  local text baseline line1 baseline1
  text=$(readonly_path_text writable path=/r/x merge=1 target=main)
  baseline=$(readonly_path_text writable path=/r/x)
  line1=$(printf '%s\n' "$text" | sed -n '1p')
  baseline1=$(printf '%s\n' "$baseline" | sed -n '1p')
  [ "$line1" = "$baseline1" ]
  text_lacks "$line1" 'restore'
  [ "${#line1}" -lt 400 ]
  run bash -c 'printf "%s\n" "$1" | bash "$2"' _ "$text" "$MATCHERS"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "readonly-path merge match list caps at five names then and N more" {
  # detectors.md fixes the five names, `and N more` after them and the rest
  # of the clause, but not whether a comma precedes `and`: both joins pass.
  local text line1 head tail
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  head='`/r/x` is writable outside the sandbox, whose allowlist refused it. The merge or checkout left files at the target with HEAD unmoved, blocking a re-run: restore `a`, `b`, `c`, `d`, `e`'
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  tail='from HEAD — they match `main` —, then re-run the whole call with `dangerouslyDisableSandbox: true`.'

  text=$(readonly_path_text writable path=/r/x merge=1 target=main \
    match=a match=b match=c match=d match=e match=f match=g)
  line1=$(printf '%s\n' "$text" | sed -n '1p')
  [ "$line1" = "$head and 2 more $tail" ] || [ "$line1" = "$head, and 2 more $tail" ]
  [ "${#line1}" -lt 400 ]
  run bash -c 'printf "%s\n" "$1" | bash "$2"' _ "$text" "$MATCHERS"
  [ "$status" -eq 1 ]
  [ -z "$output" ]

  # Exactly five: every name, and no `and N more`.
  text=$(readonly_path_text writable path=/r/x merge=1 target=main \
    match=a match=b match=c match=d match=e)
  line1=$(printf '%s\n' "$text" | sed -n '1p')
  [ "$line1" = "$head $tail" ]
  text_lacks "$line1" 'more'
}

@test "readonly-path longest composition stays under 400 with one-character values" {
  # The longest act (update-config) behind the longest clause (a capped
  # match list): the prose's own length, values at one character.
  local line1
  line1=$(readonly_path_text writable path=/.claude/settings.json merge=1 \
    target=t match=a match=b match=c match=d match=e match=f match=g \
    | sed -n '1p')
  printf '%s' "$line1" | grep -qF 'and 2 more'
  printf '%s' "$line1" | grep -qF 'update-config'
  [ "${#line1}" -lt 400 ]
}

@test "readonly-path readonly ignores the probe's facts" {
  local text baseline line1
  text=$(readonly_path_text readonly path=/r/x readfile=/w/build.log \
    merge=1 target=main match=a)
  baseline=$(readonly_path_text readonly path=/r/x)
  [ "$text" = "$baseline" ]
  line1=$(printf '%s\n' "$text" | sed -n '1p')
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  [ "$line1" = '`/r/x` is not writable outside the sandbox either; this is not a sandbox effect. Unsandboxing will not help: write somewhere writable, or ask before changing its permissions.' ]
  [ "${#line1}" -lt 400 ]
  run bash -c 'printf "%s\n" "$1" | bash "$2"' _ "$text" "$MATCHERS"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "readonly-path compositions drop the old tail wording and remove nothing" {
  # Each old phrase is paired with the phrase that replaces it over the same
  # text, so an empty or failed composition cannot pass as clean.
  local combined
  combined="$(readonly_path_text writable path=/r/x)
$(readonly_path_text writable path=/r/x readfile=/w/build.log)
$(readonly_path_text writable path=/r/.claude/settings.json)
$(readonly_path_text writable path=/r/x merge=1 target=main match=a match=b)
$(readonly_path_text writable path=/r/x merge=1)
$(readonly_path_text nopath)
$(readonly_path_text nopath merge=1 target=main match=a)"
  printf '%s' "$combined" | grep -qF 'The merge or checkout left'
  text_lacks "$combined" 'If a merge'
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  printf '%s' "$combined" | grep -qF '— they match `main` —'
  text_lacks "$combined" 'once they match'
  printf '%s' "$combined" | grep -qF 'Re-run the command that wrote'
  text_lacks "$combined" 'if it only read'
  # D-7 over the merge clauses, which restore and never remove: status 1
  # exactly, so an erroring grep cannot read as "no match".
  printf '%s' "$combined" | grep -qF 'restore them from HEAD'
  run bash -c 'printf "%s" "$1" | grep -qiE "(^|[^[:alpha:]])rm |remove|delete"' \
    _ "$combined"
  [ "$status" -eq 1 ]
}
