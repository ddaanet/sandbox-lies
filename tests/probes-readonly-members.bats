#!/usr/bin/env bats
# lib/probes-readonly.sh's probe_readonly_path: the fact-table members
# (docs/references/readonly-path.md, Probe facts table) that
# tests/probes-readonly-facts.bats and tests/probes-readonly-pins.bats leave
# unpinned (review Major 6), and match='s absolute names (outline D3). Each
# case runs the probe on a `writable` refusal, or a nopath one where it says
# so, and asserts exact lines. A negative assertion is paired, in the same
# case, with the positive form that proves the fault under test is the only
# thing withholding the line. Sections: merge subcommands, target= and
# match=, readfile names and readfile exclusions. The readfile operand rule
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

# --- target= and match= ----------------------------------------------------

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

# A cwd with a trailing slash still gives <repo>/<name>, never <repo>//<name>:
# _readonly_git_dir strips the slashes before its .git walk. Under nopath the
# search starts at the cwd, so <repo>/ is the start. The match= lines are
# compared whole, so a doubled slash on any of them fails.
@test "match= names carry no doubled slash from a cwd with a trailing slash" {
  local repo="$BATS_TEST_TMPDIR/scratch repo" text expected
  make_scratch_repo "$repo"
  text=$(readonly_path_text fire-readonly-path-cp-tmp "")
  expected=$(printf 'match=%s\n' "$repo/a" "$repo/b" "$repo/e f")

  run_probe_command probe_readonly_path false "$repo/" 'git merge feat' \
    "$text"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = nopath ]
  [ "$(printf '%s\n' "$output" | grep '^match=')" = "$expected" ]
}

# A match= line carries the repository root, so a newline in the root's name
# would split it and forge the key line after the newline (here readfile=).
# Under nopath the root is the cwd's: a refused path comes off one line of
# the text and cannot hold a newline. The sibling named with a blank where
# the other has the newline gives the full fact list, so only the newline
# withholds target= and match=; both outputs are compared whole.
@test "a repository root holding a newline gives no target= or match=" {
  local good="$BATS_TEST_TMPDIR/r readfile=x"
  local bad="$BATS_TEST_TMPDIR/r"$'\n'"readfile=x" text expected
  make_scratch_repo "$good"
  make_scratch_repo "$bad"
  text=$(readonly_path_text fire-readonly-path-cp-tmp "")

  run_probe_command probe_readonly_path false "$good" 'git merge feat' \
    "$text"
  expected=$(printf '%s\n' nopath merge=1 target=feat "match=$good/a" \
    "match=$good/b" "match=$good/e f")
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "$output" = "$expected" ]

  run_probe_command probe_readonly_path false "$bad" 'git merge feat' \
    "$text"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "$output" = $'nopath\nmerge=1' ]
}

# A relative refused path is joined onto the payload cwd, so a newline in the
# cwd's name would split the path= line and forge the key line after the
# newline (here readfile=). path= is printed in printf %q form, so the path
# stays one line: the outcome is the real one (writable) and path= is one
# $'...' line with the newline written \n. The sibling named with a blank
# where the other has the newline gives writable and the backslash form, so an
# encoder escaping only blanks, or only the newline, fails; the absolute
# refused path $good/a under the newline cwd gives the same as the sibling, so
# a guard keyed on the cwd rather than the resolved path fails. The newline
# case runs first, so a failure shows its own assertion rather than the
# blank's. All three outputs are compared whole; cat build.out gives
# readfile=build.out under each. The literals interpolate BATS_TEST_TMPDIR as
# itself, which the first line pins.
@test "a resolved refused path holding a newline gives writable and one encoded path= line" {
  local good="$BATS_TEST_TMPDIR/r readfile=x"
  local bad="$BATS_TEST_TMPDIR/r"$'\n'"readfile=x" text expected
  [ "$(LC_ALL=C printf %q "$BATS_TEST_TMPDIR")" = "$BATS_TEST_TMPDIR" ]
  mkdir "$good" "$bad"
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'a'")
  expected=$(printf '%s\n' writable "path=$BATS_TEST_TMPDIR/r\\ readfile=x/a" \
    readfile=build.out)

  run_probe_command probe_readonly_path false "$bad" 'cat build.out' "$text"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "$output" = "$(printf '%s\n' writable \
    "path=\$'$BATS_TEST_TMPDIR/r\\nreadfile=x/a'" readfile=build.out)" ]

  run_probe_command probe_readonly_path false "$good" 'cat build.out' "$text"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "$output" = "$expected" ]

  run_probe_command probe_readonly_path false "$bad" 'cat build.out' \
    "$(readonly_path_text fire-readonly-path-cp-tmp "'$good/a'")"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "$output" = "$expected" ]
}

# A refused path under a read-only directory whose name holds a newline: the
# outcome is readonly and path= is still one $'...' line, with the newline
# written \n, since the probe prints path= under readonly too. The directory is
# chmod 555 so -w is false for the suite's uid; a root run would read it
# writable, so the case skips there. The mode is restored straight after the
# probe, so bats can remove the tree whatever the assertions do. Under a
# mutant that drops path= when readonly holds a newline, the output assertion
# fails on the outcome line alone.
@test "a resolved refused path holding a newline under a read-only directory gives readonly and one encoded path= line" {
  local bad="$BATS_TEST_TMPDIR/r"$'\n'"readfile=x" text expected
  [ "$(id -u)" -ne 0 ] || skip "running as root: chmod 555 does not block writes"
  mkdir "$bad"
  chmod 555 "$bad"
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'a'")
  expected=$(printf '%s\n' readonly \
    "path=\$'$BATS_TEST_TMPDIR/r\\nreadfile=x/a'")

  run_probe_command probe_readonly_path false "$bad" 'cat build.out' "$text"
  chmod 755 "$bad"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "$output" = "$expected" ]
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
