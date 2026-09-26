#!/usr/bin/env bats
# lib/probes-readonly.sh, sourced through lib/probes.sh as the hook sources
# it: probe_readonly_path (Item 4.3 slices 2-4, Item 6.1 slice 1), the A-3
# contract for readonly-path. The hook's call to it is pinned in
# tests/hook-candidates.bats.
#
# Refusal lines are the cut fire-readonly-path-* fixtures with their quoted
# path replaced at run time (readonly_path_text, helpers/probes.bash), or are
# built around erofs_message, so this file never holds the readonly-path
# refusal whole (self-quiet, FR-11).

ROOT="${BATS_TEST_DIRNAME}/.."

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs
load helpers/probes

setup() {
  source "$ROOT/lib/probes.sh"
  RO_DIR=
}

# A chmod 555 case must leave its directory removable: restore before bats'
# own tmpdir cleanup runs.
teardown() {
  [ -z "$RO_DIR" ] || chmod 755 "$RO_DIR"
}

# ro_dir <dir> — creates <dir> if missing, chmod 555s it, records it in
# RO_DIR for teardown, and skips the rest of the test when the mode is not
# enforced (root, CAP_DAC_OVERRIDE, a filesystem ignoring modes): the
# precondition is checked directly, not inferred from the uid.
ro_dir() {
  RO_DIR="$1"
  mkdir -p "$RO_DIR"
  chmod 555 "$RO_DIR"
  if [ -w "$RO_DIR" ]; then
    skip "chmod 555 not enforced for this user"
  fi
}

# The target's directory holds a space: a quoted path is quoted because it
# may, and an extraction splitting on blanks would name "$BATS_TEST_TMPDIR/a".
@test "writable path" {
  local target="$BATS_TEST_TMPDIR/a dir/target" text
  mkdir -p "${target%/*}"
  : >"$target"
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'$target'")

  run_probe probe_readonly_path false "$BATS_TEST_TMPDIR" "$text"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = writable ]
  printf '%s\n' "$output" | grep -qxF "path=$target"
}

# Interpretation (the entry's Probe paragraph is silent on a relative
# quoted path): joined onto the payload cwd ($2) itself, the directory the
# producer (Python here, cp, touch, bash) resolved it against. Not the lock
# probes' _probe_resolve_path, whose walk up to a .git top-level mirrors how
# git prints a lock path: a .git directory above the cwd makes that walk
# name "$BATS_TEST_TMPDIR/repo/hooks/hooks.json", a file no error named. The
# fixture's own path ("hooks/hooks.json") is relative, used verbatim rather
# than substituted.
@test "relative path resolves against cwd" {
  local cwd="$BATS_TEST_TMPDIR/repo/sub" text
  mkdir -p "$cwd/hooks" "$BATS_TEST_TMPDIR/repo/.git"
  : >"$cwd/hooks/hooks.json"
  text=$(cat "${BATS_TEST_DIRNAME}/fixtures/fire-readonly-path-python-errno.txt")

  run_probe probe_readonly_path false "$cwd" "$text"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = writable ]
  printf '%s\n' "$output" | grep -qxF "path=$cwd/hooks/hooks.json"
}

@test "absent file checks its parent" {
  local dir="$BATS_TEST_TMPDIR/rw" path text
  mkdir -p "$dir"
  path="$dir/missing"
  text=$(readonly_path_text fire-readonly-path-python-errno "'$path'")

  run_probe probe_readonly_path false "$BATS_TEST_TMPDIR" "$text"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = writable ]
  printf '%s\n' "$output" | grep -qxF "path=$path"

  ro_dir "$BATS_TEST_TMPDIR/ro"
  path="$RO_DIR/missing"
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'$path'")

  run_probe probe_readonly_path false "$BATS_TEST_TMPDIR" "$text"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = readonly ]
  printf '%s\n' "$output" | grep -qxF "path=$path"
}

# An existing file is tested itself, never its parent: each half's file and
# parent disagree, so a probe testing the parent (or only the file's
# absence) gets both halves backwards.
@test "existing file checks the file itself" {
  local file text
  file="$BATS_TEST_TMPDIR/rw/locked"
  mkdir -p "${file%/*}"
  : >"$file"
  chmod 444 "$file"
  if [ -w "$file" ]; then
    skip "chmod 444 not enforced for this user"
  fi
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'$file'")

  run_probe probe_readonly_path false "$BATS_TEST_TMPDIR" "$text"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = readonly ]
  printf '%s\n' "$output" | grep -qxF "path=$file"

  file="$BATS_TEST_TMPDIR/ro/open"
  mkdir -p "${file%/*}"
  : >"$file"
  ro_dir "${file%/*}"
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'$file'")

  run_probe probe_readonly_path false "$BATS_TEST_TMPDIR" "$text"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = writable ]
  printf '%s\n' "$output" | grep -qxF "path=$file"
}

# The first quoted path of the matching line: the refusal line carries two
# quoted paths (as mv's "cannot move '<a>' to '<b>'" does), built by
# substituting both into the cut fixture's single quoted segment.
@test "first quoted path on the line" {
  local first="$BATS_TEST_TMPDIR/first" second="$BATS_TEST_TMPDIR/second" text
  : >"$first"
  : >"$second"
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'$first' to '$second'")

  run_probe probe_readonly_path false "$BATS_TEST_TMPDIR" "$text"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = writable ]
  printf '%s\n' "$output" | grep -qxF "path=$first"
}

# A quoted path on a line the matcher does not match is never read: first
# ahead of a refusal line naming its own path, then ahead of one naming
# none, where taking it would turn nopath into writable.
@test "quoted path off the matching line is ignored" {
  local decoy="$BATS_TEST_TMPDIR/decoy" target="$BATS_TEST_TMPDIR/target" text
  : >"$decoy"
  : >"$target"
  text="note: see '$decoy'"$'\n'$(readonly_path_text fire-readonly-path-cp-tmp "'$target'")

  run_probe probe_readonly_path false "$BATS_TEST_TMPDIR" "$text"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = writable ]
  printf '%s\n' "$output" | grep -qxF "path=$target"

  text="note: see '$decoy'"$'\n'$(readonly_path_text fire-readonly-path-cp-tmp "")

  run_probe probe_readonly_path false "$BATS_TEST_TMPDIR" "$text"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = nopath ]
  run ! grep -q '^path=' <<<"$output"
}

@test "no quoted path" {
  local text
  text=$(readonly_path_text fire-readonly-path-cp-tmp "")

  run_probe probe_readonly_path false "$BATS_TEST_TMPDIR" "$text"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = nopath ]
  run ! grep -q '^path=' <<<"$output"
}

# Item 6.1 slice 1: extraction widened past the first ASCII single-quoted
# segment. Each line shape below is real, collected sandboxed 2026-09-26 (CC
# 2.1.281; runbook Item 6.1 slice 1 table), its path swapped for one under
# $BATS_TEST_TMPDIR; the kernel's message comes from erofs_message
# (self-quiet, FR-11) rather than being quoted here. Every name holds a
# blank, and each unquoted one also holds `: ` and its own form's words: the
# capture starts after the words' first occurrence, at the tool's prefix,
# and ends at the last `: `, not at a blank, the first `: ` or a later copy
# of the words.

# The em dash (U+2014) shares its first two bytes with both curly quotes, so
# a capture excluding the closing quote's bytes one by one stops inside it,
# and a prefix excluding the opening quote's bytes (a tool invoked by a path
# holding one) never reaches the quote. Of two curly segments, the first.
@test "curly-quoted mkdir path is extracted" {
  local p="$BATS_TEST_TMPDIR/curly — target" text
  text="mkdir: cannot create directory ‘$p’: $(erofs_message)"

  run_probe probe_readonly_path false "$BATS_TEST_TMPDIR" "$text"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = writable ]
  printf '%s\n' "$output" | grep -qxF "path=$p"

  text="/opt/tools—2/mkdir: cannot create directory ‘$p’"
  text="$text ‘$BATS_TEST_TMPDIR/second’: $(erofs_message)"

  run_probe probe_readonly_path false "$BATS_TEST_TMPDIR" "$text"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = writable ]
  printf '%s\n' "$output" | grep -qxF "path=$p"
}

@test "bash line-N path is extracted" {
  local p="$BATS_TEST_TMPDIR/bash line 3: target" text
  text="/bin/bash: line 4: $p: $(erofs_message)"

  run_probe probe_readonly_path false "$BATS_TEST_TMPDIR" "$text"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = writable ]
  printf '%s\n' "$output" | grep -qxF "path=$p"
}

@test "dash redirect path is extracted" {
  local p="$BATS_TEST_TMPDIR/dash 2: cannot create target" text
  text="sh: 1: cannot create $p: $(erofs_message)"

  run_probe probe_readonly_path false "$BATS_TEST_TMPDIR" "$text"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = writable ]
  printf '%s\n' "$output" | grep -qxF "path=$p"
}

@test "git config-lock path is extracted" {
  local p="$BATS_TEST_TMPDIR/error: could not lock config file target" text
  text="error: could not lock config file $p: $(erofs_message)"

  run_probe probe_readonly_path false "$BATS_TEST_TMPDIR" "$text"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = writable ]
  printf '%s\n' "$output" | grep -qxF "path=$p"
}

@test "git mkdir path is extracted" {
  local p="$BATS_TEST_TMPDIR/fatal: cannot mkdir target" text
  text="fatal: cannot mkdir $p: $(erofs_message)"

  run_probe probe_readonly_path false "$BATS_TEST_TMPDIR" "$text"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = writable ]
  printf '%s\n' "$output" | grep -qxF "path=$p"
}

# The move's source is quoted first on the line; the removed target after it
# is the path a readonly-path verdict is about, so a probe still taking the
# first quoted segment names the wrong file.
@test "mv target path is extracted, not the source" {
  local src="$BATS_TEST_TMPDIR/mv source" p="$BATS_TEST_TMPDIR/mv target" text
  text="mv: inter-device move failed: '$src' to '$p';"
  text="$text unable to remove target: $(erofs_message)"

  run_probe probe_readonly_path false "$BATS_TEST_TMPDIR" "$text"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = writable ]
  printf '%s\n' "$output" | grep -qxF "path=$p"
}

# Regression: straight-quoted forms the extractor already handled before this
# slice. cp (fire-readonly-path-cp-tmp) and Python's OSError
# (fire-readonly-path-python-errno) are already pinned above ("writable
# path" and its siblings, "relative path resolves against cwd"); touch and
# ln are not, so they are the ones re-asserted here.
@test "straight-quoted touch and ln keep their path" {
  local p="$BATS_TEST_TMPDIR/touch target" text
  text="touch: cannot touch '$p': $(erofs_message)"

  run_probe probe_readonly_path false "$BATS_TEST_TMPDIR" "$text"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = writable ]
  printf '%s\n' "$output" | grep -qxF "path=$p"

  p="$BATS_TEST_TMPDIR/ln target"
  text="ln: failed to create symbolic link '$p': $(erofs_message)"

  run_probe probe_readonly_path false "$BATS_TEST_TMPDIR" "$text"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = writable ]
  printf '%s\n' "$output" | grep -qxF "path=$p"
}

# Near-miss: an unquoted path outside the four fixed unquoted forms (bash's
# `line N:` locator, dash's `cannot create`, git's `could not lock config
# file` and `cannot mkdir`, each after its own prefix) — after other words
# (rm), directly after the prefix (BSD touch's shape), and after dash's words
# under another prefix. The matcher has no prefix allowlist and accepts each
# line (asserted first), so nopath is the extractor's refusal, not the
# matcher's.
@test "unquoted path after an unlisted prefix stays nopath" {
  local p="$BATS_TEST_TMPDIR/near miss" line text
  for line in "rm: cannot remove $p" "touch: $p" \
    "mkdir: cannot create directory $p"; do
    text="$line: $(erofs_message)"
    match_readonly_path <<<"$text"

    run_probe probe_readonly_path false "$BATS_TEST_TMPDIR" "$text"

    [ "$status" -eq 0 ]
    [ -z "$stderr" ]
    [ "${output%%$'\n'*}" = nopath ]
    run ! grep -q '^path=' <<<"$output"
  done
}

@test "writable path survives BSD grep and sed" {
  local target="$BATS_TEST_TMPDIR/a dir/target" text bsd
  mkdir -p "${target%/*}"
  : >"$target"
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'$target'")
  bsd="$BATS_TEST_TMPDIR/bsdtools"
  make_bsd_stubs "$bsd" grep sed

  PATH="$bsd:$PATH" run_probe probe_readonly_path false "$BATS_TEST_TMPDIR" "$text"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = writable ]
  printf '%s\n' "$output" | grep -qxF "path=$target"
}

# The widened extraction through BSD grep and sed (NFR-2): the curly-quoted
# form and one unquoted form, the two new kinds of line the extractor reads.
@test "curly and unquoted paths survive BSD grep and sed" {
  local bsd="$BATS_TEST_TMPDIR/bsdtools" p text
  make_bsd_stubs "$bsd" grep sed
  p="$BATS_TEST_TMPDIR/curly — target"
  text="mkdir: cannot create directory ‘$p’: $(erofs_message)"

  PATH="$bsd:$PATH" run_probe probe_readonly_path false "$BATS_TEST_TMPDIR" "$text"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = writable ]
  printf '%s\n' "$output" | grep -qxF "path=$p"

  p="$BATS_TEST_TMPDIR/bash target"
  text="/bin/bash: line 4: $p: $(erofs_message)"

  PATH="$bsd:$PATH" run_probe probe_readonly_path false "$BATS_TEST_TMPDIR" "$text"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = writable ]
  printf '%s\n' "$output" | grep -qxF "path=$p"
}
