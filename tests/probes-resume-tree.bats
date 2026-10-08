#!/usr/bin/env bats
# lib/probes.sh: probe_resume_lost over trees it cannot search or a caller's
# shell options (Item 1.1's deliverable review): a config dir that is missing
# or unlistable is unknown, never lost; a caller's noglob does not make every
# id missing; the refusal line shape is the matcher's own; a transcript is
# never opened. The probe's main cases are in tests/probes-resume.bats.

ROOT="${BATS_TEST_DIRNAME}/.."

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs
load helpers/probes
load helpers/resume

setup() {
  source "$ROOT/lib/probes.sh"
  export CLAUDE_CONFIG_DIR="$BATS_TEST_TMPDIR/cfg"
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$CLAUDE_CONFIG_DIR/projects/-p" "$HOME"
  TEXT=$(cat "$BATS_TEST_DIRNAME/fixtures/fire-resume-lost-two-turn.txt")
}

teardown() {
  resume_teardown
}

@test "resume-lost probe: a caller's noglob does not make every id lost" {
  # Under set -f the pattern never expands, the literal path fails [ -f ],
  # and every transcript that exists reads as missing.
  transcript "$ID_1"
  transcript "$ID_2"
  set -f

  run_probe probe_resume_lost false "$BATS_TEST_TMPDIR" "$TEXT"
  set +f

  [ "$status" -eq 0 ]
  [ "$output" = found ]
  [ -z "$stderr" ]
}

@test "resume-lost probe: a config dir that does not exist is unknown" {
  # A tree the probe could not search says nothing about the transcript: a
  # relative CLAUDE_CONFIG_DIR resolved against the hook's cwd lands here.
  CLAUDE_CONFIG_DIR="$BATS_TEST_TMPDIR/nonexistent" \
    run_probe probe_resume_lost false "$BATS_TEST_TMPDIR" "$TEXT"

  [ "$status" -eq 0 ]
  [ "$output" = unknown ]
  [ -z "$stderr" ]
}

@test "resume-lost probe: a projects directory it cannot list is unknown" {
  # No read bit, no search bit, neither: each leaves the glob empty, and an
  # empty glob is not a transcript that was never written.
  [ "$(id -u)" -ne 0 ] || skip "root reads past chmod 000"
  local mode
  transcript "$ID_1"
  transcript "$ID_2"
  for mode in 000 444 311; do
    chmod "$mode" "$BATS_TEST_TMPDIR/cfg/projects"

    run_probe probe_resume_lost false "$BATS_TEST_TMPDIR" "$TEXT"
    chmod 755 "$BATS_TEST_TMPDIR/cfg/projects"

    [ "$status" -eq 0 ]
    [ "$output" = unknown ] || { echo "mode $mode: $output" >&2; return 1; }
    [ -z "$stderr" ]
  done
}

@test "resume-lost probe: a readable projects directory with no project in it is lost" {
  # Nothing to list is not nothing that could be listed: the unmatched glob
  # is no unreadable project directory.
  rmdir "$BATS_TEST_TMPDIR/cfg/projects/-p"

  run_probe probe_resume_lost false "$BATS_TEST_TMPDIR" "$TEXT"

  [ "$status" -eq 0 ]
  [ "$output" = lost ]
  [ -z "$stderr" ]
}

@test "resume-lost probe: a projects that is not a directory is unknown" {
  rm -r "$BATS_TEST_TMPDIR/cfg/projects"
  printf '#!/bin/sh\n' >"$BATS_TEST_TMPDIR/cfg/projects"
  chmod 755 "$BATS_TEST_TMPDIR/cfg/projects"

  run_probe probe_resume_lost false "$BATS_TEST_TMPDIR" "$TEXT"

  [ "$status" -eq 0 ]
  [ "$output" = unknown ]
  [ -z "$stderr" ]
}

@test "resume-lost probe: an unreadable project directory hiding an id is unknown" {
  # ID_2's transcript may sit in -q, which the probe cannot list: no hit in
  # the directories it could read is not a lost transcript.
  [ "$(id -u)" -ne 0 ] || skip "root reads past chmod 000"
  transcript "$ID_1"
  transcript "$ID_2" "$BATS_TEST_TMPDIR/cfg" -q
  chmod 000 "$BATS_TEST_TMPDIR/cfg/projects/-q"

  run_probe probe_resume_lost false "$BATS_TEST_TMPDIR" "$TEXT"
  chmod 755 "$BATS_TEST_TMPDIR/cfg/projects/-q"

  [ "$status" -eq 0 ]
  [ "$output" = unknown ]
  [ -z "$stderr" ]
}

@test "resume-lost probe: an unreadable project directory beside both hits is found" {
  # The partner of the case above: every id found in a readable directory
  # needs nothing from the one the probe cannot list.
  [ "$(id -u)" -ne 0 ] || skip "root reads past chmod 000"
  transcript "$ID_1"
  transcript "$ID_2"
  mkdir "$BATS_TEST_TMPDIR/cfg/projects/-q"
  chmod 000 "$BATS_TEST_TMPDIR/cfg/projects/-q"

  run_probe probe_resume_lost false "$BATS_TEST_TMPDIR" "$TEXT"
  chmod 755 "$BATS_TEST_TMPDIR/cfg/projects/-q"

  [ "$status" -eq 0 ]
  [ "$output" = found ]
  [ -z "$stderr" ]
}

@test "resume-lost probe: an unreadable transcript is found, never opened" {
  # NFR-4: the probe tests for the file and does not read it. A probe that
  # cats a hit writes a permission error to stderr.
  [ "$(id -u)" -ne 0 ] || skip "root reads past chmod 000"
  transcript "$ID_1"
  transcript "$ID_2"
  chmod 000 "$BATS_TEST_TMPDIR/cfg/projects/-p/$ID_1.jsonl" \
    "$BATS_TEST_TMPDIR/cfg/projects/-p/$ID_2.jsonl"

  run_probe probe_resume_lost false "$BATS_TEST_TMPDIR" "$TEXT"

  [ "$status" -eq 0 ]
  [ "$output" = found ]
  [ -z "$stderr" ]
}

@test "resume-lost probe: the id class is the matcher's own" {
  # The probe extracts with the line shape match_resume_lost tests, held once
  # in _RESUME_LOST_LINE. Widen it and both follow: a probe keeping a copy
  # prints unknown on a refusal the matcher detected.
  local text='No conversation found with session ID: zzzz'
  # shellcheck disable=SC2034 # read by match_resume_lost and the probe
  _RESUME_LOST_LINE='^No conversation found with session ID: ([0-9a-fA-Fz-]+)[[:space:]]*$'

  printf '%s\n' "$text" | match_resume_lost
  run_probe probe_resume_lost false "$BATS_TEST_TMPDIR" "$text"

  [ "$status" -eq 0 ]
  [ "$output" = lost ]
}

@test "resume-lost probe: an unsearchable tree is unknown under BSD sed and stat" {
  # The unlistable-directory scan and the extraction both run under the
  # stubs: a GNU-ism in either reads the tree as lost or the text as unknown.
  [ "$(id -u)" -ne 0 ] || skip "root reads past chmod 000"
  transcript "$ID_1"
  transcript "$ID_2" "$BATS_TEST_TMPDIR/cfg" -q
  chmod 000 "$BATS_TEST_TMPDIR/cfg/projects/-q"
  make_bsd_stubs "$BATS_TEST_TMPDIR/bsd" sed grep mktemp stat wc

  PATH="$BATS_TEST_TMPDIR/bsd:$PATH" \
    run_probe probe_resume_lost false "$BATS_TEST_TMPDIR" "$TEXT"
  chmod 755 "$BATS_TEST_TMPDIR/cfg/projects/-q"

  [ "$status" -eq 0 ]
  [ "$output" = unknown ]
  [ -z "$stderr" ]
}
