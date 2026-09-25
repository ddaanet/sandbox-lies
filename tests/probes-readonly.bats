#!/usr/bin/env bats
# lib/probes.sh: probe_readonly_path (Item 4.3 slices 2-4), the A-3 contract
# for the readonly-path candidate. No verdict ships yet (Item 6.1), so the
# hook never calls this probe (tests/hook-candidates.bats "hook silent
# without a verdict" pins that).
#
# Refusal lines are the cut fire-readonly-path-* fixtures with their quoted
# path replaced at run time (readonly_path_text, helpers/probes.bash), so
# this file never holds the readonly-path refusal whole (self-quiet, FR-11).

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
  [ -z "$RO_DIR" ] || { chmod 755 "$RO_DIR" 2>/dev/null || :; }
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
