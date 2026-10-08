#!/usr/bin/env bats
# lib/probes-readonly.sh's probe_readonly_path: a readfile candidate holding
# *, ?, [, { or $ is a pattern or an expansion, never a name the command wrote,
# so it is skipped, quoted or not (plans/sandbox-lies-review-fixes-2/outline.md
# Q4, Item 2.1). Each negative is paired, in the same case, with the same
# command shape minus the metacharacter, which must print readfile=: only the
# skip rule can then be what withholds the line.

ROOT="${BATS_TEST_DIRNAME}/.."

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs
load helpers/git-env
load helpers/probes

setup() {
  source "$ROOT/lib/probes.sh"
}

# probe_for <command> — the probe on a writable refusal, as the operands suite
# runs it.
probe_for() {
  local text
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'$BATS_TEST_TMPDIR/x'")
  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" "$1" "$text"
}

@test "grep -l pat *.log gives no readfile for the glob" {
  probe_for 'grep -l pat x.log'
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -qxF 'readfile=x.log'

  probe_for 'grep -l pat *.log'
  assert_no_readfile
}

@test "cat \$OUT.log gives no readfile for the expansion" {
  probe_for 'cat OUT.log'
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -qxF 'readfile=OUT.log'

  # shellcheck disable=SC2016 # the literal $OUT is the command's text
  probe_for 'cat $OUT.log'
  assert_no_readfile
}

@test "cat run?.log gives no readfile for the ? glob" {
  probe_for 'cat run1.log'
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -qxF 'readfile=run1.log'

  probe_for 'cat run?.log'
  assert_no_readfile
}

@test "cat run[12].log gives no readfile for the [ glob" {
  probe_for 'cat run1.log'
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -qxF 'readfile=run1.log'

  probe_for 'cat run[12].log'
  assert_no_readfile
}

@test "cat {a,b}.log gives no readfile for the brace expansion" {
  probe_for 'cat a.log'
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -qxF 'readfile=a.log'

  probe_for 'cat {a,b}.log'
  assert_no_readfile
}

@test "cat x.log still gives readfile=x.log" {
  probe_for 'cat x.log'
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = writable ]
  printf '%s\n' "$output" | grep -qxF 'readfile=x.log'
}

# pat is grep's pattern, so *.log is its first input and x.err its second:
# skipping the glob must leave the later literal as the candidate.
@test "a skipped glob does not hide a later literal candidate" {
  probe_for 'grep pat a.log x.err'
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -qxF 'readfile=a.log'

  probe_for 'grep pat *.log x.err'
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = writable ]
  [ "$(grep '^readfile=' <<<"$output")" = readfile=x.err ]
}

# A command holding $ is not rejected whole: only the word holding it is
# skipped, so the literal after it is still the candidate.
@test "a skipped \$ expansion does not hide a later literal candidate" {
  probe_for 'cat OUT.log x.err'
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -qxF 'readfile=OUT.log'

  # shellcheck disable=SC2016 # the literal $OUT is the command's text
  probe_for 'cat $OUT.log x.err'
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = writable ]
  [ "$(grep '^readfile=' <<<"$output")" = readfile=x.err ]
}

# The skip applies to the candidate only. A metacharacter in grep's pattern
# must neither withhold readfile= nor shift the pattern role onto x.log.
@test "a metacharacter in grep's pattern leaves readfile=x.log" {
  probe_for "grep 'err.*\$' x.log"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = writable ]
  [ "$(grep '^readfile=' <<<"$output")" = readfile=x.log ]
}

# The tokenizer removes quotes before the scan sees the word, so a quoted
# '*.log' is skipped like a bare one: the safe side the outline's Q4 accepts.
@test "a quoted '*.log' is skipped too" {
  probe_for "grep -l pat 'x.log'"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -qxF 'readfile=x.log'

  probe_for "grep -l pat '*.log'"
  assert_no_readfile
}

# In a word glued to <, the candidate is the name after the last <, and only
# that name is tested: a glob or $ in grep's pattern ahead of the < must not
# withhold the redirected name.
@test "a glob or \$ ahead of a glued < keeps the redirected name" {
  probe_for "grep 'err.*'<x.log"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = writable ]
  [ "$(grep '^readfile=' <<<"$output")" = readfile=x.log ]

  # shellcheck disable=SC2016 # the literal $p is the command's text
  probe_for 'grep "$p"<x.log'
  [ "$status" -eq 0 ]
  [ "$(grep '^readfile=' <<<"$output")" = readfile=x.log ]
}

@test "a glob or \$ after < is skipped, lone or glued" {
  probe_for 'cat <x.log'
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -qxF 'readfile=x.log'

  probe_for 'cat <*.log'
  assert_no_readfile

  probe_for 'wc -l<x.log'
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -qxF 'readfile=x.log'

  # shellcheck disable=SC2016 # the literal $x is the command's text
  probe_for 'wc -l<$x.log'
  assert_no_readfile
}

# The skip and the later-literal rule through BSD grep, sed, stat and wc
# (NFR-2), as tests/probes-readonly-operands.bats re-runs its operand rule.
@test "the glob skip survives BSD grep, sed, stat and wc" {
  local bsd="$BATS_TEST_TMPDIR/bsdtools" text
  make_bsd_stubs "$bsd" grep sed stat wc
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'$BATS_TEST_TMPDIR/x'")

  PATH="$bsd:$PATH" run_probe_command probe_readonly_path false \
    "$BATS_TEST_TMPDIR" 'grep pat a.log x.err' "$text"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  printf '%s\n' "$output" | grep -qxF 'readfile=a.log'

  PATH="$bsd:$PATH" run_probe_command probe_readonly_path false \
    "$BATS_TEST_TMPDIR" 'grep pat *.log x.err' "$text"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = writable ]
  [ "$(grep '^readfile=' <<<"$output")" = readfile=x.err ]
}
