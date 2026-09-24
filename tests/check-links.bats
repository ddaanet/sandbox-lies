#!/usr/bin/env bats
# Item 2.2 slice 1: scripts/check-links.sh's external contract.
#
# Each fixture root is a `git init` temp repo under $BATS_TEST_TMPDIR with its
# files `git add`ed — the script walks the same tracked markdown scope as
# Item 2.1, so a root with nothing staged would test an empty tree, not the
# fixture.

ROOT="${BATS_TEST_DIRNAME}/.."
SCRIPT="$ROOT/scripts/check-links.sh"

# `run --separate-stderr` needs 1.5.0: the contract puts broken-link lines on
# stdout, and a plain `run` merges stderr into $output, so a report written to
# the wrong stream would still match.
bats_require_minimum_version 1.5.0

load helpers/bsd-stubs

# Run from a directory holding only the fixture roots: from the repo root, a
# script resolving links against its CWD would pass or fail on whatever this
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

@test "resolving link passes" {
  local dir
  dir=$(make_fixture_root resolving)
  mkdir -p "$dir/docs"
  printf '[b](b.md)\n' >"$dir/docs/a.md"
  # Only docs/b.md exists — no root-level b.md. A script resolving the link
  # against ROOT or CWD instead of the linking file's own directory (docs/)
  # would look for a b.md that is not there and report it broken.
  : >"$dir/docs/b.md"
  git -C "$dir" add docs/a.md docs/b.md

  run --separate-stderr "$SCRIPT" "$dir"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ -z "$stderr" ]
}

@test "broken link is reported" {
  local dir
  dir=$(make_fixture_root broken)
  mkdir -p "$dir/docs"
  # The one link in the fixture, and the only broken one — nothing else in
  # the tree to source a second report line from.
  printf '[m](missing.md)\n' >"$dir/docs/a.md"
  # Decoys: a missing.md that exists, but at ROOT and in the CWD (see setup)
  # rather than beside the linking file. A script resolving against either,
  # falling back to either, or accepting a file of that name anywhere in the
  # tree finds one of these and reports nothing.
  : >"$dir/missing.md"
  : >"$BATS_TEST_TMPDIR/missing.md"
  git -C "$dir" add docs/a.md missing.md

  run --separate-stderr "$SCRIPT" "$dir"
  [ "$status" -eq 1 ]
  [ "$output" = "broken-link: docs/a.md -> missing.md" ]
}
