#!/usr/bin/env bats
# tests/extract-fixtures.py: the cutter, run from a copy in a scratch tests/
# directory so OUT (next to the script) never lands in the repo's
# tests/fixtures/. The corpus holds one call matching SPEC entry NAME.
# The Python calls no stubbed tool, so there is no make_bsd_stubs case.

ROOT="${BATS_TEST_DIRNAME}/.."
NAME=fire-lock-commit-amend
PROJECT=-Users-david-code-claude-plugin-dev

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs
load helpers/corpus

setup() {
  HOME="$BATS_TEST_TMPDIR/home"
  SCRATCH="$BATS_TEST_TMPDIR/scratch"
  CORPUS="$HOME/.claude/projects/$PROJECT/s.jsonl"
  mkdir -p "$HOME/.claude/projects/$PROJECT" "$SCRATCH/tests"
  cp "$ROOT/tests/extract-fixtures.py" "$SCRATCH/tests/"
  export HOME
}

# the matching call of $NAME, dated inside its day
matching_call() {
  corpus_use m1 "2026-08-13T10:00:00Z" "git commit --amend --no-edit"
  corpus_result m1 "2026-08-13T10:00:01Z" "$(lock_text)"
}

cut_fixture() {
  python3 "$SCRATCH/tests/extract-fixtures.py" "$NAME"
}

# the cut file's bytes are the call's recorded output, verbatim
assert_cut_verbatim() {
  [ "$status" -eq 0 ]
  lock_text >"$BATS_TEST_TMPDIR/want"
  cmp "$SCRATCH/tests/fixtures/$NAME.txt" "$BATS_TEST_TMPDIR/want"
}

@test "a null timestamp reads as no day, so a dated entry does not take its call" {
  {
    corpus_use m1 "2026-08-13T10:00:00Z" "git commit --amend --no-edit"
    jq -nc --arg t "$(lock_text)" '{timestamp: null,
      message: {content: [{type: "tool_result", tool_use_id: "m1", content: $t}]}}'
  } >"$CORPUS"

  run cut_fixture

  [ "$status" -eq 1 ]
  [[ "$output" == *"NOT FOUND: $NAME"* ]]
  [ ! -e "$SCRATCH/tests/fixtures/$NAME.txt" ]
}

@test "a string tool_use input reads as no command, so its matching call is not taken" {
  {
    corpus_use_raw_input m1 "2026-08-13T10:00:00Z" '"git commit --amend --no-edit"'
    corpus_result m1 "2026-08-13T10:00:01Z" "$(lock_text)"
  } >"$CORPUS"

  run cut_fixture

  [ "$status" -eq 1 ]
  [[ "$output" == *"NOT FOUND: $NAME"* ]]
  [ ! -e "$SCRATCH/tests/fixtures/$NAME.txt" ]
}

@test "a scalar and an array JSONL line beside the call do not stop the cut" {
  {
    printf '42\n[1]\n'
    matching_call
  } >"$CORPUS"

  run cut_fixture

  assert_cut_verbatim
}

@test "a null text item in a list-form tool_result reads as an empty line" {
  {
    corpus_use m1 "2026-08-13T10:00:00Z" "git commit --amend --no-edit"
    jq -nc --arg t "$(lock_text)" '{timestamp: "2026-08-13T10:00:01Z",
      message: {content: [{type: "tool_result", tool_use_id: "m1",
        content: [{type: "text", text: null}, {type: "text", text: $t}]}]}}'
  } >"$CORPUS"

  run cut_fixture

  [ "$status" -eq 0 ]
  printf '\n%s' "$(lock_text)" >"$BATS_TEST_TMPDIR/want"
  cmp "$SCRATCH/tests/fixtures/$NAME.txt" "$BATS_TEST_TMPDIR/want"
}

@test "a Bash tool_use whose id is a list does not stop the cut" {
  {
    jq -nc '{timestamp: "2026-08-13T10:00:00Z", message: {content: [{type: "tool_use",
      name: "Bash", id: ["m0"], input: {command: "ls"}}]}}'
    matching_call
  } >"$CORPUS"

  run --separate-stderr cut_fixture

  # shellcheck disable=SC2154 # set by bats' run --separate-stderr
  [[ "$stderr" != *Traceback* ]]
  assert_cut_verbatim
}

@test "a tool_result whose tool_use_id is a list does not stop the cut" {
  {
    jq -nc --arg t "$(lock_text)" '{timestamp: "2026-08-13T10:00:00Z",
      message: {content: [{type: "tool_result", tool_use_id: ["m0"], content: $t}]}}'
    matching_call
  } >"$CORPUS"

  run --separate-stderr cut_fixture

  # shellcheck disable=SC2154 # set by bats' run --separate-stderr
  [[ "$stderr" != *Traceback* ]]
  assert_cut_verbatim
}

@test "an integer timestamp beside the call does not stop the cut" {
  {
    jq -nc '{timestamp: 5, message: {content: [{type: "tool_use", name: "Bash",
      id: "m0", input: {command: "ls"}}]}}'
    matching_call
  } >"$CORPUS"

  run --separate-stderr cut_fixture

  # shellcheck disable=SC2154 # set by bats' run --separate-stderr
  [[ "$stderr" != *Traceback* ]]
  assert_cut_verbatim
}

@test "an integer text item in a list-form tool_result does not stop the cut" {
  {
    corpus_use m1 "2026-08-13T10:00:00Z" "git commit --amend --no-edit"
    jq -nc --arg t "$(lock_text)" '{timestamp: "2026-08-13T10:00:01Z",
      message: {content: [{type: "tool_result", tool_use_id: "m1",
        content: [{type: "text", text: 5}, {type: "text", text: $t}]}]}}'
  } >"$CORPUS"

  run --separate-stderr cut_fixture

  # shellcheck disable=SC2154 # set by bats' run --separate-stderr
  [[ "$stderr" != *Traceback* ]]
  [ "$status" -eq 0 ]
  grep -Fq "$(lock_text)" "$SCRATCH/tests/fixtures/$NAME.txt"
}
