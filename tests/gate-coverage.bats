#!/usr/bin/env bats
# Which gate an edit reruns. `precommit` depends on two sentinel gates,
# gate-docs and gate-code (the justfile), and each is cached while the inputs
# it hashes are unchanged. Reasoning about the hash is the claim that fails, so
# these cases edit a file in the scratch repository that tests/helpers/
# gate-tree.bash builds from the working tree and run the two gates directly,
# the uncached dependencies left out: a code dir reruns gate-code alone, except
# the code files gate-docs's checks run; everything else reruns gate-docs alone;
# the justfile and plugin-dev/ rerun both. The cases in
# tests/task-files-cache.bats run the whole `precommit`.

# shellcheck disable=SC2034 # read by tests/helpers/gate-tree.bash
ROOT="${BATS_TEST_DIRNAME}/.."

load helpers/bsd-stubs
load helpers/git-env
load helpers/gate-tree

# The code files gate-docs's checks run, which rerun it as well as gate-code,
# and a frozen plans/ file gate-code's suites feed to the matchers, which
# rerun it as well as gate-docs.
BOTH_FILES=(
  plans/2026-09-02-sandbox-detector-hits.jsonl
  lib/matchers.sh tests/docs.bats tests/helpers/bsd-stubs.bash
  tests/helpers/git-env.bash tests/helpers/sweep.bash
  scripts/check-links.sh scripts/lib/tracked.sh scripts/lib/strip-code.awk
)

# One newline appended: valid at the end of JSON, shell, Python and markdown
# alike, and a new byte every time.
touch_file() {
  printf '\n' >>"$GATE_TREE/$1"
}

# touch_file <path>, run both gates, and expect_ran <docs> <code>.
edit_expecting() {
  local path="$1"
  touch_file "$path"
  run_gates
  expect_ran "$2" "$3" || { echo "edited: $path" >&2; return 1; }
}

# A tracked file of the gate tree's top-level directory $1.
first_file_under() {
  git -C "$GATE_TREE" ls-files -z -- "$1" | { IFS= read -r -d '' f && printf '%s' "$f"; }
}

# The gate tree's tracked top-level entries, NUL-delimited, gitlinks left out.
top_level_entries() {
  local meta path
  git -C "$GATE_TREE" ls-files -z -s | while IFS= read -r -d '' meta; do
    path=${meta#*$'\t'}
    [ "${meta%% *}" = 160000 ] || printf '%s\0' "${path%%/*}"
  done | LC_ALL=C sort -zu
}

is_code_dir() {
  local d
  for d in "${SWEEP_CODE_DIRS[@]}"; do [ "$1" != "$d" ] || return 0; done
  return 1
}

setup() {
  load helpers/sweep
  make_gate_tree
  run_gates
  expect_ran 1 1
}

@test "a file in a code dir reruns gate-code alone" {
  local path
  for path in lib/verdicts.sh hooks/annotate.sh scripts/run-bats-under.sh \
    bin/sandbox-lies-recover tests/matchers.bats tests/helpers/hook.bash \
    tests/extract-fixtures.py; do
    edit_expecting "$path" 0 1
  done
}

@test "the code files gate-docs's checks run and the frozen plans files gate-code reads rerun both gates" {
  local path
  run_gates
  expect_ran 0 0
  for path in "${BOTH_FILES[@]}"; do
    edit_expecting "$path" 1 1
  done
}

@test "the justfile and plugin-dev/ rerun both gates" {
  edit_expecting justfile 1 1
  edit_expecting plugin-dev/README.md 1 1
}

@test "every tracked top-level directory that is not a code dir reruns gate-docs alone" {
  local top sample seen=0
  while IFS= read -r -d '' top; do
    is_code_dir "$top" && continue
    [ -d "$GATE_TREE/$top" ] || continue
    sample=$(first_file_under "$top")
    edit_expecting "$sample" 1 0
    seen=$((seen + 1))
  done < <(top_level_entries)
  # plans/ and the dot-directories among them: a sample, not a hand list.
  [ "$seen" -ge 5 ]
}

@test "every tracked root file reruns gate-docs alone, the justfile both, TASK.md and TODO.md neither" {
  local top seen=0
  while IFS= read -r -d '' top; do
    [ -f "$GATE_TREE/$top" ] || continue
    case "$top" in
      justfile) edit_expecting "$top" 1 1 ;;
      TASK.md | TODO.md) edit_expecting "$top" 0 0 ;;
      *) edit_expecting "$top" 1 0 ;;
    esac
    seen=$((seen + 1))
  done < <(top_level_entries)
  [ "$seen" -ge 10 ]
}

@test "a newly tracked root file and a new top-level directory rerun gate-docs, with no justfile edit" {
  printf 'x\n' >"$GATE_TREE/new file.txt"
  mkdir -p "$GATE_TREE/new dir/sub dir"
  printf 'x\n' >"$GATE_TREE/new dir/sub dir/a b.txt"
  # Untracked, neither is read by a check: nothing reruns.
  run_gates
  expect_ran 0 0
  git -C "$GATE_TREE" add -- "new file.txt"
  run_gates
  expect_ran 1 0
  git -C "$GATE_TREE" add -- "new dir"
  run_gates
  expect_ran 1 0
  # Now hashed by content, not just by name.
  edit_expecting "new dir/sub dir/a b.txt" 1 0
  edit_expecting "new file.txt" 1 0
}

@test "git add of a previously untracked file reruns the gate on its side" {
  # Created, the file is an untracked input of the dir that holds it: its own
  # side reruns. Added, only the tracked-set line has moved.
  printf 'x\n' >"$GATE_TREE/docs/new note.txt"
  run_gates
  expect_ran 1 0
  git -C "$GATE_TREE" add -- "docs/new note.txt"
  run_gates
  expect_ran 1 0

  printf 'x\n' >"$GATE_TREE/tests/new note.txt"
  run_gates
  expect_ran 0 1
  git -C "$GATE_TREE" add -- "tests/new note.txt"
  run_gates
  expect_ran 0 1
}

@test "an untracked root dotfile or other root file reruns nothing; an untracked root markdown file reruns gate-docs" {
  # Named for no real dotfile: the command sandbox refuses writes to the real
  # names (.bashrc, .mcp.json), which is where the untracked masks come from.
  printf 'x\n' >"$GATE_TREE/.draft-dotfile"
  printf 'x\n' >"$GATE_TREE/.draft-dotfile.json"
  printf 'x\n' >"$GATE_TREE/scratch.txt"
  run_gates
  expect_ran 0 0
  printf 'x\n' >"$GATE_TREE/draft.md"
  run_gates
  expect_ran 1 0
}

@test "each gate's tool lines reach its own hash: shellcheck and the memory file rerun gate-code alone" {
  printf 'ShellCheck 9.9.9\n' >"$STUBS/shellcheck.version"
  run_gates
  expect_ran 0 1
  mkdir -p "$GATE_TREE/memory/ddaanet"
  printf 'a fact\n' >"$GATE_TREE/memory/ddaanet/sandbox-effects.md"
  run_gates
  expect_ran 0 1
  printf 'another fact\n' >>"$GATE_TREE/memory/ddaanet/sandbox-effects.md"
  run_gates
  expect_ran 0 1
}
