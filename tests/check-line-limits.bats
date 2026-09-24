#!/usr/bin/env bats
# Item 2.1 slice 1: scripts/check-line-limits.sh's external contract.

load helpers/fixture-root
load helpers/bsd-stubs

SCRIPT="$ROOT/scripts/check-line-limits.sh"

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

@test "oversized script is reported" {
  local dir
  dir=$(make_fixture_root scripts)
  mkdir -p "$dir/lib" "$dir/tools/plans" "$dir/tools/plugin-dev"
  # One 401-line file per script type this item scopes in: an arm layout
  # that leaves any one type uncounted drops its line from the output.
  seq 401 >"$dir/lib/x.bash"
  seq 401 >"$dir/lib/x.bats"
  seq 401 >"$dir/lib/x.py"
  seq 401 >"$dir/lib/x.sh"
  # A `plans/` and a `plugin-dev/` that are not at the root: an unanchored
  # exclusion (`*plans/*`) drops these. Under `tools/`, a directory the real
  # tree lacks, so an arm listing the tree's script directories (as the
  # port's `for dir in src tests` walk does) misses them too.
  seq 401 >"$dir/tools/plans/x.sh"
  seq 401 >"$dir/tools/plugin-dev/x.sh"
  # A script at the root: an arm requiring a directory (`*/*.sh`) misses it.
  seq 401 >"$dir/x.sh"
  git -C "$dir" add lib/x.bash lib/x.bats lib/x.py lib/x.sh \
    tools/plans/x.sh tools/plugin-dev/x.sh x.sh

  run --separate-stderr "$SCRIPT" "$dir"
  [ "$status" -eq 1 ]
  # `git ls-files` order: bytewise, so .bash < .bats < .py < .sh, and
  # lib/ < tools/ < x.sh.
  [ "$output" = "oversized-file: lib/x.bash: 401 lines > 400
oversized-file: lib/x.bats: 401 lines > 400
oversized-file: lib/x.py: 401 lines > 400
oversized-file: lib/x.sh: 401 lines > 400
oversized-file: tools/plans/x.sh: 401 lines > 400
oversized-file: tools/plugin-dev/x.sh: 401 lines > 400
oversized-file: x.sh: 401 lines > 400" ]
}

@test "plans/ is out of scope" {
  local dir
  dir=$(make_fixture_root plans-scope)
  mkdir -p "$dir/plans"
  seq 401 >"$dir/plans/x.md"
  # Every script type `oversized script is reported` counts, so an exclusion
  # narrowed to the types it names (`plans/*.sh`) leaves one reported.
  seq 401 >"$dir/plans/x.bash"
  seq 401 >"$dir/plans/x.bats"
  seq 401 >"$dir/plans/x.py"
  seq 401 >"$dir/plans/x.sh"
  git -C "$dir" add plans/x.md plans/x.bash plans/x.bats plans/x.py \
    plans/x.sh

  run --separate-stderr "$SCRIPT" "$dir"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ -z "$stderr" ]
}

@test "plugin-dev/ is out of scope" {
  local dir
  dir=$(make_fixture_root plugin-dev-scope)
  mkdir -p "$dir/plugin-dev"
  # Every script type, as in `plans/ is out of scope`.
  seq 401 >"$dir/plugin-dev/x.bash"
  seq 401 >"$dir/plugin-dev/x.bats"
  seq 401 >"$dir/plugin-dev/x.py"
  seq 401 >"$dir/plugin-dev/x.sh"
  git -C "$dir" add plugin-dev/x.bash plugin-dev/x.bats plugin-dev/x.py \
    plugin-dev/x.sh

  run --separate-stderr "$SCRIPT" "$dir"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ -z "$stderr" ]
}

@test "markdown directly under skills/" {
  local dir
  dir=$(make_fixture_root skills-top)
  mkdir -p "$dir/skills"
  seq 401 >"$dir/skills/top.md"
  git -C "$dir" add skills/top.md

  run --separate-stderr "$SCRIPT" "$dir"
  [ "$status" -eq 1 ]
  [ "$output" = "oversized-file: skills/top.md: 401 lines > 400" ]
}

@test "untracked file is out of scope" {
  local dir
  dir=$(make_fixture_root untracked)
  mkdir -p "$dir/docs"
  seq 401 >"$dir/docs/u.md"
  # Deliberately not `git add`ed: the walk is `git ls-files`, so this must
  # never reach the `case`.

  run --separate-stderr "$SCRIPT" "$dir"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ -z "$stderr" ]
}

@test "deleted tracked file is skipped" {
  local dir
  dir=$(make_fixture_root deleted)
  mkdir -p "$dir/docs"
  seq 401 >"$dir/docs/gone.md"
  # A present file after it in `git ls-files` order, holding the one overage
  # to report: a walk that yields nothing, or a skip that ends the walk
  # (`break` for `continue`), drops its line.
  seq 401 >"$dir/docs/sentinel.md"
  git -C "$dir" add docs/gone.md docs/sentinel.md
  # Removed from the work tree only, so it stays in the index: `git ls-files`
  # still lists it, and walk_tracked_files's `[ ! -f … ]` guard must skip it.
  rm "$dir/docs/gone.md"

  run --separate-stderr "$SCRIPT" "$dir"
  [ "$status" -eq 1 ]
  [ "$output" = "oversized-file: docs/sentinel.md: 401 lines > 400" ]
  [ -z "$stderr" ]
}

@test "path with whitespace" {
  local dir tab=$'\t'
  dir=$(make_fixture_root spaced)
  mkdir -p "$dir/docs"
  # Each path fails a different walk. The space: one that word-splits
  # (`for file in $(git ls-files)`). The tab: one delimited by newlines,
  # since `git ls-files` without `-z` C-quotes it as `"docs/a\tb.md"`,
  # which matches no arm. The leading space: a `read` without `IFS=`,
  # which strips it and leaves a path that does not exist.
  seq 401 >"$dir/docs/a b.md"
  seq 401 >"$dir/docs/a${tab}b.md"
  seq 401 >"$dir/ lead.md"
  git -C "$dir" add "docs/a b.md" "docs/a${tab}b.md" " lead.md"

  run --separate-stderr "$SCRIPT" "$dir"
  [ "$status" -eq 1 ]
  [ "$output" = "oversized-file:  lead.md: 401 lines > 400
oversized-file: docs/a${tab}b.md: 401 lines > 400
oversized-file: docs/a b.md: 401 lines > 400" ]
}

@test "unterminated last line counts" {
  local dir
  dir=$(make_fixture_root unterminated)
  mkdir -p "$dir/docs"
  # Command substitution strips the trailing newline `seq`'s output ends
  # with, leaving 401 lines with no terminating newline on the last one.
  printf '%s' "$(seq 401)" >"$dir/docs/a.md"
  git -C "$dir" add docs/a.md

  run --separate-stderr "$SCRIPT" "$dir"
  [ "$status" -eq 1 ]
  [ "$output" = "oversized-file: docs/a.md: 401 lines > 400" ]
}

@test "extra argument exits 2" {
  local dir
  dir=$(make_fixture_root extra-arg)
  mkdir -p "$dir/docs"
  # Oversized, so a script that ignored the extra argument, or checked it
  # only after the walk, would print an overage line: the empty stdout
  # below then pins the refusal to before the walk.
  seq 401 >"$dir/docs/a.md"
  git -C "$dir" add docs/a.md

  # The extra argument is itself a valid root, so no failure but the
  # argument check can exit 2 — `extra` would also exit 2 from a script
  # that took the last argument as ROOT and failed `git ls-files` on it.
  # Joining the arguments into one ROOT ("$*") still fails there, so stderr
  # names the refusal.
  run --separate-stderr "$SCRIPT" "$dir" "$dir"
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  [ "$stderr" = "check-line-limits: unexpected extra argument: $dir" ]
}

@test "oversized markdown survives BSD mktemp" {
  local dir bsd
  dir=$(make_fixture_root bsd-mktemp)
  mkdir -p "$dir/docs"
  seq 401 >"$dir/docs/a.md"
  git -C "$dir" add docs/a.md

  # A portability smoke run, not a mutation-proven case: the script's one
  # `mktemp` template ends in X, which the stub hands to the real tool, and
  # it only refuses a literal template whose file already exists — which a
  # single run with the trap's cleanup never leaves behind.
  bsd="$BATS_TEST_TMPDIR/bsdtools"
  make_bsd_stubs "$bsd" mktemp

  PATH="$bsd:$PATH" run --separate-stderr "$SCRIPT" "$dir"
  [ "$status" -eq 1 ]
  [ "$output" = "oversized-file: docs/a.md: 401 lines > 400" ]
}
