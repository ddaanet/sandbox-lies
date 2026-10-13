#!/usr/bin/env bats
# lib/probes-readonly-facts.sh's partial=1 fact: which lines of the result text
# count as git's partial-checkout message (lib/probes-readonly.sh's
# _probe_partial_checkout_text), and that deriving it writes nothing (NFR-4).
# Split from tests/probes-readonly-facts.bats to hold that file under the line
# cap.
#
# The partial-checkout lines come from helpers/probes.bash's
# partial_checkout_*_error, built from two fragments each, so no source line
# here holds git's diagnostic whole (self-quiet, FR-11).

ROOT="${BATS_TEST_DIRNAME}/.."

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs
load helpers/git-env
load helpers/probes

setup() {
  source "$ROOT/lib/probes.sh"
}

@test "a partial-checkout phrase inside another tool's quoted path prints neither merge=1 nor partial=1" {
  local text n facts

  for n in 1 2 3; do
    text=$(cp_refusal_in_path "$BATS_TEST_TMPDIR" "$n")
    run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
      'cp src dst' "$text"
    [ "$status" -eq 0 ]
    # `run` below replaces $output, so the facts are held aside first.
    facts="$output"
    [ "${facts%%$'\n'*}" = writable ]
    run ! grep -q '^merge=1$' <<<"$facts"
    run ! grep -q '^partial=1$' <<<"$facts"
  done
}

# Pin: git's line counts wherever it sits, not only as the first line.
@test "partial=1 still fires when git's partial-checkout line is not the first line" {
  local text

  text="hint: something unrelated
$(partial_checkout_unlink_error "$BATS_TEST_TMPDIR/a")"
  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    'just sync' "$text"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -qxF 'partial=1'
}

# Pin: a git line another program indented or prefixed does not open its line.
@test "an indented or remote-prefixed git partial-checkout line prints neither merge=1 nor partial=1" {
  local git_line cp_line text facts shape

  git_line=$(partial_checkout_unlink_error "$BATS_TEST_TMPDIR/a")
  cp_line=$(readonly_path_text fire-readonly-path-cp-tmp "'$BATS_TEST_TMPDIR/b'")
  for shape in '    ' 'remote: '; do
    text="$cp_line
$shape$git_line"
    run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
      'just sync' "$text"
    [ "$status" -eq 0 ]
    facts="$output"
    [ "${facts%%$'\n'*}" = writable ]
    run ! grep -q '^merge=1$' <<<"$facts"
    run ! grep -q '^partial=1$' <<<"$facts"
  done
}

# NFR-4: the fact is derived with no temp file. A here-string spools through
# one above the pipe size (bash 5.1 and later) or always (before 5.1), falling
# back to the working directory when TMPDIR names nothing. The text is fed
# from a file, since run_probe_command's own here-string would spool too.
# Residual: where /tmp or the working directory is writable the fallback
# succeeds silently and this cannot see it.
@test "partial=1 on a text above 64 KB needs no temp dir" {
  local text="$BATS_TEST_TMPDIR/big.txt" i
  {
    for ((i = 0; i < 1500; i++)); do
      printf 'filler line %04d of git progress output, padding it out\n' "$i"
    done
    partial_checkout_mkdir_error "$BATS_TEST_TMPDIR/c"
  } >"$text"
  [ "$(wc -c <"$text")" -gt 65536 ]

  # shellcheck disable=SC2016 # $1 and $2 expand in the child shell
  run --separate-stderr env TMPDIR="$BATS_TEST_TMPDIR/does-not-exist" \
    bash -c 'cd / && . "$1/lib/probes.sh" && probe_readonly_path false / "just sync" <"$2"' \
    _ "$ROOT" "$text"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ] || { printf '%s\n' "$stderr" >&2; return 1; }
  printf '%s\n' "$output" | grep -qxF 'partial=1'
}

# Git's own progress fragment ends in a carriage return and the next message
# follows on the same line.
@test "partial=1 fires on git's message after its own progress fragment" {
  local text cp_line git_line

  cp_line=$(readonly_path_text fire-readonly-path-cp-tmp "'$BATS_TEST_TMPDIR/b'")
  git_line=$(partial_checkout_create_error "$BATS_TEST_TMPDIR/a")
  text=$(printf '%s\nUpdating files:  50%% (1/2)\r%s' "$cp_line" "$git_line")
  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    'just sync' "$text"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -qxF 'partial=1'
}
