#!/usr/bin/env bats
# bin/sandbox-lies-recover: recovery of a `git checkout <branch>` or
# `git merge --ff-only <commit-ish>` that a read-only directory (chmod 555,
# standing in for the sandbox's refusal) killed part-way. Each case builds a
# scratch repo, runs the refused command while the directory is read-only,
# makes it writable again (the script runs unsandboxed in real use), runs the
# script with --apply, and asserts the branch or HEAD is at the target, that
# `git status` lists only the work that was kept, and that work is intact.
#
# Contract: plans/2026-11-01-recovery-script.md. No git diagnostic is quoted
# here (self-quiet, FR-11): the refusals are asserted by exit status and HEAD
# position, as the observation table in
# skills/sandbox-lies/references/refused-merge-recovery.md records them.

# shellcheck disable=SC2030,SC2031,SC2034 # state set in a @test body is read by helpers/recover.bash

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs
load helpers/git-env
load helpers/recover

RECOVER="$BATS_TEST_DIRNAME/../bin/sandbox-lies-recover"

setup() {
  REPO="$BATS_TEST_TMPDIR/repo"
  BASEBR=main
  git config --file "$GIT_CONFIG_GLOBAL" init.defaultBranch main
}

# A frozen directory is not removable by bats; make the whole tree writable.
teardown() {
  chmod -R u+w "$BATS_TEST_TMPDIR" 2>/dev/null || true
}

# ---- the cases -------------------------------------------------------------

# The eight cells of the observation table.

@test "checkout, target changes a file in a read-only directory" {
  cell checkout change
}

@test "checkout, target adds a file in a read-only directory" {
  cell checkout add
}

@test "checkout, target deletes a file in a read-only directory" {
  cell checkout delete
}

@test "checkout, target adds a directory under a read-only directory" {
  cell checkout adddir
}

@test "merge --ff-only, target changes a file in a read-only directory" {
  cell merge change
}

@test "merge --ff-only, target adds a file in a read-only directory" {
  cell merge add
}

@test "merge --ff-only, target deletes a file in a read-only directory" {
  cell merge delete
}

@test "merge --ff-only, target adds a directory under a read-only directory" {
  cell merge adddir
}

# Mixed and neighbouring states.

@test "checkout: a path staged with the target's content then edited further is kept" {
  scenario checkout change
  printf 'f v3 mine\n' >"$REPO/d/f"
  apply_ok
  [[ "$output" == *"keep d/f"* ]]
  assert_reached
  assert_status ' M d/f'
  assert_bytes d/f $'f v3 mine\n'
}

@test "checkout: an untracked leftover edited after the refusal is kept" {
  scenario checkout delete
  printf 'f v1 edited\n' >"$REPO/d/f"
  apply_ok
  [[ "$output" == *"keep d/f"* ]]
  assert_reached
  assert_status '?? d/f'
  assert_bytes d/f $'f v1 edited\n'
}

@test "checkout of a branch at the current commit, refused on index.lock, ends at exit 0" {
  build_repo same
  PRE=$(g rev-parse HEAD)
  TARGET=$PRE
  VERB=checkout
  : >"$REPO/.git/index.lock"
  run git -C "$REPO" checkout feat
  [ "$status" -ne 0 ]
  [ "$(g symbolic-ref -q HEAD)" = refs/heads/main ]
  # The lock is the sandbox's doing; the script runs unsandboxed without it.
  rm "$REPO/.git/index.lock"
  apply_ok
  assert_reached
  assert_status
}

@test "H1: the checkout re-run by hand before recovery still recovers" {
  scenario_up checkout change
  run git -C "$REPO" checkout feat
  [ "$status" -eq 0 ]
  [ "$(g reflog -1 --format=%gs)" = "checkout: moving from feat to feat" ]
  thaw
  apply_ok
  assert_reached
  assert_status
}

@test "M1: a file added inside a new directory, under checkout" {
  cell checkout m1
}

@test "M1: a file added inside a new directory, under merge --ff-only" {
  cell merge m1
}

@test "M1: a deleted directory, under checkout" {
  cell checkout deldir
}

@test "M1: a deleted directory, under merge --ff-only" {
  cell merge deldir
}

@test "M5: a rename out of a refused directory, under checkout" {
  cell checkout rename
}

@test "M5: a rename out of a refused directory, under merge --ff-only" {
  cell merge rename
}

@test "M6: an untracked leftover identical to pre is removed" {
  scenario checkout delete
  [ "$(cat "$REPO/d/f")" = "f v1" ]
  [ "$(g status --porcelain -uall)" = "?? d/f" ]
  apply_ok
  [[ "$output" == *"remove d/f"* ]]
  [ ! -e "$REPO/d/f" ]
  assert_reached
  assert_status
}

@test "a file git converts on checkout (eol=crlf) left at pre is restored, not kept" {
  cell checkout crlf
}

@test "a gitlink whose commit is absent is compared as presence, not kept" {
  cell checkout gitlink
  [[ "$output" != *sub* ]]
}

@test "a directory at a gitlink only the target has is never removed" {
  scenario merge gitlink_add
  mkdir -p "$REPO/sub"
  apply_ok
  [[ "$output" != *"remove sub"* ]]
  [[ "$output" != *"restore sub"* ]]
  [ -d "$REPO/sub" ]
  assert_reached
}

@test "paths with a space and with a newline, under checkout" {
  cell checkout odd
}

@test "paths with a space and with a newline, under merge --ff-only" {
  cell merge odd
}

@test "paths with a space and with a newline are kept byte for byte when edited" {
  scenario checkout odd
  printf 'sp mine\n' >"$REPO/d/sp ace.txt"
  printf 'nl mine\n' >"$REPO/d/nl"$'\n'"file.txt"
  apply_ok
  [[ "$output" == *"keep d/sp ace.txt"* ]]
  assert_reached
  assert_status " M d/nl"$'\n'"file.txt" ' M d/sp ace.txt'
  assert_bytes "d/sp ace.txt" $'sp mine\n'
  assert_bytes "d/nl"$'\n'"file.txt" $'nl mine\n'
}

@test "a path with a newline prints as one plan line" {
  scenario checkout odd
  printf 'sp mine\n' >"$REPO/d/sp ace.txt"
  printf 'nl mine\n' >"$REPO/d/nl"$'\n'"file.txt"
  apply_ok
  local line
  while IFS= read -r line; do
    case $line in
      'restore '* | 'remove '* | 'keep '* | 'git '* | 'nothing to do') ;;
      *) printf 'stray plan line: [%s]\n' "$line" >&2; return 1 ;;
    esac
  done <<<"$output"
  [[ "$output" == *"keep d/sp ace.txt"* ]]
  [[ "$output" == *"keep "*"d/nl"*"file.txt"* ]]
}

# A pathspec is magic only at its start, and only the root is outside the
# frozen directory, so the checkout wrote this name; putting the old version
# back stands in for a refused write. Read as magic, the name means every file
# but x, and the restore takes the edits with it.
@test "a path named like pathspec magic is restored alone" {
  scenario checkout magic
  printf 'x v1\n' >"$REPO/:!x"
  printf 'g mine\n' >"$REPO/d/g"
  apply_ok
  [[ "$output" == *"restore :!x"* ]]
  assert_reached
  assert_status ' M d/g'
  assert_bytes ":!x" $'x v2\n'
  assert_bytes d/g $'g mine\n'
}

@test "an unrelated uncommitted change survives, under checkout" {
  UNRELATED=1
  scenario checkout change
  apply_ok
  assert_reached
  assert_status ' M other.txt' '?? scratch.txt'
  assert_bytes other.txt $'other v1\nmine\n'
  assert_bytes scratch.txt $'scratch\n'
}

@test "an unrelated uncommitted change survives, under merge --ff-only" {
  UNRELATED=1
  scenario merge add
  apply_ok
  assert_reached
  assert_status ' M other.txt' '?? scratch.txt'
  assert_bytes other.txt $'other v1\nmine\n'
  assert_bytes scratch.txt $'scratch\n'
}

@test "an unrelated change next to kept work: both stay" {
  UNRELATED=1
  scenario checkout change
  printf 'f v3 mine\n' >"$REPO/d/f"
  apply_ok
  [[ "$output" == *"keep d/f"* ]]
  assert_reached
  assert_status ' M d/f' ' M other.txt' '?? scratch.txt'
  assert_bytes d/f $'f v3 mine\n'
  assert_bytes other.txt $'other v1\nmine\n'
}
