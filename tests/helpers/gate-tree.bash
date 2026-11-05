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
# quiet line. shellcheck and rumdl are stubs, each printing the contents of a
# `<stub>.version` file beside it for `--version` so a case can change a tool
# version, and the tree's bats runner a spy appending its arguments as one line
# to $SPY_LOG: the cases are about whether a gate runs, and the slow checks are
# not what they assert.
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
  # shellcheck disable=SC2016 # $0 expands in the stub, not here
  printf '#!/bin/sh\ncat "$0.version" 2>/dev/null\nexit 0\n' >"$STUBS/shellcheck"
  cp "$STUBS/shellcheck" "$STUBS/rumdl"
  chmod 755 "$STUBS/shellcheck" "$STUBS/rumdl"
  printf '#!/bin/sh\necho "$*" >>"%s"\nexit 0\n' "$SPY_LOG" \
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
