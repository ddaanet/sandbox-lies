#!/usr/bin/env bats
# FR-11, the code half of the sweep: no tracked file under a code dir fires a
# detector when read back, except the recorded fixtures under tests/fixtures/,
# which fire by design. tests/docs.bats sweeps the other half;
# tests/helpers/sweep.bash holds the predicate that splits them.

ROOT="${BATS_TEST_DIRNAME}/.."
MATCHERS="$ROOT/lib/matchers.sh"

load helpers/bsd-stubs
load helpers/git-env
load helpers/sweep

# A line that fires the phantom-chardev detector, built from fragments so this
# file stays quiet under the sweep.
firing_line() {
  printf '%s%s  1 root root 1, 3 Jan  1 00:00 %s\n' c rw-rw-rw- .bashrc
}

@test "no tracked code file outside the fixtures fires a detector" {
  sweep_side code
  [ "$SWEPT" -gt 0 ]
  [ -z "$FIRING" ] || {
    echo "files firing a detector or failing the matchers:$FIRING" >&2
    return 1
  }
}

# A stub either refuses or runs the real tool, so under the stubs a file can
# fire only where it fires plainly: a second sweep would find nothing the
# first misses. What the stubs add is the refusal, on stderr whether or not
# its matcher would have fired, and every matcher runs on every input. The
# exempt files reach git-lock's follow-on grep; lib/ and hooks/, which hold
# the matchers' own patterns, reach the other matchers' later stages.
@test "the matchers give the plain verdicts and refuse no BSD sed or grep call" {
  local bsd="$BATS_TEST_TMPDIR/bsdtools" err="$BATS_TEST_TMPDIR/stubbed-err"
  local path plain stubbed
  local -a inputs=("${EXEMPT[@]}")
  make_bsd_stubs "$bsd" sed grep
  while IFS= read -r -d '' path; do
    inputs+=("$path")
  done < <(git -C "$ROOT" ls-files -z -- lib hooks)
  [ "${#inputs[@]}" -gt "${#EXEMPT[@]}" ]
  for path in "${inputs[@]}"; do
    # `detect` exits 1 when nothing fires: that must reach the comparison.
    plain=$(bash "$MATCHERS" <"$ROOT/$path") || :
    stubbed=$(PATH="$bsd:$PATH" bash "$MATCHERS" <"$ROOT/$path" 2>"$err") || :
    if is_exempt "$path"; then [ -n "$plain" ]; fi
    [ "$stubbed" = "$plain" ] || {
      echo "$path: stubbed [$stubbed], plain [$plain]" >&2
      return 1
    }
    [ ! -s "$err" ] || { echo "$path:" >&2; cat "$err" >&2; return 1; }
  done
}

@test "is_code_path puts a path under a code dir on the code side, everything else on the docs side" {
  local path
  for path in lib/matchers.sh hooks/hooks.json scripts/lib/tracked.sh bin/sandbox-lies-recover \
    tests/fixtures/fire-x.txt "tests/sp ace.bats" plugin-dev/README.md; do
    is_code_path "$path"
  done
  # Docs side: a root file, a docs dir, a dir that only starts like a code dir,
  # and a code dir name nested below a docs dir.
  for path in justfile TODO.md lib docs/design.md libs/x.sh tests.md plans/lib/x.sh \
    skills/hooks/SKILL.md; do
    run is_code_path "$path"
    [ "$status" -eq 1 ]
  done
}

@test "the sweep splits the tracked files: each side reads its own and fires on its own" {
  local dir="$BATS_TEST_TMPDIR/split"
  mkdir -p "$dir/lib" "$dir/docs" "$dir/tests/fixtures" "$dir/sp ace"
  firing_line >"$dir/lib/code.sh"
  firing_line >"$dir/docs/prose.md"
  firing_line >"$dir/sp ace/prose.md"
  firing_line >"$dir/tests/fixtures/fire-x.txt"
  firing_line >"$dir/TODO.md"
  printf 'quiet\n' >"$dir/lib/quiet.sh"
  git -C "$dir" init -q
  git -C "$dir" add -A

  sweep_side code "$dir"
  [ "$SWEPT" -eq 2 ]
  [ "$FIRING" = $'\n  lib/code.sh: phantom-chardev' ]

  sweep_side docs "$dir"
  [ "$SWEPT" -eq 2 ]
  [[ "$FIRING" == *"  docs/prose.md: phantom-chardev"* ]]
  [[ "$FIRING" == *"  sp ace/prose.md: phantom-chardev"* ]]
  [[ "$FIRING" != *code.sh* && "$FIRING" != *fixtures* && "$FIRING" != *TODO.md* ]]
}

@test "the predicate's code dirs are the justfile's code_dirs" {
  run just --justfile "$ROOT/justfile" --evaluate code_dirs
  [ "$status" -eq 0 ]
  [ "$output" = "${SWEEP_CODE_DIRS[*]}" ]
}
