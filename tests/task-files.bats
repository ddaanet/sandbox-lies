#!/usr/bin/env bats
# TASK.md and TODO.md have a gate of their own: `just task-files`, which
# `precommit` depends on and which is never cached. The cached gates stop reading
# them, so an edit to either leaves their cached passes standing.
#
# - `--task-files` on scripts/check-links.sh;
# - the recipe, run over a scratch tree holding the justfile, scripts/ and lib/;
# - the tests/docs.bats sweep skipping both, run over a scratch tree.
#
# The real `precommit` in a scratch repository is in tests/task-files-cache.bats.

load helpers/fixture-root
load helpers/bsd-stubs
load helpers/git-env
load helpers/sweep

LINKS="$ROOT/scripts/check-links.sh"

# A git root holding the named root files, each tracked and quiet (one line).
make_root() {
  local dir f
  dir=$(make_fixture_root "$1")
  shift
  for f in "$@"; do
    printf 'quiet\n' >"$dir/$f"
  done
  git -C "$dir" add -- "$@"
  printf '%s\n' "$dir"
}

# A scratch tree the recipe runs in: the real justfile and the code it calls,
# with TODO.md and TASK.md tracked and quiet.
make_recipe_tree() {
  local dir
  dir=$(make_root "$1" TODO.md TASK.md)
  mkdir -p "$dir/plugin-dev"
  cp "$ROOT/justfile" "$dir/"
  cp "$ROOT/plugin-dev/release.just" "$ROOT/plugin-dev/gates.just" \
    "$dir/plugin-dev/"
  cp -R "$ROOT/scripts" "$ROOT/lib" "$dir/"
  git -C "$dir" add justfile plugin-dev scripts lib
  printf '%s\n' "$dir"
}

run_recipe() {
  local dir="$1"
  shift
  cd "$dir" && run --separate-stderr just task-files "$@"
}

# ---- --task-files on the two scripts ----

@test "--task-files reports a broken link in TODO.md and TASK.md; the plain run passes them" {
  local f dir
  for f in TODO.md TASK.md; do
    dir=$(make_root "link-$f" "$f")
    printf '[m](missing.md)\n' >"$dir/$f"

    run --separate-stderr "$LINKS" --task-files "$dir"
    [ "$status" -eq 1 ]
    [ "$output" = "broken-link: $f -> missing.md" ]

    run --separate-stderr "$LINKS" "$dir"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
  done
}

@test "--task-files passes resolving links" {
  local dir
  dir=$(make_root resolving TODO.md TASK.md)
  printf '[t](TASK.md)\n' >"$dir/TODO.md"
  run --separate-stderr "$LINKS" --task-files "$dir"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "the plain runs still check other root markdown; --task-files leaves it alone" {
  local dir
  dir=$(make_root others TODO.md NOTES.md)
  printf '[m](missing.md)\n' >"$dir/NOTES.md"

  run --separate-stderr "$LINKS" "$dir"
  [ "$status" -eq 1 ]
  [ "$output" = "broken-link: NOTES.md -> missing.md" ]

  run --separate-stderr "$LINKS" --task-files "$dir"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "--task-files covers the root files only, and only tracked ones" {
  local dir
  dir=$(make_root rootonly TASK.md)
  mkdir -p "$dir/docs"
  printf '[m](missing.md)\n' >"$dir/docs/TODO.md"
  printf '[m](missing.md)\n' >"$dir/TODO.md"
  git -C "$dir" add docs/TODO.md

  # docs/TODO.md is tracked and in the plain scope; the root TODO.md is
  # untracked. Neither is a task file the flag walks.
  run --separate-stderr "$LINKS" --task-files "$dir"
  [ "$status" -eq 0 ]
  [ -z "$output" ]

  # Control: the plain run does read docs/TODO.md.
  run --separate-stderr "$LINKS" "$dir"
  [ "$status" -eq 1 ]
  [ "$output" = "broken-link: docs/TODO.md -> missing.md" ]
}

@test "--task-files takes ROOT from the current directory when none follows" {
  local dir
  dir=$(make_root cwdroot TODO.md)
  printf '[m](missing.md)\n' >"$dir/TODO.md"
  cd "$dir"
  run --separate-stderr "$LINKS" --task-files
  [ "$status" -eq 1 ]
  [ "$output" = "broken-link: TODO.md -> missing.md" ]
}

@test "check-links still refuses an extra argument, with or without the flag" {
  local dir
  dir=$(make_root extra TODO.md)
  run --separate-stderr "$LINKS" "$dir" extra
  [ "$status" -eq 2 ]
  # shellcheck disable=SC2154 # set by bats' run --separate-stderr
  [ "$stderr" = "check-links: unexpected extra argument: extra" ]
  run --separate-stderr "$LINKS" --task-files "$dir" extra
  [ "$status" -eq 2 ]
  # shellcheck disable=SC2154
  [ "$stderr" = "check-links: unexpected extra argument: extra" ]
}

@test "the flag case holds with BSD sed, grep and mktemp ahead on PATH" {
  local bsd="$BATS_TEST_TMPDIR/bsdtools" dir
  make_bsd_stubs "$bsd" sed grep mktemp
  dir=$(make_root bsdroot TODO.md)
  printf '[m](missing.md)\n' >"$dir/TODO.md"
  PATH="$bsd:$PATH" run --separate-stderr "$LINKS" --task-files "$dir"
  [ "$status" -eq 1 ]
  [ "$output" = "broken-link: TODO.md -> missing.md" ]
}

# ---- the recipe ----

@test "task-files passes quiet files with one line listing the checks" {
  local dir
  dir=$(make_recipe_tree quiet)
  run_recipe "$dir"
  [ "$status" -eq 0 ]
  [ "$output" = "task-files passed: matchers, links" ]
}

@test "task-files fails naming a file that fires a detector" {
  local dir f
  for f in TODO.md TASK.md; do
    dir=$(make_recipe_tree "fires-$f")
    firing_line >"$dir/$f"
    run_recipe "$dir"
    [ "$status" -ne 0 ]
    [[ "$stderr$output" == *"$f"* ]]
    [[ "$stderr$output" == *phantom-chardev* ]]
    [[ "$output" != *"task-files passed"* ]]
  done
}

@test "task-files fails on a broken link, with the check's output" {
  local dir
  dir=$(make_recipe_tree brokenlink)
  printf '[m](missing.md)\n' >"$dir/TASK.md"
  run_recipe "$dir"
  [ "$status" -ne 0 ]
  [[ "$output" == *"broken-link: TASK.md -> missing.md"* ]]
  [[ "$output" != *"task-files passed"* ]]
}

@test "task-files fails when the matchers themselves fail" {
  local dir
  dir=$(make_recipe_tree matcherfail)
  printf '#!/usr/bin/env bash\nexit 3\n' >"$dir/lib/matchers.sh"
  run_recipe "$dir"
  [ "$status" -ne 0 ]
  [[ "$stderr$output" == *TODO.md* ]]
  [[ "$stderr$output" == *"exited 3"* ]]
}

@test "task-files fails on a file the matchers cannot read, not reading it as quiet" {
  if [ "$(id -u)" -eq 0 ]; then
    skip "running as root: chmod 000 does not block reads"
  fi
  local dir
  dir=$(make_recipe_tree unreadable)
  chmod 000 "$dir/TASK.md"
  run_recipe "$dir"
  [ "$status" -ne 0 ]
  # The matchers step's own report: the link check would also stop on the
  # file, and a matchers step that read it as quiet would leave that one.
  [[ "$stderr" == *"task-files: cannot read TASK.md"* ]]
  [[ "$output" != *"task-files passed"* ]]
}

@test "task-files walks only tracked files: a removed one is no error" {
  local dir
  dir=$(make_recipe_tree removed)
  git -C "$dir" rm -q -f TASK.md
  run_recipe "$dir"
  [ "$status" -eq 0 ]
  [ "$output" = "task-files passed: matchers, links" ]

  # Gone from the work tree but still in the index.
  dir=$(make_recipe_tree deleted)
  rm "$dir/TODO.md"
  run_recipe "$dir"
  [ "$status" -eq 0 ]
  [ "$output" = "task-files passed: matchers, links" ]

  # Untracked and firing: not walked.
  dir=$(make_recipe_tree untracked)
  git -C "$dir" rm -q -f --cached TODO.md
  firing_line >"$dir/TODO.md"
  run_recipe "$dir"
  [ "$status" -eq 0 ]
}

@test "task-files fires and passes the same with BSD sed, grep and mktemp ahead on PATH" {
  local bsd="$BATS_TEST_TMPDIR/bsdtools" dir
  make_bsd_stubs "$bsd" sed grep mktemp
  dir=$(make_recipe_tree bsd)
  PATH="$bsd:$PATH" run_recipe "$dir"
  [ "$status" -eq 0 ]
  [ "$output" = "task-files passed: matchers, links" ]
  firing_line >"$dir/TODO.md"
  PATH="$bsd:$PATH" run_recipe "$dir"
  [ "$status" -ne 0 ]
  [[ "$stderr$output" == *phantom-chardev* ]]
}

# ---- the cached gates stop reading them ----

@test "the docs.bats sweep ignores a firing TODO.md and TASK.md, and still catches other files" {
  # A scratch tree holding the real suite, its helpers and matchers, and the
  # three exempt files the suite insists still fire.
  local dir e
  dir=$(make_fixture_root sweep)
  mkdir -p "$dir/tests" "$dir/plans"
  cp "$ROOT/tests/docs.bats" "$dir/tests/"
  cp -R "$ROOT/tests/helpers" "$dir/tests/"
  cp -R "$ROOT/lib" "$dir/"
  for e in 2026-09-02-sandbox-detector-replay.py \
    2026-09-02-sandbox-detector-hits.jsonl \
    2026-09-03-sandbox-matcher-corpus-eval.md; do
    cp "$ROOT/plans/$e" "$dir/plans/"
  done
  firing_line >"$dir/TODO.md"
  firing_line >"$dir/TASK.md"
  # The docs half of the sweep needs a file to read besides the exempt ones.
  printf 'quiet\n' >"$dir/README.md"
  git -C "$dir" add -A

  cd "$dir"
  run bats --filter 'no tracked file outside the fixtures' tests/docs.bats
  [ "$status" -eq 0 ] || { echo "$output" >&2; return 1; }
  [[ "$output" == *"ok 1 no tracked file outside the fixtures fires a detector"* ]]

  # Control: the same line in any other file fails the sweep, naming it.
  firing_line >"$dir/NOTES.md"
  git -C "$dir" add NOTES.md
  run bats --filter 'no tracked file outside the fixtures' tests/docs.bats
  [ "$status" -ne 0 ]
  [[ "$output" == *"NOTES.md: phantom-chardev"* ]]
  [[ "$output" != *"TODO.md: phantom"* ]]
  [[ "$output" != *"TASK.md: phantom"* ]]
}

@test "markdown_in_scope turns away the root TASK.md and TODO.md only" {
  local path want
  for want in NOTES.md:0 docs/TODO.md:0 skills/TASK.md:0 TODO.md:1 TASK.md:1; do
    path=${want%:*}
    run bash -c 'source "$1/scripts/lib/tracked.sh"; markdown_in_scope "$2"' \
      _ "$ROOT" "$path"
    [ "$status" -eq "${want##*:}" ]
  done
}
