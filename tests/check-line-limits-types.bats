#!/usr/bin/env bats
# scripts/check-line-limits.sh's script-type caps (shell, Python, awk, TOML,
# JSON, justfile) and the root-level exclusions. The markdown caps and the
# walk's failure modes are in check-line-limits.bats.

load helpers/fixture-root
load helpers/bsd-stubs
load helpers/git-env

SCRIPT="$ROOT/scripts/check-line-limits.sh"

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

@test "oversized awk is reported" {
  local dir
  dir=$(make_fixture_root awk)
  mkdir -p "$dir/lib"
  # 401 lines: one over the 400 cap the awk arm shares with the script arm.
  # The exact "> 400" pins the cap, and the path pins the arm to `*.awk` at
  # depth, not only a root-level `.awk`.
  seq 401 >"$dir/lib/x.awk"
  git -C "$dir" add lib/x.awk

  run --separate-stderr "$SCRIPT" "$dir"
  [ "$status" -eq 1 ]
  [ "$output" = "oversized-file: lib/x.awk: 401 lines > 400" ]
}

@test "fixtures are out of the awk, TOML and JSON cap" {
  local dir
  dir=$(make_fixture_root fixtures)
  mkdir -p "$dir/tests/fixtures" "$dir/lib"
  # Over the cap, under tests/fixtures/: left unreported. The same 401 lines
  # under lib/ pin the cap, and an arm that caps fixtures reports both
  # fixture lines too.
  # Only tests/fixtures/ is excluded: lib/ and tests/ itself are capped.
  seq 401 >"$dir/tests/fixtures/x.json"
  seq 401 >"$dir/tests/fixtures/y.awk"
  seq 401 >"$dir/lib/x.json"
  seq 401 >"$dir/tests/o.json"
  git -C "$dir" add tests/fixtures/x.json tests/fixtures/y.awk lib/x.json tests/o.json

  run --separate-stderr "$SCRIPT" "$dir"
  [ "$status" -eq 1 ]
  [ "$output" = "oversized-file: lib/x.json: 401 lines > 400
oversized-file: tests/o.json: 401 lines > 400" ]
}

@test "justfile and TOML are capped at any depth" {
  local dir
  dir=$(make_fixture_root justfile-toml)
  mkdir -p "$dir/sub"
  # One per arm: a root justfile, a justfile under sub/ (`*/justfile`), and
  # a TOML file. Dropping any one drops its line from the exact output.
  seq 401 >"$dir/config.toml"
  seq 401 >"$dir/justfile"
  seq 401 >"$dir/sub/justfile"
  git -C "$dir" add config.toml justfile sub/justfile

  run --separate-stderr "$SCRIPT" "$dir"
  [ "$status" -eq 1 ]
  [ "$output" = "oversized-file: config.toml: 401 lines > 400
oversized-file: justfile: 401 lines > 400
oversized-file: sub/justfile: 401 lines > 400" ]
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

@test "plans/ and plugin-dev/ are out of the awk, TOML, JSON and justfile cap" {
  local dir top name failed=""
  for top in plans plugin-dev; do
    for name in x.awk x.toml x.json justfile sub/justfile; do
      dir=$(make_fixture_root "excl-${top}-${name//\//-}")
      mkdir -p "$dir/$top/sub"
      # One type per root, so the failure names it. Over the cap, under a
      # root-level exclusion: an exclusion narrowed to the script types
      # leaves this file reported.
      seq 401 >"$dir/$top/$name"
      git -C "$dir" add "$top/$name"

      run --separate-stderr "$SCRIPT" "$dir"
      if [ "$status" -ne 0 ] || [ -n "$output" ] || [ -n "$stderr" ]; then
        failed="$failed $top/$name"
      fi
    done
  done
  # Every type is run before the verdict, so the message names all it caps.
  [ -z "$failed" ] || { echo "capped despite exclusion:$failed" >&2; return 1; }
}

@test "oversized script survives BSD mktemp" {
  local dir bsd
  dir=$(make_fixture_root bsd-mktemp-script)
  seq 401 >"$dir/x.sh"
  git -C "$dir" add x.sh

  # The script reaches `mktemp` through scripts/lib/tracked.sh, not `wc`
  # (it counts with `awk`). A portability smoke run, as in
  # check-line-limits.bats's markdown case, not a mutation-proven one.
  bsd="$BATS_TEST_TMPDIR/bsdtools"
  make_bsd_stubs "$bsd" mktemp

  PATH="$bsd:$PATH" run --separate-stderr "$SCRIPT" "$dir"
  [ "$status" -eq 1 ]
  [ "$output" = "oversized-file: x.sh: 401 lines > 400" ]
}
