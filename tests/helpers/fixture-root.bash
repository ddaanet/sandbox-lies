#!/usr/bin/env bash
# Shared by the check-script suites (check-line-limits, check-links,
# check-links-edges). Each fixture root is a `git init` temp repo under
# $BATS_TEST_TMPDIR with its files `git add`ed: the scripts walk
# `git ls-files`, so a root with nothing staged would test an empty tree, not
# the fixture.
#
# Usage: `load helpers/fixture-root`, then `SCRIPT="$ROOT/scripts/<name>"`.

# `run --separate-stderr` needs 1.5.0: the scripts' contracts put report
# lines on stdout, and a plain `run` merges stderr into $output, so a report
# written to the wrong stream would still match.
bats_require_minimum_version 1.5.0

# shellcheck disable=SC2034 # read by the loading suite, not here
ROOT="${BATS_TEST_DIRNAME}/.."

# Run from a directory holding only the fixture roots: from the repo root, a
# script resolving paths against its CWD would pass or fail on whatever this
# repo's own tree happens to hold.
setup() {
  cd "$BATS_TEST_TMPDIR" || return
}

# Build a `git init` repo under $BATS_TEST_TMPDIR/<name> and print its path.
make_fixture_root() {
  local dir
  dir="$BATS_TEST_TMPDIR/$1"
  mkdir -p "$dir"
  git -C "$dir" init -q
  printf '%s\n' "$dir"
}
