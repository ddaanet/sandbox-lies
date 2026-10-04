#!/usr/bin/env bats
# lib/probes-readonly.sh's probe_readonly_path: the fact-table members
# (docs/references/readonly-path.md, Probe facts table) that
# tests/probes-readonly-facts.bats and tests/probes-readonly-pins.bats leave
# unpinned (review Major 6). Each case runs the probe on a `writable` refusal
# and asserts exact lines. A negative assertion is paired, in the same case,
# with the positive form that proves the fault under test is the only thing
# withholding the line. Sections: merge subcommands, target= and match= for
# switch, readfile names, readfile exclusions, and the readfile operand rule
# (outline D4, review code m-2).

ROOT="${BATS_TEST_DIRNAME}/.."

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs
load helpers/git-env
load helpers/probes

setup() {
  source "$ROOT/lib/probes.sh"
}

# assert_no_readfile — the last probe run exited 0 with nothing on stderr,
# answered writable (so an empty output cannot pass) and printed no readfile=
# line.
assert_no_readfile() {
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = writable ]
  run ! grep -q '^readfile=' <<<"$output"
}

# --- merge subcommands -----------------------------------------------------

# switch, rebase and cherry-pick each open a merge segment, so each gives
# merge=1; none of the three is in the merge/pull/checkout trio alone.
@test "git switch, git rebase and git cherry-pick each give merge=1" {
  local text sub
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'$BATS_TEST_TMPDIR/x'")

  for sub in switch rebase cherry-pick; do
    run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
      "git $sub feat" "$text"
    [ "$status" -eq 0 ]
    [ -z "$stderr" ]
    [ "${output%%$'\n'*}" = writable ]
    printf '%s\n' "$output" | grep -qxF 'merge=1'
  done
}

# --- target= and match= for switch -----------------------------------------

# switch is one of the three subcommands target= is attempted after; the
# refused path is <repo>/a, so the search starts there and finds the repo.
@test "git switch feat in a scratch repo gives target=feat and match=a" {
  local repo="$BATS_TEST_TMPDIR/scratch repo" text
  make_scratch_repo "$repo"
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'$repo/a'")

  run_probe_command probe_readonly_path false "$repo" 'git switch feat' \
    "$text"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  printf '%s\n' "$output" | grep -qxF 'merge=1'
  printf '%s\n' "$output" | grep -qxF 'target=feat'
  printf '%s\n' "$output" | grep -qxF 'match=a'
}

# --- readfile names --------------------------------------------------------

# *.out and *.err are command-output names beside *.log and *.output.
@test "cat build.out and tail run.err give readfile" {
  local text
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'$BATS_TEST_TMPDIR/x'")

  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    'cat build.out' "$text"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  printf '%s\n' "$output" | grep -qxF 'readfile=build.out'

  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    'tail run.err' "$text"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  printf '%s\n' "$output" | grep -qxF 'readfile=run.err'
}

# --- readfile exclusions ---------------------------------------------------

# Each writing option on a tool that otherwise reads: the plain reader form
# gives readfile= (so the tool is a reader and the file name is a candidate),
# the option form gives none. The option's own arm of the case in
# _readonly_readfile_arg is the only thing withholding it: sort -o is not
# caught by the `-[!-]*o*` arm (it needs a character between - and o), and
# --output, -i and --include share no arm with another form.
@test "sort -o out.log withholds readfile, plain sort gives it" {
  local text
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'$BATS_TEST_TMPDIR/x'")

  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    'sort in.log' "$text"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -qxF 'readfile=in.log'

  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    'sort -o out.log in.log' "$text"
  assert_no_readfile
}

@test "sort --output=out.log withholds readfile, plain sort gives it" {
  local text
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'$BATS_TEST_TMPDIR/x'")

  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    'sort in.log' "$text"
  printf '%s\n' "$output" | grep -qxF 'readfile=in.log'

  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    'sort --output=out.log in.log' "$text"
  assert_no_readfile
}

@test "awk -i inplace withholds readfile, plain awk gives it" {
  local text
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'$BATS_TEST_TMPDIR/x'")

  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    'awk 1 x.log' "$text"
  printf '%s\n' "$output" | grep -qxF 'readfile=x.log'

  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    'awk -i inplace 1 x.log' "$text"
  assert_no_readfile
}

@test "awk --include withholds readfile, plain awk gives it" {
  local text
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'$BATS_TEST_TMPDIR/x'")

  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    'awk 1 x.log' "$text"
  printf '%s\n' "$output" | grep -qxF 'readfile=x.log'

  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    'awk --include=lib.awk 1 x.log' "$text"
  assert_no_readfile
}

# --- readfile operand rule -------------------------------------------------

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

# --- BSD tools -------------------------------------------------------------

# One case per kind of fact above through BSD grep, sed, stat and wc (NFR-2).
@test "the member facts survive BSD grep, sed, stat and wc" {
  local repo="$BATS_TEST_TMPDIR/scratch repo" bsd="$BATS_TEST_TMPDIR/bsdtools"
  local text
  make_scratch_repo "$repo"
  make_bsd_stubs "$bsd" grep sed stat wc

  text=$(readonly_path_text fire-readonly-path-cp-tmp "'$repo/a'")
  PATH="$bsd:$PATH" run_probe_command probe_readonly_path false "$repo" \
    'git switch feat' "$text"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  printf '%s\n' "$output" | grep -qxF 'merge=1'
  printf '%s\n' "$output" | grep -qxF 'target=feat'
  printf '%s\n' "$output" | grep -qxF 'match=a'

  text=$(readonly_path_text fire-readonly-path-cp-tmp "'$BATS_TEST_TMPDIR/x'")
  PATH="$bsd:$PATH" run_probe_command probe_readonly_path false \
    "$BATS_TEST_TMPDIR" 'cat build.out' "$text"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  printf '%s\n' "$output" | grep -qxF 'readfile=build.out'

  PATH="$bsd:$PATH" run_probe_command probe_readonly_path false \
    "$BATS_TEST_TMPDIR" 'sort -o out.log in.log' "$text"
  assert_no_readfile
}
