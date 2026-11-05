#!/usr/bin/env bats
# Editing TASK.md or TODO.md leaves both gates' cached passes standing, and
# `precommit` still refuses a firing one through `task-files`, a file over the
# byte cap through `check-size` and a skill without a description through
# `check-frontmatter`. The real `precommit` runs in a scratch repository
# holding what the working tree holds (tests/helpers/gate-tree.bash), so
# uncommitted work is what is tested and no commit of this repository is an
# input, with its own quiet TODO.md and TASK.md, so the real ones' content does
# not reach this suite. Which gate an edit reruns is in tests/gate-coverage.bats;
# the script and recipe cases are in tests/task-files.bats.

# shellcheck disable=SC2034 # read by tests/helpers/gate-tree.bash
ROOT="${BATS_TEST_DIRNAME}/.."

load helpers/bsd-stubs
load helpers/git-env
load helpers/gate-tree

# A line that fires the phantom-chardev detector, built from fragments so this
# file stays quiet under the tests/sweep-code.bats sweep.
firing_line() {
  printf '%s%s  1 root root 1, 3 Jan  1 00:00 %s\n' c rw-rw-rw- .bashrc
}

@test "editing TODO.md or TASK.md leaves both gates cached; a root markdown file reruns gate-docs alone" {
  make_gate_tree
  run_gate
  [ "$status" -eq 0 ] || { echo "$output" >&2; return 1; }
  [[ "$output" == *"gate-docs passed:"* ]]
  [[ "$output" == *"gate-code passed:"* ]]
  [[ "$output" == *"precommit passed: check-refs, check-size, check-frontmatter, task-files, gate-docs, gate-code"* ]]
  [ "$(spy_docs_runs)" -eq 1 ]
  [ "$(spy_code_runs)" -eq 1 ]

  local f
  for f in TODO.md TASK.md; do
    printf 'one more line\n' >>"$GATE_TREE/$f"
    run_gate
    [ "$status" -eq 0 ]
    [[ "$output" == *"gate-docs: cached"* ]]
    [[ "$output" == *"gate-code: cached"* ]]
    [[ "$output" == *"task-files passed"* ]]
    [[ "$output" == *"precommit passed:"* ]]
    [ "$(spy_runs)" -eq 2 ]
  done

  # Control: an edit to another root markdown file reruns gate-docs, or the
  # assertions above would hold of gates that never rerun, and leaves gate-code
  # cached.
  printf 'one more line\n' >>"$GATE_TREE/README.md"
  run_gate
  [ "$status" -eq 0 ]
  [[ "$output" == *"gate-docs passed:"* ]]
  [[ "$output" == *"gate-code: cached"* ]]
  [ "$(spy_docs_runs)" -eq 2 ]
  [ "$(spy_code_runs)" -eq 1 ]
}

@test "precommit refuses a firing TODO.md through task-files before either gate runs" {
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

@test "precommit refuses a TODO.md past the byte cap after a cached pass" {
  make_gate_tree
  run_gate
  [ "$status" -eq 0 ] || { echo "$output" >&2; return 1; }
  [ "$(spy_runs)" -eq 2 ]

  # Built at run time: this file stays under the cap itself. A check inside a
  # guarded body would not see this edit: the gates' hashes exclude TODO.md.
  head -c 20001 /dev/zero | tr '\0' x >"$GATE_TREE/TODO.md"
  run_gate
  [ "$status" -ne 0 ]
  [[ "$output" == *"oversized-file: TODO.md"* ]]
  [[ "$output" != *"precommit passed"* ]]
  [ "$(spy_runs)" -eq 2 ]
}

@test "precommit refuses a skill whose frontmatter lacks a description" {
  make_gate_tree
  local skill rel="" f
  # Whichever skill the tree holds, so a rename elsewhere cannot stale this case.
  for f in "$GATE_TREE"/skills/*/SKILL.md; do
    [ -f "$f" ] && { skill=$f; rel=${f#"$GATE_TREE"/}; break; }
  done
  [ -n "$rel" ] || { echo "no skills/*/SKILL.md in the gate tree" >&2; return 1; }
  grep -v '^description:' "$skill" >"$skill.new"
  mv "$skill.new" "$skill"
  run_gate
  [ "$status" -ne 0 ]
  [[ "$output" == *"$rel"* ]]
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
