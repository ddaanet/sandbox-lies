#!/usr/bin/env bats
# lib/probes-readonly.sh's probe_readonly_path: pins the defects the Item 8.0
# slice 3 code review found and fixed
# (plans/sandbox-lies/reports/item-8-0-s3-code-review.md) that the slice's own
# tests (tests/probes-readonly-facts.bats) did not reach. That file sits near
# the line cap, so this is a new file; it shares fixtures and helpers with it
# through tests/helpers/probes.bash rather than duplicating them.

ROOT="${BATS_TEST_DIRNAME}/.."

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs
load helpers/probes

setup() {
  source "$ROOT/lib/probes.sh"
}

# make_tag_repo <repo> — one commit holding a, with commit-tag, tree-tag and
# blob-tag naming that commit, its tree and a's blob.
make_tag_repo() {
  make_one_commit_repo "$1" main
  git -C "$1" tag commit-tag HEAD
  git -C "$1" tag tree-tag "$(git -C "$1" rev-parse 'HEAD^{tree}')"
  git -C "$1" tag blob-tag "$(git -C "$1" rev-parse HEAD:a)"
}

# make_one_commit_repo <repo> <branch> — one commit holding a, on <branch>.
make_one_commit_repo() {
  git init -q -b "$2" "$1"
  git -C "$1" config user.email test@example.invalid
  git -C "$1" config user.name test
  git -C "$1" config commit.gpgsign false
  printf 'a\n' >"$1/a"
  git -C "$1" add a
  git -C "$1" commit -q -m init
}

# assert_merge_without_target — the last probe run exited 0 with nothing on
# stderr, printed merge=1 and no target=.
assert_merge_without_target() {
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  printf '%s\n' "$output" | grep -qxF 'merge=1'
  run ! grep -q '^target=' <<<"$output"
}

# The index is back-dated so a rewrite moves its mtime even within the second
# the fixture was made in, and snapshotted around the probe call only. `d` is
# stat-dirty with unchanged content — the state the review's Critical Issue 3
# fixture did not cover — and its mtime is set to a fixed past second rather
# than to now: git compares whole-second mtimes (a build without USE_NSEC, as
# git 2.47.3 here), so a plain `touch d` lands in the second `git add`
# recorded, d stays stat-clean, and a porcelain `git diff HEAD` has nothing to
# refresh and never writes — the pin would stay green on the defect it names.
# diff-files (plumbing, no refresh) still listing d afterwards proves the
# fixture was stat-dirty and that the probe left it so; target=feat and
# match=a prove the file comparison ran, so d's absence is its own.
@test "a tracked file stat-dirty with unchanged content never becomes a match, and the index is untouched" {
  local repo="$BATS_TEST_TMPDIR/scratch repo" text facts before_mtime

  make_scratch_repo "$repo"
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'$repo'")
  touch -t 200501010000 "$repo/d"
  touch -t 200001010000 "$repo/.git/index"
  cp "$repo/.git/index" "$BATS_TEST_TMPDIR/index-before"
  before_mtime=$(index_mtime "$repo/.git/index")

  run_probe_command probe_readonly_path false "$repo" 'git checkout feat' \
    "$text"

  facts=$output
  cmp -s "$repo/.git/index" "$BATS_TEST_TMPDIR/index-before"
  [ "$(index_mtime "$repo/.git/index")" = "$before_mtime" ]
  [ ! -e "$repo/.git/index.lock" ]
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  printf '%s\n' "$facts" | grep -qxF 'target=feat'
  printf '%s\n' "$facts" | grep -qxF 'match=a'
  git -C "$repo" diff-files --name-only | grep -qxF d
  run ! grep -qxF 'match=d' <<<"$facts"
}

# `git pull` has no candidate word after its subcommand, so
# _readonly_merge_segment's cands array stays empty — the shape that aborted
# the probe on bash 3.2 under set -u (Major Issue 1) before every possibly-
# empty array was guarded. The suite runs bash 5, which does not reproduce
# that abort even unguarded, so this test pins the outcome rather than the
# crash path itself.
@test "a bare git pull gives merge=1 with a clean exit" {
  local text
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'$BATS_TEST_TMPDIR/x'")

  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" 'git pull' \
    "$text"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  printf '%s\n' "$output" | grep -qxF 'merge=1'
}

# Major Issue 2: a candidate whose type is not a commit used to print to
# stderr; it now resolves silently to no target. commit-tag, in the same
# repository, resolves, so the tree tag's missing target= is its type's.
@test "a tag on a tree gives merge=1, no target and a clean exit" {
  local repo="$BATS_TEST_TMPDIR/tagrepo" text
  make_tag_repo "$repo"
  text=$(readonly_path_text fire-readonly-path-cp-tmp "")

  run_probe_command probe_readonly_path false "$repo" 'git merge commit-tag' \
    "$text"
  printf '%s\n' "$output" | grep -qxF 'target=commit-tag'

  run_probe_command probe_readonly_path false "$repo" 'git merge tree-tag' \
    "$text"
  assert_merge_without_target
}

@test "a tag on a blob gives merge=1, no target and a clean exit" {
  local repo="$BATS_TEST_TMPDIR/tagrepo" text
  make_tag_repo "$repo"
  text=$(readonly_path_text fire-readonly-path-cp-tmp "")

  run_probe_command probe_readonly_path false "$repo" 'git merge commit-tag' \
    "$text"
  printf '%s\n' "$output" | grep -qxF 'target=commit-tag'

  run_probe_command probe_readonly_path false "$repo" 'git merge blob-tag' \
    "$text"
  assert_merge_without_target
}

# Major Issue 3: a repository git cannot open used to print to stderr. Here
# nothing can resolve, so the empty stderr is what this test pins.
@test "a .git file naming a missing gitdir gives merge=1, no target and a clean exit" {
  local broken="$BATS_TEST_TMPDIR/brokenrepo" text
  mkdir -p "$broken"
  printf 'gitdir: %s/nonexistent\n' "$broken" >"$broken/.git"
  text=$(readonly_path_text fire-readonly-path-cp-tmp "")

  run_probe_command probe_readonly_path false "$broken" 'git merge sometag' \
    "$text"

  assert_merge_without_target
}

# Major Issue 3's unborn HEAD beside another branch: feat resolves, so only
# the unborn HEAD keeps target= away (a candidate naming nothing would give no
# target whatever HEAD is), and diff-index against that HEAD is what used to
# print a fatal.
@test "an unborn HEAD beside a resolvable branch gives merge=1, no target and a clean exit" {
  local repo="$BATS_TEST_TMPDIR/unbornrepo" text
  make_one_commit_repo "$repo" feat
  git -C "$repo" symbolic-ref HEAD refs/heads/main
  text=$(readonly_path_text fire-readonly-path-cp-tmp "")

  run_probe_command probe_readonly_path false "$repo" 'git merge feat' "$text"

  assert_merge_without_target
}

# Critical Issue 2: past 1000 modified files against HEAD, no target= is
# printed at all — the verdict falls back to its generic clause rather than
# building a list that could not finish in time. The files match the target's
# content: restoring one from HEAD, leaving exactly 1000, brings target= back,
# so the cap and nothing else withholds it.
@test "past 1000 modified files against HEAD, matching the target, gives no target" {
  local repo="$BATS_TEST_TMPDIR/manyfiles" text i

  git init -q -b main "$repo"
  git -C "$repo" config user.email test@example.invalid
  git -C "$repo" config user.name test
  git -C "$repo" config commit.gpgsign false
  for i in $(seq 1 1001); do
    printf 'v1\n' >"$repo/f$i"
  done
  git -C "$repo" add .
  git -C "$repo" commit -q -m init
  git -C "$repo" checkout -q -b feat
  for i in $(seq 1 1001); do
    printf 'v2\n' >"$repo/f$i"
  done
  git -C "$repo" add .
  git -C "$repo" commit -q -m feat
  git -C "$repo" checkout -q main
  for i in $(seq 1 1001); do
    printf 'v2\n' >"$repo/f$i"
  done

  text=$(readonly_path_text fire-readonly-path-cp-tmp "")

  run_probe_command probe_readonly_path false "$repo" 'git merge feat' "$text"
  assert_merge_without_target

  git -C "$repo" checkout -q -- f1001
  run_probe_command probe_readonly_path false "$repo" 'git merge feat' "$text"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -qxF 'target=feat'
  printf '%s\n' "$output" | grep -qxF 'match=f1000'
}

# make_merge_pass_repo <repo> — main holds x and z; feat changes z; HEAD at
# main with a clean tree. Each merge-pass case below then puts z at feat's
# content, the one match it expects.
make_merge_pass_repo() {
  make_one_commit_repo "$1" main
  printf 'x main\n' >"$1/x"
  printf 'z main\n' >"$1/z"
  git -C "$1" add x z
  git -C "$1" commit -q -m xz
  git -C "$1" checkout -q -b feat
  printf 'z feat\n' >"$1/z"
  git -C "$1" add z
  git -C "$1" commit -q -m feat
  git -C "$1" checkout -q main
}

# Critical Issue 2's single ls-tree pairs its records with the modified files
# in one pass over both sorted lists, stepping past a name only one side
# holds. m, staged new, is modified against HEAD but absent at feat, and
# sorts before z: stepping the ls-tree side past it instead ends the pass
# before z is reached.
@test "a modified file absent at the target does not hide a later match" {
  local repo="$BATS_TEST_TMPDIR/passrepo" text
  make_merge_pass_repo "$repo"
  printf 'z feat\n' >"$repo/z"
  printf 'm new\n' >"$repo/m"
  git -C "$repo" add m
  text=$(readonly_path_text fire-readonly-path-cp-tmp "")

  run_probe_command probe_readonly_path false "$repo" 'git merge feat' "$text"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  printf '%s\n' "$output" | grep -qxF 'target=feat'
  printf '%s\n' "$output" | grep -qxF 'match=z'
}

# The other side: x is a file in the working tree and a directory at feat,
# which ls-tree -r lists as x/y, a record no modified file pairs with; x/y
# sorts before z, and stepping the file side past it ends the pass before z.
@test "a directory at the target where a modified file sits does not hide a later match" {
  local repo="$BATS_TEST_TMPDIR/passrepo" text
  make_merge_pass_repo "$repo"
  git -C "$repo" checkout -q feat
  git -C "$repo" rm -q x
  mkdir "$repo/x"
  printf 'y feat\n' >"$repo/x/y"
  git -C "$repo" add x/y
  git -C "$repo" commit -q -m 'x becomes a directory'
  git -C "$repo" checkout -q main
  printf 'z feat\n' >"$repo/z"
  printf 'x edited\n' >"$repo/x"
  text=$(readonly_path_text fire-readonly-path-cp-tmp "")

  run_probe_command probe_readonly_path false "$repo" 'git merge feat' "$text"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  git -C "$repo" ls-tree -r --name-only feat -- x | grep -qxF x/y
  printf '%s\n' "$output" | grep -qxF 'target=feat'
  printf '%s\n' "$output" | grep -qxF 'match=z'
}

# Critical Issue 1: the tokenizer stops at 16384 characters, and a cut scan
# gives no readfile= (the unscanned rest may hold a writer). The same reader
# command ending exactly at character 16384 gives readfile=, so the bound sits
# there and not lower; with the padding 10 characters longer, build.log starts
# at character 16386.
@test "a reader name past character 16384 gives no readfile" {
  local text pad
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'$BATS_TEST_TMPDIR/x'")

  pad=$(printf 'a%.0s' {1..16370})
  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    "cat $pad build.log" "$text"
  printf '%s\n' "$output" | grep -qxF 'readfile=build.log'

  pad=$(printf 'a%.0s' {1..16380})
  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    "cat $pad build.log" "$text"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  run ! grep -q '^readfile=' <<<"$output"
}

# Major Issue 4: an unquoted newline separates command segments, but a
# heredoc body's line is not a command — the scan stops at the end of the
# line holding the opening `<<`. The same lines behind a single `<` read the
# body line as a command, so the `<<` and nothing else withholds merge=1.
@test "a heredoc body's git merge line gives no merge" {
  local text
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'$BATS_TEST_TMPDIR/x'")

  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    $'cat <EOF\ngit merge feat\nEOF' "$text"
  printf '%s\n' "$output" | grep -qxF 'merge=1'

  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    $'cat <<EOF\ngit merge feat\nEOF' "$text"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  run ! grep -qxF 'merge=1' <<<"$output"
}

@test "a git merge on the line after another command gives merge=1" {
  local text
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'$BATS_TEST_TMPDIR/x'")

  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    $'git fetch\ngit merge feat' "$text"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  printf '%s\n' "$output" | grep -qxF 'merge=1'
}

# A reader on the next line keeps readfile=, so the writer's segment is what
# withholds it.
@test "a writer on the line after a reader gives no readfile" {
  local text
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'$BATS_TEST_TMPDIR/x'")

  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    $'cat build.log\ncat x' "$text"
  printf '%s\n' "$output" | grep -qxF 'readfile=build.log'

  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    $'cat build.log\nrm -rf x' "$text"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  run ! grep -q '^readfile=' <<<"$output"
}

# Major Issue 8: under nopath, the git-dir search starts at the raw payload
# cwd. A relative cwd is joined onto the probe's own $PWD before the search
# begins; without that join, stripping a bare relative component never
# reaches / and the search spins. The scratch repo's .git sits at
# $BATS_TEST_TMPDIR, the test's working directory, three levels above the
# relative cwd passed in; run_probe_bounded (helpers/probes.bash) bounds the
# wait so a regression fails the test instead of hanging the suite.
@test "nopath with a relative cwd resolves target within a bound" {
  local text

  make_scratch_repo "$BATS_TEST_TMPDIR"
  mkdir -p "$BATS_TEST_TMPDIR/sub1/sub2/sub3"
  text=$(readonly_path_text fire-readonly-path-cp-tmp "")
  cd "$BATS_TEST_TMPDIR"

  run_probe_bounded probe_readonly_path false sub1/sub2/sub3 "$text" \
    'git checkout feat'

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = nopath ]
  printf '%s\n' "$output" | grep -qxF 'target=feat'
}
