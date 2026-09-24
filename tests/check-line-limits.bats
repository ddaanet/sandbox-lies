#!/usr/bin/env bats
# Item 2.1 slice 1: scripts/check-line-limits.sh's external contract.
#
# Each fixture root is a `git init` temp repo under $BATS_TEST_TMPDIR with its
# files `git add`ed — the script walks `git ls-files`, so a root with nothing
# staged would test an empty tree, not the fixture.

ROOT="${BATS_TEST_DIRNAME}/.."
SCRIPT="$ROOT/scripts/check-line-limits.sh"

# `run --separate-stderr` needs 1.5.0: the contract puts overage lines on
# stdout, and a plain `run` merges stderr into $output, so a report written to
# the wrong stream would still match.
bats_require_minimum_version 1.5.0

load helpers/bsd-stubs

# Build a `git init` repo under $BATS_TEST_TMPDIR/<name> and print its path.
make_fixture_root() {
  local dir
  dir="$BATS_TEST_TMPDIR/$1"
  mkdir -p "$dir"
  git -C "$dir" init -q
  printf '%s\n' "$dir"
}

@test "clean tree exits 0 silently" {
  local dir
  dir=$(make_fixture_root clean)
  mkdir -p "$dir/docs"
  # Exactly at the cap, one line short of the oversized case below: a cap
  # compared with `>=`, or set one lower, reports this file.
  seq 400 >"$dir/docs/a.md"
  git -C "$dir" add docs/a.md

  run --separate-stderr "$SCRIPT" "$dir"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ -z "$stderr" ]
}

@test "oversized markdown is reported" {
  local dir
  dir=$(make_fixture_root oversized)
  mkdir -p "$dir/docs"
  seq 401 >"$dir/docs/a.md"
  git -C "$dir" add docs/a.md

  run --separate-stderr "$SCRIPT" "$dir"
  [ "$status" -eq 1 ]
  [ "$output" = "oversized-file: docs/a.md: 401 lines > 400" ]
}
