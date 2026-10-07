#!/usr/bin/env bats
# lib/probes.sh: probe_resume_lost (Item 1.1). The probe reads the refusal
# lines in the result text for session ids and tests each for a regular file
# <config dir>/projects/*/<id>.jsonl; `lost` when some id has none, `found`
# when every id has one. The ids are those of fire-resume-lost-two-turn.txt.

ROOT="${BATS_TEST_DIRNAME}/.."

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs
load helpers/probes

ID_1=37b5f8f7-cd46-44d7-8416-946cf6729b30
ID_2=7ded81f3-920a-40b7-bf8b-5f08e913c333
ID_OTHER=11111111-2222-4333-8444-555555555555

setup() {
  source "$ROOT/lib/probes.sh"
  # Neither the host's config dir nor its HOME is ever read.
  export CLAUDE_CONFIG_DIR="$BATS_TEST_TMPDIR/cfg"
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$CLAUDE_CONFIG_DIR/projects/-p" "$HOME"
  TEXT=$(cat "$BATS_TEST_DIRNAME/fixtures/fire-resume-lost-two-turn.txt")
}

# transcript <id> [root] [project] — a regular file
# <root>/projects/<project>/<id>.jsonl, root defaulting to the config dir and
# project to -p. It holds one JSON line, as a transcript CC wrote would.
transcript() {
  local root="${2:-$CLAUDE_CONFIG_DIR}" project="${3:--p}"
  mkdir -p "$root/projects/$project"
  printf '{}\n' >"$root/projects/$project/$1.jsonl"
}

@test "resume-lost probe: both ids have a transcript, found" {
  # In two project directories: the glob spans every project, and a probe
  # searching one directory, or requiring both ids in the same one, is lost.
  transcript "$ID_1"
  transcript "$ID_2" "$CLAUDE_CONFIG_DIR" -q

  run_probe probe_resume_lost false "$BATS_TEST_TMPDIR" "$TEXT"

  [ "$status" -eq 0 ]
  [ "$output" = found ]
  [ -z "$stderr" ]
}

@test "resume-lost probe: one id without a transcript is lost" {
  transcript "$ID_1"

  run_probe probe_resume_lost false "$BATS_TEST_TMPDIR" "$TEXT"

  [ "$status" -eq 0 ]
  [ "$output" = lost ]
  [ -z "$stderr" ]
}

@test "resume-lost probe: the first id without a transcript is lost" {
  # The mirror of the case above: a probe testing only the last refusal's id
  # passes that one and fails this.
  transcript "$ID_2"

  run_probe probe_resume_lost false "$BATS_TEST_TMPDIR" "$TEXT"

  [ "$status" -eq 0 ]
  [ "$output" = lost ]
}

@test "resume-lost probe: a transcript for an unrelated id does not count" {
  # As many transcripts as refused ids, so a probe counting .jsonl files, or
  # testing for any, prints found.
  transcript "$ID_1"
  transcript "$ID_OTHER"

  run_probe probe_resume_lost false "$BATS_TEST_TMPDIR" "$TEXT"

  [ "$status" -eq 0 ]
  [ "$output" = lost ]
}

@test "resume-lost probe: an id outside a refusal line is not taken" {
  # The fixture minus the refusal naming ID_2; its sid2= line still names
  # it. A probe taking every id in the text tests ID_2 and prints lost.
  local text
  text=$(printf '%s\n' "$TEXT" | grep -vF -- "ID: $ID_2")
  case "$text" in *"sid2=$ID_2"*) ;; *) return 1 ;; esac
  case "$text" in *"ID: $ID_2"*) return 1 ;; esac
  transcript "$ID_1"

  run_probe probe_resume_lost false "$BATS_TEST_TMPDIR" "$text"

  [ "$status" -eq 0 ]
  [ "$output" = found ]
}

@test "resume-lost probe: a directory named <id>.jsonl is not a transcript" {
  transcript "$ID_1"
  mkdir "$CLAUDE_CONFIG_DIR/projects/-p/$ID_2.jsonl"

  run_probe probe_resume_lost false "$BATS_TEST_TMPDIR" "$TEXT"

  [ "$status" -eq 0 ]
  [ "$output" = lost ]
}

@test "resume-lost probe: a transcript under archived/ is not counted" {
  transcript "$ID_1"
  transcript "$ID_2" "$CLAUDE_CONFIG_DIR" -p/archived

  run_probe probe_resume_lost false "$BATS_TEST_TMPDIR" "$TEXT"

  [ "$status" -eq 0 ]
  [ "$output" = lost ]
}

@test "resume-lost probe: CLAUDE_CONFIG_DIR unset falls back to HOME/.claude" {
  unset CLAUDE_CONFIG_DIR
  transcript "$ID_1" "$HOME/.claude"
  transcript "$ID_2" "$HOME/.claude"

  run_probe probe_resume_lost false "$BATS_TEST_TMPDIR" "$TEXT"

  [ "$status" -eq 0 ]
  [ "$output" = found ]
}

@test "resume-lost probe: CLAUDE_CONFIG_DIR set, HOME/.claude is not read" {
  # E5: CC reads only the config dir it is given. A probe also searching
  # HOME/.claude finds ID_2 there and prints found.
  transcript "$ID_1"
  transcript "$ID_2" "$HOME/.claude"

  run_probe probe_resume_lost false "$BATS_TEST_TMPDIR" "$TEXT"

  [ "$status" -eq 0 ]
  [ "$output" = lost ]
}

@test "resume-lost probe: found survives BSD grep, sed, mktemp, stat and wc" {
  # found needs both ids taken from the text. A GNU-ism that leaves the
  # probe with no ids and a lost default reads as the correct answer in the
  # hook's no-transcript BSD case; here it prints lost.
  transcript "$ID_1"
  transcript "$ID_2"
  make_bsd_stubs "$BATS_TEST_TMPDIR/bsd" sed grep mktemp stat wc

  PATH="$BATS_TEST_TMPDIR/bsd:$PATH" \
    run_probe probe_resume_lost false "$BATS_TEST_TMPDIR" "$TEXT"

  [ "$status" -eq 0 ]
  [ "$output" = found ]
}
