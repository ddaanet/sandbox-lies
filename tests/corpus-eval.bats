#!/usr/bin/env bats
# tests/corpus-eval.py: extract and aggregate, run over a JSONL corpus written
# under a scratch HOME. The Python calls no stubbed tool, so there is no
# make_bsd_stubs case.

ROOT="${BATS_TEST_DIRNAME}/.."

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs
load helpers/corpus

setup() {
  HOME="$BATS_TEST_TMPDIR/home"
  PROJ="$HOME/.claude/projects/-p"
  OUTDIR="$BATS_TEST_TMPDIR/out"
  mkdir -p "$PROJ"
  export HOME
}

eval_py() {
  python3 "$ROOT/tests/corpus-eval.py" "$@"
}

# one_call <n> — appends call n (a Bash call whose output survives the
# prefilter) to the corpus
one_call() {
  {
    corpus_use "u$1" "2026-09-01T00:00:00Z" "cp a b"
    corpus_result "u$1" "2026-09-01T00:00:01Z" "$(readonly_text)"
  } >>"$PROJ/s.jsonl"
}

@test "extract drops survivors and verdicts left by an earlier, larger run" {
  one_call 1
  one_call 2
  run eval_py extract --outdir "$OUTDIR"
  [ "$status" -eq 0 ]
  [ -e "$OUTDIR/survivors/000002.txt" ]
  printf '000001.txt\tfoo\n' >"$OUTDIR/verdicts.tsv"

  rm "$PROJ/s.jsonl"
  one_call 1
  run eval_py extract --outdir "$OUTDIR"

  [ "$status" -eq 0 ]
  local survivors=("$OUTDIR"/survivors/*)
  [ "${#survivors[@]}" -eq 1 ]
  [ -e "$OUTDIR/survivors/000001.txt" ]
  [ ! -e "$OUTDIR/verdicts.tsv" ]
}

@test "aggregate skips verdict lines with no manifest entry and counts them" {
  one_call 1
  run eval_py extract --outdir "$OUTDIR"
  [ "$status" -eq 0 ]
  printf '000001.txt\tro\n999998.txt\tro\n999999.txt\tro\n' >"$OUTDIR/verdicts.tsv"

  run eval_py aggregate --outdir "$OUTDIR"

  [ "$status" -eq 0 ]
  # two unmatched lines against one matched file, so the 2 on the "skipped"
  # line is the unmatched count and not the matched file's 1
  grep -i skipped <<<"$output" | grep -Eq '(^|[^0-9])2([^0-9]|$)'
  [[ "$output" == *"-> 000001.txt"* ]]
}

@test "aggregate counts skipped verdict lines by line, not by verdict" {
  one_call 1
  run eval_py extract --outdir "$OUTDIR"
  [ "$status" -eq 0 ]
  # the first unmatched line holds three verdicts and the second holds none:
  # two lines, three verdicts, so the skipped count is 2 only if it counts lines
  printf '000001.txt\tro\n999998.txt\tro rw ff\n999999.txt\t\n' >"$OUTDIR/verdicts.tsv"

  run eval_py aggregate --outdir "$OUTDIR"

  [ "$status" -eq 0 ]
  grep -Fxq "verdict lines skipped, no manifest entry: 2" <<<"$output"
}

@test "extract reads a string tool_use input as no command" {
  {
    corpus_use_raw_input u0 "2026-09-01T00:00:00Z" '"ls"'
  } >"$PROJ/s.jsonl"
  one_call 1

  run eval_py extract --outdir "$OUTDIR"

  [ "$status" -eq 0 ]
  local survivors=("$OUTDIR"/survivors/*)
  [ "${#survivors[@]}" -eq 1 ]
  [ -e "$OUTDIR/survivors/000001.txt" ]
}

@test "extract skips scalar and array JSONL lines beside a survivor" {
  printf '42\n[1]\n' >"$PROJ/s.jsonl"
  one_call 1

  run eval_py extract --outdir "$OUTDIR"

  [ "$status" -eq 0 ]
  [ -e "$OUTDIR/survivors/000001.txt" ]
}

@test "extract reads a list, number or null tool_use input as no command" {
  {
    corpus_use_raw_input u2 "2026-09-01T00:00:00Z" '["ls"]'
    corpus_use_raw_input u3 "2026-09-01T00:00:00Z" '42'
    corpus_use_raw_input u4 "2026-09-01T00:00:00Z" 'null'
  } >"$PROJ/s.jsonl"
  one_call 1

  run eval_py extract --outdir "$OUTDIR"

  [ "$status" -eq 0 ]
  local survivors=("$OUTDIR"/survivors/*)
  [ "${#survivors[@]}" -eq 1 ]
  [ -e "$OUTDIR/survivors/000001.txt" ]
}
