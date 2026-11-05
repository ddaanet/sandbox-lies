#!/usr/bin/env bash
# Shared by tests/task-files-cache.bats and tests/gate-coverage.bats: the real
# gates run in a scratch repository holding what the working tree holds, so
# uncommitted work is what is tested and no commit of this repository is an
# input. The loading suite sets ROOT to the repository.

# Copy into $2 the tracked and untracked non-ignored files of the work tree $1:
# regular files and symlinks only, so a gitlink's contents, a path deleted from
# the work tree and a sandbox's char-device mask stay out. Through a
# NUL-delimited list and an archive file, so names with whitespace survive and
# a failure of git or tar stops the case, which a pipe would hide. Writes to $3
# the NUL-delimited paths among them that $1 tracks. Its scratch files go under
# $4, $BATS_TEST_TMPDIR by default, which setup_file has not got.
copy_work_tree() {
  local src="$1" dst="$2" tracked="$3" scratch list index others meta path mode
  scratch=$(mktemp -d "${4:-$BATS_TEST_TMPDIR}/copy.XXXXXX")
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
# quiet line. shellcheck and rumdl are stubs, each printing the contents of a
# `<stub>.version` file beside it for `--version` so a case can change a tool
# version, and the tree's bats runner a spy appending its arguments as one line
# to $SPY_LOG: the cases are about whether a gate runs, and the slow checks are
# not what they assert. Built under $1, $BATS_TEST_TMPDIR by default, which
# setup_file has not got. The spy appends to the bats-runs file beside the tree
# (the gates run with the tree as their working directory), and STUBS and
# SPY_LOG name the stubs directory and that file beside it, so the tree holds no
# path of its own and clone_gate_tree's copy is the same bytes.
make_gate_tree() {
  local base="${1:-$BATS_TEST_TMPDIR}"
  GATE_TREE="$base/gate-tree"
  STUBS="$base/stubs"
  SPY_LOG="$base/bats-runs"
  mkdir -p "$base"
  copy_work_tree "$ROOT" "$GATE_TREE" "$base/tracked" "$base"
  printf 'quiet\n' >"$GATE_TREE/TODO.md"
  printf 'quiet\n' >"$GATE_TREE/TASK.md"
  git -C "$GATE_TREE" init -q
  # -f: a file tracked there despite .gitignore stays tracked here.
  xargs -0 git --literal-pathspecs -C "$GATE_TREE" add -f -- \
    <"$base/tracked"
  git -C "$GATE_TREE" commit -q -m scratch
  mkdir -p "$STUBS"
  # shellcheck disable=SC2016 # $0 expands in the stub, not here
  printf '#!/bin/sh\ncat "$0.version" 2>/dev/null\nexit 0\n' >"$STUBS/shellcheck"
  cp "$STUBS/shellcheck" "$STUBS/rumdl"
  chmod 755 "$STUBS/shellcheck" "$STUBS/rumdl"
  # shellcheck disable=SC2016 # $PWD expands in the spy, not here
  printf '#!/bin/sh\necho "$*" >>"$PWD/../bats-runs"\nexit 0\n' \
    >"$GATE_TREE/plugin-dev/run-bats.sh"
  : >"$SPY_LOG"
}

# A private copy, in $BATS_TEST_TMPDIR, of the tree, stubs and spy log that
# make_gate_tree built under $1, with its sentinels: GATE_TREE, STUBS and
# SPY_LOG name the copy, so a case edits and runs it with nothing to undo.
clone_gate_tree() {
  local from="$1"
  cp -R "$from/gate-tree" "$from/stubs" "$from/bats-runs" "$BATS_TEST_TMPDIR/"
  GATE_TREE="$BATS_TEST_TMPDIR/gate-tree"
  STUBS="$BATS_TEST_TMPDIR/stubs"
  SPY_LOG="$BATS_TEST_TMPDIR/bats-runs"
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

# How many of the spy's runs were gate-docs's (the one suite it is given,
# tests/docs.bats) and how many gate-code's (all the others).
spy_docs_runs() {
  grep -cx 'tests/docs.bats' "$SPY_LOG" || :
}

spy_code_runs() {
  echo $(($(spy_runs) - $(spy_docs_runs)))
}

# run_gates: gate-docs then gate-code directly, the uncached checks left out.
# Sets RAN_DOCS and RAN_CODE to 1 for a gate that ran its checks and 0 for one
# that printed "cached", and fails when the printed line and the spy's log
# disagree, so a gate cannot be taken for having run on its say-so.
run_gates() {
  local gate out docs_before code_before
  docs_before=$(spy_docs_runs)
  code_before=$(spy_code_runs)
  RAN_DOCS=0
  RAN_CODE=0
  for gate in docs code; do
    out=$(cd "$GATE_TREE" && PATH="$STUBS:$PATH" env -u PLUGIN_DEV_GATE_FORCE \
      -u PLUGIN_DEV_GATE_DIR just "gate-$gate" 2>&1) || {
      printf '%s\n' "$out" >&2
      return 1
    }
    case "$out" in
      "gate-$gate: cached (inputs unchanged)") ;;
      *"gate-$gate passed: "*)
        if [ "$gate" = docs ]; then RAN_DOCS=1; else RAN_CODE=1; fi
        ;;
      *) printf 'unexpected gate-%s output: %s\n' "$gate" "$out" >&2; return 1 ;;
    esac
  done
  [ "$(spy_docs_runs)" -eq $((docs_before + RAN_DOCS)) ]
  [ "$(spy_code_runs)" -eq $((code_before + RAN_CODE)) ]
}

# expect_ran <docs> <code>: what the last run_gates ran, 1 or 0 each.
expect_ran() {
  if [ "$RAN_DOCS" -ne "$1" ] || [ "$RAN_CODE" -ne "$2" ]; then
    printf 'gate-docs ran=%s (want %s), gate-code ran=%s (want %s)\n' \
      "$RAN_DOCS" "$1" "$RAN_CODE" "$2" >&2
    return 1
  fi
}
