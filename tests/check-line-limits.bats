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

@test "SKILL.md capped at 200" {
  local dir
  dir=$(make_fixture_root skill-cap)
  mkdir -p "$dir/skills/x/references"
  # 201 lines: one over the 200 cap this slice adds. The exact "> 200" in the
  # expected line pins the cap itself — a 400 cap (docs/'s) or a 201 cap
  # would leave a 201-line file clean, and a 199 cap would print the wrong
  # number.
  seq 201 >"$dir/skills/x/SKILL.md"
  # The same 201 lines in a sibling references node, which the exact
  # single-line output requires to stay clean: the 200 cap is SKILL.md's
  # alone, and a 200 cap over all of skills/ markdown reports this too.
  seq 201 >"$dir/skills/x/references/n.md"
  git -C "$dir" add skills/x/SKILL.md skills/x/references/n.md

  run --separate-stderr "$SCRIPT" "$dir"
  [ "$status" -eq 1 ]
  [ "$output" = "oversized-file: skills/x/SKILL.md: 201 lines > 200" ]
}

@test "oversized skills node is reported" {
  local dir
  dir=$(make_fixture_root skills-node)
  mkdir -p "$dir/skills/x/references"
  # 401 lines: over the 400 cap non-SKILL skills/ markdown is scoped at. The
  # exact "> 400" in its expected line pins the cap: a 200 cap prints "> 200".
  seq 401 >"$dir/skills/x/references/n.md"
  # The same 401 lines at the skill's root, outside references/: its own
  # expected line pins the arm to all markdown under skills/, where one
  # narrowed to `skills/*/references/*.md` leaves it clean.
  seq 401 >"$dir/skills/x/p.md"
  git -C "$dir" add skills/x/references/n.md skills/x/p.md

  run --separate-stderr "$SCRIPT" "$dir"
  [ "$status" -eq 1 ]
  # `git ls-files` order: bytewise, so p.md sorts before references/.
  [ "$output" = "oversized-file: skills/x/p.md: 401 lines > 400
oversized-file: skills/x/references/n.md: 401 lines > 400" ]
}

@test "oversized root markdown is reported" {
  local dir
  dir=$(make_fixture_root root-markdown)
  mkdir -p "$dir/notes"
  seq 401 >"$dir/README.md"
  # Same 401 lines one directory down. Left clean, this rules out a root arm
  # that crosses `/` (`*.md` unanchored, or `**/*.md`): it would flag this
  # too and break the exact single-line assertion below. A root arm leaking
  # into dot-directories only is pinned in `markdown elsewhere is out of
  # scope`.
  seq 401 >"$dir/notes/deep.md"
  git -C "$dir" add README.md notes/deep.md

  run --separate-stderr "$SCRIPT" "$dir"
  [ "$status" -eq 1 ]
  [ "$output" = "oversized-file: README.md: 401 lines > 400" ]
}

@test "markdown elsewhere is out of scope" {
  local dir
  dir=$(make_fixture_root elsewhere)
  mkdir -p "$dir/lib" "$dir/.claude/skills/y/references"
  seq 401 >"$dir/lib/x.md"
  # 201 lines, over SKILL.md's own 200 cap: left clean, this pins the
  # SKILL.md arm's anchor to a root-level `skills/`, not any `skills/`
  # segment wherever it falls in the path.
  seq 201 >"$dir/.claude/skills/y/SKILL.md"
  # `oversized skills node is reported`'s 401-line node, moved under a
  # dot-directory. Left clean, this pins the skills node arm's anchor the
  # same way (`*skills/*.md` flags it), and rules out a root arm that skips
  # only non-dot subdirectories.
  seq 401 >"$dir/.claude/skills/y/references/n.md"
  git -C "$dir" add lib/x.md .claude/skills/y/SKILL.md \
    .claude/skills/y/references/n.md

  run --separate-stderr "$SCRIPT" "$dir"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ -z "$stderr" ]
}
