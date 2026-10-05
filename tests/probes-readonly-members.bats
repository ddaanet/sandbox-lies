#!/usr/bin/env bats
# lib/probes-readonly.sh's probe_readonly_path: the fact-table members
# (docs/references/readonly-path.md, Probe facts table) that
# tests/probes-readonly-facts.bats and tests/probes-readonly-pins.bats leave
# unpinned (review Major 6). Each case runs the probe on a `writable` refusal
# and asserts exact lines. A negative assertion is paired, in the same case,
# with the positive form that proves the fault under test is the only thing
# withholding the line. Sections: merge subcommands, target= and match= for
# switch, readfile names and readfile exclusions. The readfile operand rule
# (outline D4) is in tests/probes-readonly-operands.bats.

ROOT="${BATS_TEST_DIRNAME}/.."

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs
load helpers/git-env
load helpers/probes

setup() {
  source "$ROOT/lib/probes.sh"
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
@test "git switch feat in a scratch repo gives target=feat and an absolute match=" {
  local repo="$BATS_TEST_TMPDIR/scratch repo" text
  make_scratch_repo "$repo"
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'$repo/a'")

  run_probe_command probe_readonly_path false "$repo" 'git switch feat' \
    "$text"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  printf '%s\n' "$output" | grep -qxF 'merge=1'
  printf '%s\n' "$output" | grep -qxF 'target=feat'
  printf '%s\n' "$output" | grep -qxF "match=$repo/a"
}

# The name is absolute: <repo>/<name>, the repository root joined on, never
# the cwd <repo>/sub nor the refused path's directory (<repo>/sub for the
# second refused path). merge is one of the three subcommands target= is
# attempted after. a, b and `e f` sit at feat's blob and differ from HEAD; c
# is edited to a third value and d equals HEAD. The match= lines are compared
# whole, so a bare name printed beside the absolute one fails too.
@test "match= names are absolute from a subdirectory cwd" {
  local repo="$BATS_TEST_TMPDIR/scratch repo" text refused expected
  make_scratch_repo "$repo"
  mkdir "$repo/sub"
  expected=$(printf 'match=%s\n' "$repo/a" "$repo/b" "$repo/e f")

  for refused in "$repo/a" "$repo/sub/x"; do
    text=$(readonly_path_text fire-readonly-path-cp-tmp "'$refused'")
    run_probe_command probe_readonly_path false "$repo/sub" \
      'git merge feat' "$text"

    [ "$status" -eq 0 ]
    [ -z "$stderr" ]
    [ "${output%%$'\n'*}" = writable ]
    [ "$(printf '%s\n' "$output" | grep '^match=')" = "$expected" ]
  done
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
  printf '%s\n' "$output" | grep -qxF "match=$repo/a"

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
