#!/usr/bin/env bats
# Git behaviour a verdict's wording relies on, pinned against the git on PATH.
#
# readonly-path's recovery clause says that after a fast-forward killed
# mid-way — some target files already written to the worktree, HEAD and the
# index unmoved — a re-run refuses them, so they must be restored from HEAD
# before the whole call is re-run. The skill's merge-recovery procedure adds
# the untracked files the target added. No case matches git's own messages:
# they vary across versions and locales, and the outcome is in the exit
# status, HEAD and the worktree.

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs
load helpers/git-env

# A repository whose HEAD (main) is one commit behind `target`, which changes
# a.txt and b.txt and adds c.txt. Exports REPO, BASE and TARGET.
setup() {
  REPO="$BATS_TEST_TMPDIR/repo"
  git init -q -b main "$REPO"
  git -C "$REPO" config user.email test@example.invalid
  git -C "$REPO" config user.name test
  git -C "$REPO" config commit.gpgsign false
  printf 'a base\n' >"$REPO/a.txt"
  printf 'b base\n' >"$REPO/b.txt"
  git -C "$REPO" add a.txt b.txt
  git -C "$REPO" commit -q -m base
  BASE=$(git -C "$REPO" rev-parse HEAD)
  git -C "$REPO" checkout -q -b target
  printf 'a target\n' >"$REPO/a.txt"
  printf 'b target\n' >"$REPO/b.txt"
  printf 'c target\n' >"$REPO/c.txt"
  git -C "$REPO" add a.txt b.txt c.txt
  git -C "$REPO" commit -q -m target
  TARGET=$(git -C "$REPO" rev-parse HEAD)
  git -C "$REPO" checkout -q main
}

# The state a killed fast-forward leaves: a.txt already at the target's
# content, b.txt not yet reached, HEAD and index at the base.
partly_applied() {
  git -C "$REPO" show "$TARGET:a.txt" >"$REPO/a.txt"
  [ "$(git -C "$REPO" rev-parse HEAD)" = "$BASE" ]
  git -C "$REPO" diff --cached --quiet
}

@test "a fast-forward re-run over a file already at the target is refused" {
  partly_applied

  run git -C "$REPO" merge --ff-only target

  [ "$status" -ne 0 ]
  [ "$(git -C "$REPO" rev-parse HEAD)" = "$BASE" ]
  [ "$(cat "$REPO/b.txt")" = 'b base' ]
}

@test "a fast-forward re-run over an added file already written is refused" {
  git -C "$REPO" show "$TARGET:c.txt" >"$REPO/c.txt"

  run git -C "$REPO" merge --ff-only target

  [ "$status" -ne 0 ]
  [ "$(git -C "$REPO" rev-parse HEAD)" = "$BASE" ]
  [ "$(cat "$REPO/a.txt")" = 'a base' ]
}

@test "restored from HEAD, the whole fast-forward re-runs cleanly" {
  partly_applied
  git -C "$REPO" show "$TARGET:c.txt" >"$REPO/c.txt"
  git -C "$REPO" diff --quiet "$TARGET" -- a.txt
  git -C "$REPO" checkout HEAD -- a.txt
  rm "$REPO/c.txt"

  run git -C "$REPO" merge --ff-only target

  [ "$status" -eq 0 ]
  [ "$(git -C "$REPO" rev-parse HEAD)" = "$TARGET" ]
  [ "$(cat "$REPO/b.txt")" = 'b target' ]
}
