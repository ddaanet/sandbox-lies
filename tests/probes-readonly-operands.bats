#!/usr/bin/env bats
# lib/probes-readonly.sh's probe_readonly_path: the readfile operand rule
# (outline D4, plans/sandbox-lies-review-fixes/outline.md;
# docs/references/readonly-path.md, Probe facts table). A word opening with -
# is an option, never an input file, and the first non-option operand of grep,
# sed or awk is its pattern or program, not an input. Each case runs the probe
# on a `writable` refusal and asserts exact lines; a negative assertion is
# paired, in the same case, with the positive form that proves the rule under
# test is the only thing withholding the line.

ROOT="${BATS_TEST_DIRNAME}/.."

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs
load helpers/git-env
load helpers/probes

setup() {
  source "$ROOT/lib/probes.sh"
}

# A word opening with - is an option, never an input file: the --include glob
# matches *.log but is not the file grep reads.
@test "grep --include=*.log gives the operand, never the option" {
  local text
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'$BATS_TEST_TMPDIR/x'")

  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    'grep --include=*.log pat build.log' "$text"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = writable ]
  printf '%s\n' "$output" | grep -qxF 'readfile=build.log'
  run ! grep -q '^readfile=-' <<<"$output"
}

# The single-dash form: -vout=run.log is awk's assignment option, not its
# input, so in.err is the candidate. 1 is awk's program and not a log name,
# so this holds with or without the pattern-operand rule.
@test "awk -vout=run.log gives the operand, never the short option" {
  local text
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'$BATS_TEST_TMPDIR/x'")

  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    'awk -vout=run.log 1 in.err' "$text"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = writable ]
  printf '%s\n' "$output" | grep -qxF 'readfile=in.err'
  run ! grep -q '^readfile=-' <<<"$output"
}

# The same option with no log-named operand: pat and . (the tree grep -r
# walks) are not output names, so the option word was the only candidate.
@test "grep -r --include=*.log pat . gives no readfile" {
  local text
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'$BATS_TEST_TMPDIR/x'")

  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    'grep -r --include=*.log pat .' "$text"
  assert_no_readfile
}

# An option word glued to an input redirection: the tokenizer keeps -l<build.log
# one word, and the < still reads build.log, so the option rule must not drop
# it.
@test "wc -l<build.log gives the redirected name despite the leading option" {
  local text
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'$BATS_TEST_TMPDIR/x'")

  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    'wc -l<build.log' "$text"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = writable ]
  printf '%s\n' "$output" | grep -qxF 'readfile=build.log'
}

# The first non-option operand of grep is its pattern, not an input file, even
# when it is shaped like a log name.
@test "grep x.log y.out gives the input, never the pattern" {
  local text
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'$BATS_TEST_TMPDIR/x'")

  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    'grep x.log y.out' "$text"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = writable ]
  printf '%s\n' "$output" | grep -qxF 'readfile=y.out'
  run ! grep -qxF 'readfile=x.log' <<<"$output"
}

# sed's first non-option operand is its program; s/a/b/x.log ends in .log but
# is a substitution, not a file.
@test "sed s/a/b/x.log in.out gives the input, never the program" {
  local text
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'$BATS_TEST_TMPDIR/x'")

  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    'sed s/a/b/x.log in.out' "$text"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = writable ]
  printf '%s\n' "$output" | grep -qxF 'readfile=in.out'
  run ! grep -qxF 'readfile=s/a/b/x.log' <<<"$output"
}

# awk's first non-option operand is its program.
@test "awk x.log in.err gives the input, never the program" {
  local text
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'$BATS_TEST_TMPDIR/x'")

  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    'awk x.log in.err' "$text"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = writable ]
  printf '%s\n' "$output" | grep -qxF 'readfile=in.err'
  run ! grep -qxF 'readfile=x.log' <<<"$output"
}

# Guard, passes before the rule: the program s/a/b/ is no log name, so in.log
# is the candidate with or without skipping the program operand.
@test "sed s/a/b/ in.log still gives the input" {
  local text
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'$BATS_TEST_TMPDIR/x'")

  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    'sed s/a/b/ in.log' "$text"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = writable ]
  printf '%s\n' "$output" | grep -qxF 'readfile=in.log'
}

# The pattern is the first non-option operand, not the word after grep: an
# option ahead of it leaves x.log in the pattern's place.
@test "grep -i x.log y.out gives the input, never the pattern after an option" {
  local text
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'$BATS_TEST_TMPDIR/x'")

  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    'grep -i x.log y.out' "$text"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = writable ]
  printf '%s\n' "$output" | grep -qxF 'readfile=y.out'
  run ! grep -qxF 'readfile=x.log' <<<"$output"
}

# Only the pattern is skipped: of two inputs after it, the first is the
# candidate, so taking the last log-shaped word is not the rule.
@test "grep x.log a.out b.err gives the first input after the pattern" {
  local text
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'$BATS_TEST_TMPDIR/x'")

  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    'grep x.log a.out b.err' "$text"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = writable ]
  printf '%s\n' "$output" | grep -qxF 'readfile=a.out'
  run ! grep -qxF 'readfile=b.err' <<<"$output"
}

# The pattern is per segment: sed's program in the first segment does not use
# up grep's pattern in the second.
@test "sed s/a/b/ in.txt | grep x.log y.out gives grep's input" {
  local text
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'$BATS_TEST_TMPDIR/x'")

  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    'sed s/a/b/ in.txt | grep x.log y.out' "$text"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = writable ]
  printf '%s\n' "$output" | grep -qxF 'readfile=y.out'
  run ! grep -qxF 'readfile=x.log' <<<"$output"
}

# The word after a lone < is the name grep reads on stdin, never the pattern:
# y.out is the pattern here.
@test "grep < x.log y.out gives the redirected name, never the pattern" {
  local text
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'$BATS_TEST_TMPDIR/x'")

  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    'grep < x.log y.out' "$text"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = writable ]
  printf '%s\n' "$output" | grep -qxF 'readfile=x.log'
  run ! grep -qxF 'readfile=y.out' <<<"$output"
}

# A pattern holding a quoted newline, or a < past its first character, is
# still the pattern, so y.out after it is the input.
@test "a pattern holding a newline or an inner < is still the pattern" {
  local text
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'$BATS_TEST_TMPDIR/x'")

  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    $'grep \'a\nb\' y.out' "$text"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = writable ]
  printf '%s\n' "$output" | grep -qxF 'readfile=y.out'

  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    "grep 'a<b' y.out" "$text"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = writable ]
  printf '%s\n' "$output" | grep -qxF 'readfile=y.out'
}

# -e carries the pattern in its own word (-epat), so the first operand is
# input; x.log is that input and not a pattern.
@test "grep -epat x.log gives the input, the -e word being the pattern" {
  local text
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'$BATS_TEST_TMPDIR/x'")

  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    'grep -epat x.log' "$text"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = writable ]
  printf '%s\n' "$output" | grep -qxF 'readfile=x.log'
}

# A separate -e takes the next word as its argument, so s/c/d/x.log is a
# program, not a log, and in.out after the options is the input.
@test "sed -e s/a/b/ -e s/c/d/x.log in.out gives the input, never an -e argument" {
  local text
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'$BATS_TEST_TMPDIR/x'")

  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    'sed -e s/a/b/ -e s/c/d/x.log in.out' "$text"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = writable ]
  printf '%s\n' "$output" | grep -qxF 'readfile=in.out'
  run ! grep -qxF 'readfile=s/c/d/x.log' <<<"$output"
}

# -f names the program file, so prog.log is awk's program and in.err, the
# first operand, is the input.
@test "awk -f prog.log in.err gives the input, never the program file" {
  local text
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'$BATS_TEST_TMPDIR/x'")

  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    'awk -f prog.log in.err' "$text"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = writable ]
  printf '%s\n' "$output" | grep -qxF 'readfile=in.err'
  run ! grep -qxF 'readfile=prog.log' <<<"$output"

  # The separate form above passes on a pattern skip that eats prog.log; the
  # glued form leaves nothing for that skip to eat but the input.
  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    'awk -fprog.log in.err' "$text"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = writable ]
  printf '%s\n' "$output" | grep -qxF 'readfile=in.err'
  run ! grep -qxF 'readfile=prog.log' <<<"$output"

  # A second separate -f: that skip eats lib.awk only, so prog.log is withheld
  # only when the word after each -f is its argument.
  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    'awk -f lib.awk -f prog.log in.err' "$text"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = writable ]
  printf '%s\n' "$output" | grep -qxF 'readfile=in.err'
  run ! grep -qxF 'readfile=prog.log' <<<"$output"
}

# The pattern role is per segment. grep -i has no operand, so its role is
# still unconsumed when the segment ends (-i is neither -e nor -f); the
# reset keeps it from taking tail's run.log. Passes before the slice's code.
@test "grep -i | tail run.log leaves the pattern role behind in its segment" {
  local text
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'$BATS_TEST_TMPDIR/x'")

  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    'grep -i | tail run.log' "$text"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = writable ]
  printf '%s\n' "$output" | grep -qxF 'readfile=run.log'
}

# uniq's second operand is the file it writes, so a segment holding one is a
# writer (outline D4), as sort -o is. uniq in.log is the positive run, and
# uniq in.log out.txt differs from it only in the second operand: in.log is
# withheld because the segment writes, not because out.txt is skipped. An
# option is no operand, so uniq -c in.log is still a reader, and so is
# uniq -c in.log 2>&1, a descriptor duplication being no operand. A lone -
# (stdin), the text ahead of a <, and a word after -- are operands.
@test "uniq with a second operand is a writer, uniq in.log is not" {
  local text cmd
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'$BATS_TEST_TMPDIR/x'")

  for cmd in 'uniq in.log' 'uniq -c in.log' 'uniq -c in.log 2>&1'; do
    run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
      "$cmd" "$text"
    [ "$status" -eq 0 ]
    [ -z "$stderr" ]
    [ "${output%%$'\n'*}" = writable ]
    printf '%s\n' "$output" | grep -qxF 'readfile=in.log'
  done

  for cmd in 'uniq in.log out.txt' 'uniq in.txt out.log' 'uniq - out.log' \
    'uniq x<in.log out.log' 'uniq -- -x.txt out.log'; do
    run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
      "$cmd" "$text"
    assert_no_readfile
  done
}

# A < redirection in the argument slot of a separate -e is still a redirection:
# in.log is read, and pat.log, the word after it, is -e's pattern, not input.
@test "grep -e <in.log pat.log gives the redirected name, never the pattern" {
  local text
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'$BATS_TEST_TMPDIR/x'")

  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    'grep -e <in.log pat.log' "$text"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = writable ]
  printf '%s\n' "$output" | grep -qxF 'readfile=in.log'
  run ! grep -qxF 'readfile=pat.log' <<<"$output"

  # in.log above is the first candidate, so a < word that ended -e's argument
  # role would leave pat.log as input unseen. With no log name behind the <,
  # y.out is the input only while pat.log stays -e's argument.
  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    'grep -e <in.txt pat.log y.out' "$text"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = writable ]
  printf '%s\n' "$output" | grep -qxF 'readfile=y.out'
  run ! grep -qxF 'readfile=pat.log' <<<"$output"
}

# --- BSD tools -------------------------------------------------------------

# A slice-1 and a slice-2 case through BSD grep, sed, stat and wc (NFR-2).
@test "the operand rule survives BSD grep, sed, stat and wc" {
  local bsd="$BATS_TEST_TMPDIR/bsdtools" text
  make_bsd_stubs "$bsd" grep sed stat wc
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'$BATS_TEST_TMPDIR/x'")

  PATH="$bsd:$PATH" run_probe_command probe_readonly_path false \
    "$BATS_TEST_TMPDIR" 'grep --include=*.log pat build.log' "$text"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  printf '%s\n' "$output" | grep -qxF 'readfile=build.log'
  run ! grep -q '^readfile=-' <<<"$output"

  PATH="$bsd:$PATH" run_probe_command probe_readonly_path false \
    "$BATS_TEST_TMPDIR" 'sed s/a/b/x.log in.out' "$text"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  printf '%s\n' "$output" | grep -qxF 'readfile=in.out'
  run ! grep -qxF 'readfile=s/a/b/x.log' <<<"$output"
}
