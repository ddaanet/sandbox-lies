#!/usr/bin/env bats
# Editing TASK.md or TODO.md leaves the main gate's cached pass standing, and
# `precommit` still refuses a firing one through `task-files`, a file over the
# byte cap through `check-size` and a skill without a description through
# `check-frontmatter`. The real
# `precommit` runs in a scratch repository holding what the working tree holds,
# so uncommitted work is what is tested and no commit of this repository is an
# input, with its own quiet TODO.md and TASK.md, so the real ones' content does
# not reach this suite. The script and recipe cases are in tests/task-files.bats.

ROOT="${BATS_TEST_DIRNAME}/.."

load helpers/bsd-stubs
load helpers/git-env

# A line that fires the phantom-chardev detector, built from fragments so this
# file stays quiet under the tests/docs.bats sweep.
firing_line() {
  printf '%s%s  1 root root 1, 3 Jan  1 00:00 %s\n' c rw-rw-rw- .bashrc
}

# Copy into $2 the tracked and untracked non-ignored files of the work tree $1:
# regular files and symlinks only, so a gitlink's contents, a path deleted from
# the work tree and a sandbox's char-device mask stay out. Through a
# NUL-delimited list and an archive file, so names with whitespace survive and
# a failure of git or tar stops the case, which a pipe would hide. Writes to $3
# the NUL-delimited paths among them that $1 tracks.
copy_work_tree() {
  local src="$1" dst="$2" tracked="$3" scratch list index others meta path mode
  scratch=$(mktemp -d "$BATS_TEST_TMPDIR/copy.XXXXXX")
  list="$scratch/list" index="$scratch/index" others="$scratch/others"
  git -C "$src" ls-files -z -s >"$index"
  git -C "$src" ls-files -z --others --exclude-standard >"$others"
  : >"$list"
  : >"$tracked"
  # `-s` prefixes each path with `<mode> <object> <stage>` and a tab; 160000 is
  # a gitlink.
  while IFS= read -r -d '' meta; do
    path=${meta#*$'\t'}
    mode=${meta%% *}
    [ "$mode" != 160000 ] || continue
    if [ -f "$src/$path" ] || [ -L "$src/$path" ]; then
      printf '%s\0' "$path" >>"$list"
      printf '%s\0' "$path" >>"$tracked"
    fi
  done <"$index"
  while IFS= read -r -d '' path; do
    if [ -f "$src/$path" ] || [ -L "$src/$path" ]; then
      printf '%s\0' "$path" >>"$list"
    fi
  done <"$others"
  tar -cf "$scratch/tree.tar" -C "$src" --null -T "$list"
  mkdir -p "$dst"
  tar -xf "$scratch/tree.tar" -C "$dst"
}

# A fresh repository holding what this working tree holds. A file tracked there
# and still on disk is tracked here, so an unrelated untracked draft stays out
# of the tracked-only checks in both. TODO.md and TASK.md are replaced by a
# quiet line. shellcheck and rumdl are stubs and the tree's bats runner a spy
# appending a line to $SPY_LOG: the cases are about whether the gate runs, and
# the slow checks are not what they assert.
make_gate_tree() {
  GATE_TREE="$BATS_TEST_TMPDIR/gate-tree"
  STUBS="$BATS_TEST_TMPDIR/stubs"
  SPY_LOG="$BATS_TEST_TMPDIR/bats-runs"
  copy_work_tree "$ROOT" "$GATE_TREE" "$BATS_TEST_TMPDIR/tracked"
  printf 'quiet\n' >"$GATE_TREE/TODO.md"
  printf 'quiet\n' >"$GATE_TREE/TASK.md"
  git -C "$GATE_TREE" init -q
  # -f: a file tracked there despite .gitignore stays tracked here.
  xargs -0 git --literal-pathspecs -C "$GATE_TREE" add -f -- \
    <"$BATS_TEST_TMPDIR/tracked"
  git -C "$GATE_TREE" commit -q -m scratch
  mkdir -p "$STUBS"
  printf '#!/bin/sh\nexit 0\n' >"$STUBS/shellcheck"
  cp "$STUBS/shellcheck" "$STUBS/rumdl"
  chmod 755 "$STUBS/shellcheck" "$STUBS/rumdl"
  printf '#!/bin/sh\necho run >>"%s"\nexit 0\n' "$SPY_LOG" \
    >"$GATE_TREE/plugin-dev/run-bats.sh"
  : >"$SPY_LOG"
}

# The real `just precommit` in the gate tree, on a PATH with the stubs first and
# a sentinel directory of its own.
run_gate() {
  cd "$GATE_TREE" && PATH="$STUBS:$PATH" run env -u PLUGIN_DEV_GATE_FORCE \
    -u PLUGIN_DEV_GATE_DIR just precommit
}

spy_runs() {
  wc -l <"$SPY_LOG" | tr -d ' '
}

@test "editing TODO.md or TASK.md leaves the main gate cached; another root input does not" {
  make_gate_tree
  run_gate
  [ "$status" -eq 0 ] || { echo "$output" >&2; return 1; }
  [[ "$output" == *"precommit passed:"* ]]
  [ "$(spy_runs)" -eq 1 ]

  local f
  for f in TODO.md TASK.md; do
    printf 'one more line\n' >>"$GATE_TREE/$f"
    run_gate
    [ "$status" -eq 0 ]
    [[ "$output" == *"precommit: cached"* ]]
    [[ "$output" == *"task-files passed"* ]]
    [ "$(spy_runs)" -eq 1 ]
  done

  # Control: an edit to another root markdown input is not cached, or the
  # assertions above would hold of a gate that never reruns.
  printf 'one more line\n' >>"$GATE_TREE/README.md"
  run_gate
  [ "$status" -eq 0 ]
  [[ "$output" == *"precommit passed:"* ]]
  [[ "$output" != *"precommit: cached"* ]]
  [ "$(spy_runs)" -eq 2 ]
}

@test "precommit refuses a firing TODO.md through task-files before the main gate runs" {
  make_gate_tree
  firing_line >"$GATE_TREE/TODO.md"
  run_gate
  [ "$status" -ne 0 ]
  [[ "$output" == *TODO.md* ]]
  [[ "$output" == *phantom-chardev* ]]
  [[ "$output" != *"precommit passed"* ]]
  [ "$(spy_runs)" -eq 0 ]
}

@test "precommit refuses a file over the byte cap, tracked or untracked, naming it" {
  make_gate_tree
  # Built at run time: this file stays under the cap itself.
  head -c 20001 /dev/zero | tr '\0' x >"$GATE_TREE/untracked-big.txt"
  head -c 20001 /dev/zero | tr '\0' x >>"$GATE_TREE/CLAUDE.md"
  run_gate
  [ "$status" -ne 0 ]
  [[ "$output" == *"oversized-file: untracked-big.txt"* ]]
  [[ "$output" == *"oversized-file: CLAUDE.md"* ]]
  [[ "$output" != *"precommit passed"* ]]
  [ "$(spy_runs)" -eq 0 ]
}

@test "precommit refuses a skill whose frontmatter lacks a description" {
  make_gate_tree
  local skill="$GATE_TREE/skills/sandbox-lies/SKILL.md"
  grep -v '^description:' "$skill" >"$skill.new"
  mv "$skill.new" "$skill"
  run_gate
  [ "$status" -ne 0 ]
  [[ "$output" == *"skills/sandbox-lies/SKILL.md"* ]]
  [[ "$output" == *description* ]]
  [[ "$output" != *"precommit passed"* ]]
  [ "$(spy_runs)" -eq 0 ]
}

@test "copy_work_tree takes tracked and untracked files, whitespace intact, and nothing else" {
  local src="$BATS_TEST_TMPDIR/src" dst="$BATS_TEST_TMPDIR/dst" sha
  mkdir -p "$src/sp ace/deep" "$src/link/inside"
  git -C "$src" init -q
  printf 'ignored.txt\n' >"$src/.gitignore"
  printf 'tracked\n' >"$src/sp ace/deep/tra cked.txt"
  printf 'x\ty\n' >"$src/ta"$'\t'"b.txt"
  printf '#!/bin/sh\n' >"$src/run.sh"
  chmod 755 "$src/run.sh"
  printf 'gone\n' >"$src/gone.txt"
  git -C "$src" add -A
  git -C "$src" commit -q -m base
  sha=$(git -C "$src" rev-parse HEAD)
  git -C "$src" update-index --add --cacheinfo "160000,$sha,link"
  printf 'inside the gitlink\n' >"$src/link/inside/file"
  rm "$src/gone.txt"
  printf 'untracked\n' >"$src/un tracked.txt"
  printf 'ignored\n' >"$src/ignored.txt"

  copy_work_tree "$src" "$dst" "$BATS_TEST_TMPDIR/tracked"

  [ -f "$dst/sp ace/deep/tra cked.txt" ]
  [ -f "$dst/ta"$'\t'"b.txt" ]
  [ -f "$dst/un tracked.txt" ]
  [ -x "$dst/run.sh" ]
  [ ! -e "$dst/link" ]
  [ ! -e "$dst/gone.txt" ]
  [ ! -e "$dst/ignored.txt" ]
  # The untracked file is copied but not reported as tracked; the others are.
  local want
  want=$(printf '%s\n' .gitignore run.sh 'sp ace/deep/tra cked.txt' $'ta\tb.txt')
  [ "$(tr '\0' '\n' <"$BATS_TEST_TMPDIR/tracked" | LC_ALL=C sort)" = "$want" ]
}
