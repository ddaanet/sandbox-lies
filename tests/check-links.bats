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

# Item 2.2 slice 2: the tracked markdown scope, added from Item 2.1's
# reviews — the scope is where its gaps were.

@test "broken links in scope are reported" {
  local dir
  dir=$(make_fixture_root scope-in)
  mkdir -p "$dir/docs/plans" "$dir/skills/x/references" \
    "$dir/skills/plugin-dev"
  # One broken link each, one per scope arm: root, docs/, skills/ itself,
  # and skills/ at a deeper nesting.
  printf '[m](missing.md)\n' >"$dir/README.md"
  printf '[m](missing.md)\n' >"$dir/docs/a.md"
  printf '[m](missing.md)\n' >"$dir/skills/x/SKILL.md"
  printf '[m](missing.md)\n' >"$dir/skills/x/references/n.md"
  # Directly under skills/, in no skill directory: rules out a skills arm
  # narrowed to `skills/*/…` that the two files above both satisfy.
  printf '[m](missing.md)\n' >"$dir/skills/top.md"
  # A plans/ and a plugin-dev/ below an in-scope directory: only the
  # root-level ones are excluded, so an unanchored `*plans/*` or
  # `*plugin-dev/*` exclusion drops one of these. docs/plans/a.md also
  # rules out a docs arm stopping at docs/'s own files.
  printf '[m](missing.md)\n' >"$dir/docs/plans/a.md"
  printf '[m](missing.md)\n' >"$dir/skills/plugin-dev/SKILL.md"
  git -C "$dir" add README.md docs/a.md skills/x/SKILL.md \
    skills/x/references/n.md skills/top.md docs/plans/a.md \
    skills/plugin-dev/SKILL.md

  run --separate-stderr "$SCRIPT" "$dir"
  [ "$status" -eq 1 ]
  # `git ls-files` order: bytewise, so README.md sorts first ('R' < 'd'),
  # skills/x/SKILL.md before skills/x/references/n.md ('S' < 'r').
  [ "$output" = "broken-link: README.md -> missing.md
broken-link: docs/a.md -> missing.md
broken-link: docs/plans/a.md -> missing.md
broken-link: skills/plugin-dev/SKILL.md -> missing.md
broken-link: skills/top.md -> missing.md
broken-link: skills/x/SKILL.md -> missing.md
broken-link: skills/x/references/n.md -> missing.md" ]
}

@test "markdown out of scope is ignored" {
  local dir
  dir=$(make_fixture_root scope-out)
  mkdir -p "$dir/plans" "$dir/plugin-dev" "$dir/lib/skills/y" \
    "$dir/.claude/skills/y" "$dir/docs"
  printf '[m](missing.md)\n' >"$dir/plans/x.md"
  printf '[m](missing.md)\n' >"$dir/plugin-dev/x.md"
  printf '[m](missing.md)\n' >"$dir/lib/x.md"
  # skills/ nested under a dot-directory, not at the root: out of scope the
  # same way `markdown elsewhere is out of scope` pins it for Item 2.1.
  printf '[m](missing.md)\n' >"$dir/.claude/skills/y/SKILL.md"
  # The same, under a plain directory: pins the skills arm's root anchor on
  # its own. The dot-directory file alone lets an unanchored `*skills/*`
  # arm pass behind a dot-directory skip.
  printf '[m](missing.md)\n' >"$dir/lib/skills/y/SKILL.md"
  # Not markdown, in an in-scope directory: the scope is markdown files, not
  # every file under docs/ or skills/.
  printf '[m](missing.md)\n' >"$dir/docs/x.txt"
  git -C "$dir" add plans/x.md plugin-dev/x.md lib/x.md \
    .claude/skills/y/SKILL.md lib/skills/y/SKILL.md docs/x.txt
  # Untracked, in an otherwise in-scope directory: proves the walk itself
  # excludes it, not just the scope check.
  printf '[m](missing.md)\n' >"$dir/docs/u.md"

  run --separate-stderr "$SCRIPT" "$dir"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ -z "$stderr" ]
}
